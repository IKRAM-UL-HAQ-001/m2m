import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/profile_quick_modal.dart';
import '../widgets/search_results_list.dart';
import 'chat_detail_screen.dart';

class ChatsListView extends StatelessWidget {
  final Function(Chat)? onChatTap;
  final String searchQuery;
  const ChatsListView({super.key, this.onChatTap, this.searchQuery = ''});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(time.year, time.month, time.day);
    if (d == today) return DateFormat('hh:mm a').format(time);
    if (d == yesterday) return 'Yesterday';
    if (now.difference(time).inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('MM/dd/yy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, _) {
        if (chatViewModel.isLoading && chatViewModel.chats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (chatViewModel.chats.isEmpty) {
          return const Center(
            child: Text(
              'No chats yet.\nTap the message icon to start one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          );
        }
        if (searchQuery.isNotEmpty) {
          return SearchResultsList<Chat>(
            query: searchQuery,
            allItems: chatViewModel.chats,
            getSearchableText: (chat) => chat.name,
            buildTile: (chat, isExact) =>
                _buildChatTile(context, chat, highlightQuery: searchQuery),
          );
        }
        return RefreshIndicator(
          onRefresh: () => chatViewModel.fetchChats(),
          child: ListView.separated(
            itemCount: chatViewModel.chats.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 0, indent: 72),
            itemBuilder: (context, index) {
              final chat = chatViewModel.chats[index];
              return _buildChatTile(context, chat);
            },
          ),
        );
      },
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    Chat chat, {
    String highlightQuery = '',
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Stack(
        children: [
          GestureDetector(
            onTap: () => ProfileQuickModal.show(
              context,
              userId: chat.receiverId,
              name: chat.name,
              phone: chat.phone,
              about: chat.about,
              avatarUrl: chat.avatarUrl,
              isOnline: chat.isOnline,
              onMessage: () => _openChat(context, chat),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[300],
              backgroundImage: chat.avatarUrl.isNotEmpty
                  ? NetworkImage(chat.avatarUrl)
                  : null,
              child: chat.avatarUrl.isEmpty
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
            ),
          ),
          if (chat.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: buildHighlightedText(
              chat.name,
              highlightQuery,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(chat.time),
            style: TextStyle(
              color: chat.unreadCount > 0
                  ? const Color(0xFF25D366)
                  : Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(child: _buildLastMessage(chat)),
            if (chat.unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      onTap: () async {
        await _openChat(context, chat);
      },
    );
  }

  Future<void> _openChat(BuildContext context, Chat chat) async {
    if (onChatTap != null) {
      onChatTap!(chat);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
    );
    if (context.mounted) {
      context.read<ChatViewModel>().fetchChats();
    }
  }

  Widget _buildLastMessage(Chat chat) {
    switch (chat.lastMessageType) {
      case 'image':
        return Row(
          children: const [
            Icon(Icons.photo, size: 15, color: Colors.grey),
            SizedBox(width: 4),
            Text('Photo', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        );
      case 'video':
        return Row(
          children: const [
            Icon(Icons.videocam, size: 15, color: Colors.grey),
            SizedBox(width: 4),
            Text('Video', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        );
      case 'audio':
        return Row(
          children: const [
            Icon(Icons.mic, size: 15, color: Color(0xFF25D366)),
            SizedBox(width: 4),
            Text(
              'Voice message',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        );
      case 'document':
        return Row(
          children: const [
            Icon(Icons.insert_drive_file, size: 15, color: Colors.grey),
            SizedBox(width: 4),
            Text(
              'Document',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        );
      default:
        return Text(
          chat.lastMessage.isEmpty ? '' : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        );
    }
  }
}
