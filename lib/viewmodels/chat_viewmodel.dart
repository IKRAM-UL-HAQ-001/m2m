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

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get activeChatId => _activeChatId;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  ChatViewModel() {
    _socketSubscription = _socketService.messageStream.listen((message) {
      _handleNewMessage(message);
    });
  }

  void handleAuthState(bool isAuthenticated) {
    if (_isAuthenticated == isAuthenticated) return;
    _isAuthenticated = isAuthenticated;

    if (!_isAuthenticated) {
      _activeChatId = null;
      _chats = [];
      _isLoading = false;
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
    _chats[index] = Chat(
      id: chat.id,
      receiverId: chat.receiverId,
      name: chat.name,
      avatarUrl: chat.avatarUrl,
      lastMessage: chat.lastMessage,
      lastMessageType: chat.lastMessageType,
      lastMessageFileUrl: chat.lastMessageFileUrl,
      time: chat.time,
      unreadCount: 0,
    );
    notifyListeners();
  }

  void _handleNewMessage(Message message) {
    // Find the chat and update its last message and unread count
    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index != -1) {
      final chat = _chats[index];
      final nextUnreadCount = message.chatId == _activeChatId
          ? 0
          : (message.isMe ? chat.unreadCount : chat.unreadCount + 1);
      _chats[index] = Chat(
        id: message.chatId, // Update the ID too, in case it was a placeholder
        receiverId: chat.receiverId,
        name: chat.name,
        avatarUrl: chat.avatarUrl,
        lastMessage: message.text,
        lastMessageType: message.type,
        lastMessageFileUrl: message.fileUrl,
        time: message.time,
        unreadCount: nextUnreadCount,
      );
      // Move to top
      final updatedChat = _chats.removeAt(index);
      _chats.insert(0, updatedChat);
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

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}
