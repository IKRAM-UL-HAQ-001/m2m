import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'web_chat_viewmodel.dart';

/// Sidebar conversation list for the web layout.
class WebChatList extends StatefulWidget {
  final void Function(Chat chat) onChatTap;
  final String? selectedChatId;

  const WebChatList({
    super.key,
    required this.onChatTap,
    this.selectedChatId,
  });

  @override
  State<WebChatList> createState() => _WebChatListState();
}

class _WebChatListState extends State<WebChatList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<WebChatViewModel>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WebChatViewModel>();
    if (vm.isLoading && vm.chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final chats = vm.visibleChats;
    if (chats.isEmpty) {
      return Center(
        child: Text(
          vm.searchQuery.isEmpty ? 'No chats yet' : 'No results',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: chats.length + (vm.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chats.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _tile(chats[index]);
      },
    );
  }

  Widget _tile(Chat chat) {
    final selected = chat.id == widget.selectedChatId;
    return InkWell(
      onTap: () => widget.onChatTap(chat),
      child: Container(
        color: selected ? Colors.grey[200] : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: chat.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          ApiService.mediaUrl(chat.avatarUrl),
                        )
                      : null,
                  child: chat.avatarUrl.isEmpty
                      ? Icon(Icons.person, color: Colors.grey[600])
                      : null,
                ),
                if (chat.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(chat.time),
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.unreadCount > 0
                              ? AppColors.primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(chat),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _preview(Chat chat) {
    switch (chat.lastMessageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎬 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'document':
        return '📎 Document';
      default:
        return chat.lastMessage;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    if (now.difference(local).inDays == 0 &&
        now.day == local.day) {
      return DateFormat('hh:mm a').format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('dd/MM/yy').format(local);
  }
}
