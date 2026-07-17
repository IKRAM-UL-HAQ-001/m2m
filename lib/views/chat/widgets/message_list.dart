import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/message.dart';
import '../../../utils/constants.dart';
import 'message_album.dart';
import 'message_tile.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.isLoadingMore,
    required this.scrollController,
    required this.highlightedMessageId,
    required this.targetKeyForId,
    required this.downloadedUrls,
    required this.onLongPressMessage,
    required this.onReplyTap,
    this.onOpenStatusReply,
    required this.onOpenMediaPreview,
    required this.onOpenAlbum,
    required this.onDownloadImage,
    required this.onOpenFile,
    required this.onShowReactionUsers,
    this.onDownloadFile,
    this.downloadingFileIds = const {},
    this.selectedMessageIds = const {},
    this.isSelectionMode = false,
    this.onTapMessage,
  });

  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final String? highlightedMessageId;
  final GlobalKey? Function(String messageId) targetKeyForId;
  final Set<String> downloadedUrls;
  final ValueChanged<Message> onLongPressMessage;
  final ValueChanged<String?> onReplyTap;
  final ValueChanged<StatusReply>? onOpenStatusReply;
  final ValueChanged<Message> onOpenMediaPreview;
  final void Function(List<Message> album, int index) onOpenAlbum;
  final ValueChanged<String> onDownloadImage;
  final ValueChanged<String> onOpenFile;
  final void Function(String emoji, List<String> userIds) onShowReactionUsers;
  final ValueChanged<Message>? onDownloadFile;
  final Set<String> downloadingFileIds;
  final Set<String> selectedMessageIds;
  final bool isSelectionMode;
  final ValueChanged<Message>? onTapMessage;

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
          : Builder(
              builder: (context) {
                // Group adjacent media into WhatsApp-style albums. Disabled in
                // selection mode so every photo stays individually selectable.
                final items = buildRenderItems(
                  messages,
                  enableGrouping: !isSelectionMode,
                );
                return ListView.builder(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  reverse: true,
                  addAutomaticKeepAlives: false,
                  itemCount: items.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final item = items[index];
                    final showDate =
                        index == items.length - 1 ||
                        !_isSameDay(item.refTime, items[index + 1].refTime);

                    return Column(
                      children: [
                        if (showDate) _buildDateChip(item.refTime),
                        _buildItem(item),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildItem(MessageRenderItem item) {
    if (item is AlbumRenderItem) {
      final isHighlighted =
          highlightedMessageId != null &&
          item.containsId(highlightedMessageId!);
      // Reuse a contained message's scroll-target key so reply-jumps still land
      // on the album.
      GlobalKey? targetKey;
      for (final m in item.messages) {
        targetKey = targetKeyForId(m.id);
        if (targetKey != null) break;
      }
      final tile = AlbumMessageTile(
        messages: item.messages,
        isHighlighted: isHighlighted,
        onOpen: (i) => onOpenAlbum(item.messages, i),
        onLongPress: () => onLongPressMessage(item.messages.last),
      );
      return RepaintBoundary(
        key: ValueKey('album_${item.messages.first.id}'),
        child: targetKey == null
            ? tile
            : KeyedSubtree(key: targetKey, child: tile),
      );
    }

    final message = (item as SingleRenderItem).message;
    final tile = MessageTile(
      message: message,
      isHighlighted: highlightedMessageId == message.id,
      downloadedUrls: downloadedUrls,
      onLongPress: onLongPressMessage,
      onReplyTap: onReplyTap,
      onOpenStatusReply: onOpenStatusReply,
      onOpenMediaPreview: onOpenMediaPreview,
      onDownloadImage: onDownloadImage,
      onOpenFile: onOpenFile,
      onShowReactionUsers: onShowReactionUsers,
      onDownloadFile: onDownloadFile,
      isDownloadingFile: downloadingFileIds.contains(message.id),
      isSelected: selectedMessageIds.contains(message.id),
      isSelectionMode: isSelectionMode,
      onTap: onTapMessage != null ? () => onTapMessage!(message) : null,
    );
    final targetKey = targetKeyForId(message.id);
    return RepaintBoundary(
      key: ValueKey('message_${message.id}'),
      child: targetKey == null
          ? tile
          : KeyedSubtree(key: targetKey, child: tile),
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
