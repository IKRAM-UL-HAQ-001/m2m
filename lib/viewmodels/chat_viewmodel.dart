import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatViewModel extends ChangeNotifier {
  List<Chat> _chats = [];
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _activeChatId;
  StreamSubscription<Message>? _socketSubscription;
  StreamSubscription<MessageStatusUpdate>? _statusSubscription;
  final Set<String> _recentMessageEventKeys = {};
  final List<String> _recentMessageEventOrder = [];
  static const int _maxRecentMessageEvents = 200;

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get activeChatId => _activeChatId;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  ChatViewModel() {
    _socketSubscription = _socketService.messageStream.listen((message) {
      _handleNewMessage(message);
    });
    _statusSubscription = _socketService.messageStatusStream.listen((status) {
      _handleStatusUpdate(status);
    });
  }

  void handleAuthState(bool isAuthenticated) {
    if (_isAuthenticated == isAuthenticated) return;
    _isAuthenticated = isAuthenticated;

    if (!_isAuthenticated) {
      _activeChatId = null;
      _chats = [];
      _isLoading = false;
      _recentMessageEventKeys.clear();
      _recentMessageEventOrder.clear();
      notifyListeners();
      return;
    }

    fetchChats(isSilent: true);
  }

  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }

  void markChatRead(String chatId) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1 || _chats[index].unreadCount == 0) return;

    final chat = _chats[index];
    _chats[index] = chat.copyWith(unreadCount: 0);
    notifyListeners();
  }

  void _handleNewMessage(Message message) {
    if (_isDuplicateMessageEvent(message)) return;
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
    } else {
      // If the chat is not in the list (e.g. brand new), fetch all chats to refresh state
      fetchChats(isSilent: true);
    }
  }

  Future<void> fetchChats({bool isSilent = false}) async {
    if (!_isAuthenticated) return;

    if (!isSilent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _chats = await _apiService.getChats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching chats from API: $e');
    }

    if (!isSilent) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleStatusUpdate(MessageStatusUpdate status) {
    final index = _chats.indexWhere((c) => c.id == status.chatId);
    if (index != -1) {
      final chat = _chats[index];
      if (chat.lastMessageStatus == status.deliveryState) return;
      _chats[index] = chat.copyWith(lastMessageStatus: status.deliveryState);
      notifyListeners();
    }
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
    super.dispose();
  }
}
