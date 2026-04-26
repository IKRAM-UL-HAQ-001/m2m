import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';
import 'dart:async';
import '../viewmodels/chat_viewmodel.dart';

class WebChatView extends StatefulWidget {
  final Chat chat;
  const WebChatView({super.key, required this.chat});

  @override
  State<WebChatView> createState() => _WebChatViewState();
}

class _WebChatViewState extends State<WebChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _showSendIcon = false;
  List<Message> _messages = [];
  bool _isLoading = true;
  StreamSubscription<Message>? _socketSubscription;
  StreamSubscription<MessageStatusUpdate>? _messageStatusSubscription;
  late final ChatViewModel _chatViewModel;

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();
    _chatViewModel.setActiveChat(widget.chat.id);
    _loadMessages();
    _initSocket();
  }

  @override
  void didUpdateWidget(WebChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _chatViewModel.setActiveChat(widget.chat.id);
      _loadMessages();
    }
  }

  void _initSocket() {
    _socketSubscription?.cancel();
    _messageStatusSubscription?.cancel();
    _socketSubscription = SocketService().messageStream.listen((message) {
      if (message.chatId == widget.chat.id) {
        setState(() {
          _upsertMessage(message);
        });
      }
    });
    _messageStatusSubscription = SocketService().messageStatusStream.listen((status) {
      if (status.chatId == widget.chat.id) {
        setState(() {
          _applyMessageStatus(status);
        });
      }
    });
  }

  void _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _apiService.getMessages(widget.chat.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _chatViewModel.markChatRead(widget.chat.id);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _upsertMessage(Message message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex == -1) {
      _messages.insert(0, message);
      return;
    }

    final currentMessage = _messages[existingIndex];
    _messages[existingIndex] = message.copyWith(
      isDelivered: currentMessage.isDelivered || message.isDelivered,
      isRead: currentMessage.isRead || message.isRead,
    );
  }

  void _applyMessageStatus(MessageStatusUpdate status) {
    final existingIndex = _messages.indexWhere((item) => item.id == status.messageId);
    if (existingIndex == -1) return;

    final currentMessage = _messages[existingIndex];
    _messages[existingIndex] = currentMessage.copyWith(
      isDelivered: currentMessage.isDelivered || status.isDelivered,
      isRead: currentMessage.isRead || status.isRead,
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _messageController.clear();
      setState(() => _showSendIcon = false);
      final message = await _apiService.sendMessage(widget.chat.receiverId, text);
      if (message != null) {
        setState(() {
          _upsertMessage(message);
        });
      }
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _messageStatusSubscription?.cancel();
    if (_chatViewModel.activeChatId == widget.chat.id) {
      _chatViewModel.setActiveChat(null);
    }
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat Header
        Container(
          height: 60,
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.chat.avatarUrl.isNotEmpty 
                    ? NetworkImage(widget.chat.avatarUrl) 
                    : null,
                child: widget.chat.avatarUrl.isEmpty 
                    ? const Icon(Icons.person, color: Colors.grey) 
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Online",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () {}),
            ],
          ),
        ),
        
        // Messages Area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.chatBackgroundColor,
              image: const DecorationImage(
                image: NetworkImage("https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png"),
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessage(message);
                  },
                ),
          ),
        ),
        
        // Message Composer
        Container(
          height: 62,
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.insert_emoticon, color: Colors.grey), onPressed: () {}),
              IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () {}),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onChanged: (val) => setState(() => _showSendIcon = val.trim().isNotEmpty),
                  decoration: const InputDecoration(
                    hintText: "Type a message",
                    border: InputBorder.none,
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  _showSendIcon ? Icons.send : Icons.mic,
                  color: AppColors.primaryColor,
                ),
                onPressed: _showSendIcon ? _sendMessage : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(Message message) {
    bool isMe = message.isMe;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.45),
        decoration: BoxDecoration(
          color: isMe ? AppColors.outgoingMessageColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              spreadRadius: 1,
              blurRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(message.time.toLocal()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
