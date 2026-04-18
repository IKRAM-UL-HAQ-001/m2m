import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatViewModel extends ChangeNotifier {
  List<Chat> _chats = [];
  bool _isLoading = false;
  StreamSubscription<Message>? _socketSubscription;

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  ChatViewModel() {
    _loadUserId().then((_) {
      fetchChats();
      _initSocket();
    });
  }

  Future<void> _loadUserId() async {
    if (ApiService.currentUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      ApiService.currentUserId = prefs.getString('user_id');
    }
  }

  void _initSocket() {
    _socketService.connect();
    _socketSubscription = _socketService.messageStream.listen((message) {
      _handleNewMessage(message);
    });
  }

  void _handleNewMessage(Message message) {
    // Find the chat and update its last message and unread count
    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index != -1) {
      final chat = _chats[index];
      _chats[index] = Chat(
        id: message.chatId, // Update the ID too, in case it was a placeholder
        receiverId: chat.receiverId,
        name: chat.name,
        avatarUrl: chat.avatarUrl,
        lastMessage: message.text,
        lastMessageType: message.type,
        lastMessageFileUrl: message.fileUrl,
        time: message.time,
        unreadCount: message.isMe ? chat.unreadCount : chat.unreadCount + 1,
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
