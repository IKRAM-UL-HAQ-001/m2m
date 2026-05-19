import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/url_helper.dart';

class ForwardContactPickerSheet extends StatefulWidget {
  const ForwardContactPickerSheet({
    super.key,
    required this.message,
    required this.onContactsSelected,
  });

  final Message message;
  final ValueChanged<List<String>> onContactsSelected;

  @override
  State<ForwardContactPickerSheet> createState() =>
      _ForwardContactPickerSheetState();
}

class _ForwardContactPickerSheetState extends State<ForwardContactPickerSheet> {
  final Set<String> _selectedChatIds = {};
  final ApiService _apiService = ApiService();
  List<Chat> _chats = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _apiService.getChats(limit: 50);
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase();
    final filtered = _chats
        .where((chat) => chat.name.toLowerCase().contains(query))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Forward to',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedChatIds.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        widget.onContactsSelected(_selectedChatIds.toList()),
                    child: Text(
                      'Send (${_selectedChatIds.length})',
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.reply,
                  color: AppColors.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getForwardPreviewText(widget.message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final chat = filtered[index];
                      final isSelected = _selectedChatIds.contains(chat.id);
                      final avatarUrl = UrlHelper.fixUrl(chat.avatarUrl);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          chat.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _subtitleFor(chat),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primaryColor
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        onTap: () => _toggleSelection(chat.id, isSelected),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String chatId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedChatIds.remove(chatId);
      } else if (_selectedChatIds.length < 5) {
        _selectedChatIds.add(chatId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Can forward to max 5 chats at once')),
        );
      }
    });
  }

  String _subtitleFor(Chat chat) {
    switch (chat.lastMessageType) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'document':
        return 'Document';
      default:
        return chat.lastMessage;
    }
  }

  String _getForwardPreviewText(Message message) {
    switch (message.type) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'document':
        return message.fileName ?? 'Document';
      default:
        return message.text;
    }
  }
}
