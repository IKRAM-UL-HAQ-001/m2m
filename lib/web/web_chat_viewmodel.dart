import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

/// Web-only chat-list state. Online-only: chats live in memory, sourced from the
/// API and kept live via the shared [SocketService]. No local database.
class WebChatViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  List<Chat> _chats = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  String? _activeChatId;

  StreamSubscription<Message>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  String? get activeChatId => _activeChatId;

  List<Chat> get visibleChats {
    if (_searchQuery.trim().isEmpty) return _chats;
    final q = _searchQuery.toLowerCase();
    return _chats
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.lastMessage.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q),
        )
        .toList();
  }

  void init() {
    _listenToSocket();
    fetchChats();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
    if (chatId != null) {
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index != -1 && _chats[index].unreadCount > 0) {
        _chats[index] = _chats[index].copyWith(unreadCount: 0);
        notifyListeners();
      }
    }
  }

  void _listenToSocket() {
    _messageSub = _socketService.messageStream.listen(_onIncomingMessage);
    _presenceSub = _socketService.presenceStream.listen((data) {
      final userId = data['user_id']?.toString();
      final isOnline = data['is_online'] == true;
      if (userId == null) return;
      var changed = false;
      _chats = _chats.map((c) {
        if (c.receiverId == userId && c.isOnline != isOnline) {
          changed = true;
          return c.copyWith(isOnline: isOnline);
        }
        return c;
      }).toList();
      if (changed) notifyListeners();
    });
  }

  void _onIncomingMessage(Message message) {
    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index == -1) {
      // Unknown chat (e.g. first message from a new contact)  resync.
      unawaited(fetchChats(isSilent: true));
      return;
    }
    final chat = _chats[index];
    final isActive = _activeChatId == message.chatId;
    final bumpUnread = !message.isMe && !isActive;
    final updated = chat.copyWith(
      lastMessage: message.text.isNotEmpty ? message.text : chat.lastMessage,
      lastMessageType: message.type,
      time: message.time,
      unreadCount: bumpUnread ? chat.unreadCount + 1 : chat.unreadCount,
    );
    _chats.removeAt(index);
    _chats.insert(0, updated);
    notifyListeners();
  }

  Future<void> fetchChats({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final chats = await _apiService.getChats(limit: 30);
      _chats = chats;
      _hasMore = chats.length >= 30;
    } catch (e) {
      debugPrint('fetchChats failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _searchQuery.isNotEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final more = await _apiService.getChats(offset: _chats.length, limit: 30);
      final existingIds = _chats.map((c) => c.id).toSet();
      _chats.addAll(more.where((c) => !existingIds.contains(c.id)));
      _hasMore = more.length >= 30;
    } catch (e) {
      debugPrint('loadMore chats failed: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markChatRead(String chatId) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1 && _chats[index].unreadCount > 0) {
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
    try {
      await _apiService.markChatRead(chatId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }
}
