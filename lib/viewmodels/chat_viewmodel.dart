import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/media_storage_service.dart';
import '../services/websocket_service.dart';

class ChatViewModel extends ChangeNotifier {
  List<Chat> _chats = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreChats = true;
  bool _chatSyncInFlight = false;
  bool _isAuthenticated = false;
  DateTime? _lastServerSync;
  String? _activeChatId;
  StreamSubscription<Message>? _socketSubscription;
  StreamSubscription<MessageStatusUpdate>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _deleteSubscription;
  StreamSubscription<Map<String, dynamic>>? _presenceSubscription;
  final Set<String> _deletedChatIds = {};
  final Set<String> _recentMessageEventKeys = {};
  final List<String> _recentMessageEventOrder = [];
  static const int _maxRecentMessageEvents = 200;
  static const int _chatPageSize = 20;
  static const Duration _minimumSyncInterval = Duration(seconds: 45);

  List<Chat> get chats => _chats;

  /// The existing, server-backed conversation with [receiverId], or null if we
  /// have none. Used so opening a person from the contact list reuses their
  /// real chat (and its message history) instead of starting an empty `new_`
  /// placeholder that loads no messages.
  Chat? chatForReceiver(String receiverId) {
    if (receiverId.isEmpty) return null;
    for (final chat in _chats) {
      if (chat.receiverId == receiverId && !chat.id.startsWith('new_')) {
        return chat;
      }
    }
    return null;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreChats => _hasMoreChats;
  String? get activeChatId => _activeChatId;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final AppDatabase _db = AppDatabase();

  ChatViewModel() {
    _socketSubscription = _socketService.messageStream.listen((message) {
      _handleNewMessage(message);
    });
    _statusSubscription = _socketService.messageStatusStream.listen((status) {
      _handleStatusUpdate(status);
    });
    _deleteSubscription = _socketService.messageDeleteStream.listen((data) {
      _handleMessageDeleted(data);
    });
    _presenceSubscription = _socketService.presenceStream.listen((data) {
      _handlePresenceUpdate(data);
    });
  }

  void handleAuthState(bool isAuthenticated) {
    if (_isAuthenticated == isAuthenticated) return;
    _isAuthenticated = isAuthenticated;

    if (!_isAuthenticated) {
      _activeChatId = null;
      _chats = [];
      _isLoading = false;
      _isLoadingMore = false;
      _hasMoreChats = true;
      _lastServerSync = null;
      _recentMessageEventKeys.clear();
      _recentMessageEventOrder.clear();
      notifyListeners();
      unawaited(_db.clearDatabase());
      return;
    }

    fetchChats(isSilent: true, force: true);
  }

  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }

  Future<void> invalidateMessageFreshness() {
    return _db.invalidateMessageRefreshes();
  }

  Future<void> deleteChat(String chatId) async {
    _deletedChatIds.add(chatId);
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
    try {
      await _apiService.deleteChat(chatId);
    } catch (e) {
      debugPrint('Error deleting chat on server: $e');
    }
    await _db.deleteChatById(chatId);
  }

  void markChatRead(String chatId) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1 || _chats[index].unreadCount == 0) return;

    final chat = _chats[index];
    final updatedChat = chat.copyWith(unreadCount: 0);
    _chats[index] = updatedChat;
    notifyListeners();
    unawaited(_db.updateLocalChat(updatedChat.toEntity()));
    unawaited(_db.markMessagesRead(chatId));
  }

  void _handleNewMessage(Message message) {
    if (_isDuplicateMessageEvent(message)) return;
    if (_deletedChatIds.contains(message.chatId)) return;
    unawaited(_db.upsertMessage(message));
    if (!message.isMe && message.type != 'text') {
      MediaStorageService.instance.cacheMessagesInBackground(
        [message],
        onCached: (cachedMessage, path) {
          return _db.updateMessageLocalFilePath(cachedMessage.id, path);
        },
      );
    }
    // Find the chat and update its last message and unread count
    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index != -1) {
      final chat = _chats[index];
      final nextUnreadCount = message.chatId == _activeChatId
          ? 0
          : (message.isMe ? chat.unreadCount : chat.unreadCount + 1);
      final updatedChat = chat.copyWith(
        id: message.chatId, // Update the ID too, in case it was a placeholder
        lastMessage: message.text,
        lastMessageType: message.type,
        lastMessageStatus: message.deliveryState,
        lastMessageFileUrl: message.fileUrl,
        time: message.time,
        unreadCount: nextUnreadCount,
      );
      final isAlreadyTop = index == 0;
      final hasVisibleChange =
          chat.id != updatedChat.id ||
          chat.lastMessage != updatedChat.lastMessage ||
          chat.lastMessageType != updatedChat.lastMessageType ||
          chat.lastMessageStatus != updatedChat.lastMessageStatus ||
          chat.lastMessageFileUrl != updatedChat.lastMessageFileUrl ||
          chat.time != updatedChat.time ||
          chat.unreadCount != updatedChat.unreadCount ||
          !isAlreadyTop;
      if (!hasVisibleChange) return;
      _chats[index] = updatedChat;
      // Move to top
      final movedChat = _chats.removeAt(index);
      _chats.insert(0, movedChat);
      notifyListeners();
      unawaited(_db.updateLocalChat(updatedChat.toEntity()));
    } else {
      // If the chat is not in the list (e.g. brand new), fetch all chats to refresh state
      fetchChats(isSilent: true, force: true);
    }
  }

  Future<void> fetchChats({bool isSilent = false, bool force = false}) async {
    if (!_isAuthenticated) return;

    if (_chats.isEmpty) {
      try {
        final localEntities = await _db.getLocalChats();
        if (localEntities.isNotEmpty) {
          _chats = localEntities.map((e) => e.toDomain()).toList();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error loading cached chats: $e');
      }
    }

    if (!isSilent && _chats.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    final lastSync = _lastServerSync;
    if (!force &&
        lastSync != null &&
        DateTime.now().difference(lastSync) < _minimumSyncInterval) {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }
    if (_chatSyncInFlight) return;
    _chatSyncInFlight = true;

    try {
      final page = await _apiService.getChatsPage(limit: _chatPageSize);
      final chatsById = {for (final chat in _chats) chat.id: chat};
      for (final chat in page.items) {
        chatsById[chat.id] = chat;
      }
      _chats = chatsById.values.toList()
        ..sort((a, b) => b.time.compareTo(a.time));
      _hasMoreChats = page.hasMore;
      _lastServerSync = DateTime.now();
      notifyListeners();
      unawaited(_db.saveChats(page.items.map((c) => c.toEntity()).toList()));
    } catch (e) {
      debugPrint('Error fetching chats from API: $e');
    } finally {
      _chatSyncInFlight = false;
    }

    if (!isSilent) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreChats() async {
    if (!_isAuthenticated ||
        !_hasMoreChats ||
        _isLoadingMore ||
        _chatSyncInFlight) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _apiService.getChatsPage(
        offset: _chats.length,
        limit: _chatPageSize,
      );
      final knownIds = _chats.map((chat) => chat.id).toSet();
      _chats.addAll(page.items.where((chat) => knownIds.add(chat.id)));
      _chats.sort((a, b) => b.time.compareTo(a.time));
      _hasMoreChats = page.hasMore;
      unawaited(_db.saveChats(page.items.map((c) => c.toEntity()).toList()));
    } catch (e) {
      debugPrint('Error loading more chats: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    final chatId = data['chat_id']?.toString();
    if (chatId == null) return;
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    // Re-fetch silently so the chat list last-message preview reflects the deletion.
    unawaited(fetchChats(isSilent: true, force: true));
  }

  void _handleStatusUpdate(MessageStatusUpdate status) {
    final index = _chats.indexWhere((c) => c.id == status.chatId);
    if (index != -1) {
      final chat = _chats[index];
      if (chat.lastMessageStatus != status.deliveryState) {
        final updatedChat = chat.copyWith(
          lastMessageStatus: status.deliveryState,
        );
        _chats[index] = updatedChat;
        notifyListeners();
        unawaited(_db.updateLocalChat(updatedChat.toEntity()));
      }
    }
    for (final id
        in status.messageIds.isEmpty ? [status.messageId] : status.messageIds) {
      unawaited(_db.updateMessageStatus(id, status.deliveryState));
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> data) {
    final userId = data['user_id']?.toString();
    final isOnline = data['is_online'] == true;
    if (userId == null) return;
    bool changed = false;
    for (int i = 0; i < _chats.length; i++) {
      if (_chats[i].receiverId == userId && _chats[i].isOnline != isOnline) {
        _chats[i] = _chats[i].copyWith(isOnline: isOnline);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  bool _isDuplicateMessageEvent(Message message) {
    final key = '${message.chatId}:${message.clientUuid}:${message.id}';
    if (_recentMessageEventKeys.contains(key)) return true;
    _recentMessageEventKeys.add(key);
    _recentMessageEventOrder.add(key);
    if (_recentMessageEventOrder.length > _maxRecentMessageEvents) {
      final oldest = _recentMessageEventOrder.removeAt(0);
      _recentMessageEventKeys.remove(oldest);
    }
    return false;
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _statusSubscription?.cancel();
    _deleteSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }
}
