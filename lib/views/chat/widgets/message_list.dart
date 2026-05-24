import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/message.dart';
import '../../../utils/constants.dart';
import 'message_tile.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.highlightedMessageId,
    required this.targetKeyForId,
    required this.downloadedUrls,
    required this.onLongPressMessage,
    required this.onReplyTap,
    required this.onOpenMediaPreview,
    required this.onDownloadImage,
    required this.onOpenFile,
    required this.onShowReactionUsers,
  });

  final List<Message> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final String? highlightedMessageId;
  final GlobalKey? Function(String messageId) targetKeyForId;
  final Set<String> downloadedUrls;
  final ValueChanged<Message> onLongPressMessage;
  final ValueChanged<String?> onReplyTap;
  final ValueChanged<Message> onOpenMediaPreview;
  final ValueChanged<String> onDownloadImage;
  final ValueChanged<String> onOpenFile;
  final void Function(String emoji, List<String> userIds) onShowReactionUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chatBackgroundColor,
        image: const DecorationImage(
          image: CachedNetworkImageProvider(
            'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
          ),
          fit: BoxFit.cover,
          opacity: 0.15,
        ),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
          ? const Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              reverse: true,
              addAutomaticKeepAlives: false,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final showDate =
                    index == messages.length - 1 ||
                    !_isSameDay(message.time, messages[index + 1].time);
                final isHighlighted = highlightedMessageId == message.id;
                final tile = MessageTile(
                  message: message,
                  isHighlighted: isHighlighted,
                  downloadedUrls: downloadedUrls,
                  onLongPress: onLongPressMessage,
                  onReplyTap: onReplyTap,
                  onOpenMediaPreview: onOpenMediaPreview,
                  onDownloadImage: onDownloadImage,
                  onOpenFile: onOpenFile,
                  onShowReactionUsers: onShowReactionUsers,
                );
                final targetKey = targetKeyForId(message.id);

                return Column(
                  children: [
                    if (showDate) _buildDateChip(message.time),
                    RepaintBoundary(
                      key: ValueKey('message_${message.id}'),
                      child: targetKey == null
                          ? tile
                          : KeyedSubtree(key: targetKey, child: tile),
                    ),
                  ],
                );
              },
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateChip(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    final String label;
    if (d == today) {
      label = 'Today';
    } else if (d == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, y').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
