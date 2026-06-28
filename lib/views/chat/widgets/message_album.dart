import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/message.dart';
import '../../../services/api_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/responsive.dart';

/// Adjacent media messages sent close together are rendered as a single
/// WhatsApp-style album. Two messages this far apart (or more) stay in separate
/// bubbles, matching how WhatsApp only groups a single "send" batch.
const Duration _albumTimeWindow = Duration(seconds: 90);

bool _isImageUrl(String url) {
  final l = url.toLowerCase().split('?').first;
  return l.endsWith('.jpg') ||
      l.endsWith('.jpeg') ||
      l.endsWith('.png') ||
      l.endsWith('.gif') ||
      l.endsWith('.webp');
}

bool _isVideoUrl(String url) {
  final l = url.toLowerCase().split('?').first;
  return l.endsWith('.mp4') ||
      l.endsWith('.mov') ||
      l.endsWith('.avi') ||
      l.endsWith('.mkv') ||
      l.endsWith('.3gp') ||
      l.endsWith('.webm');
}

bool isVideoMessage(Message m) {
  final url = m.fileUrl ?? m.localFilePath ?? '';
  return m.type == 'video' || _isVideoUrl(url);
}

/// Whether a message can be absorbed into an album. Replies, reactions,
/// forwards and deleted messages keep their own bubble so their extra chrome
/// (quote, reaction chips, "Forwarded" label) isn't lost.
bool isAlbumCandidate(Message m) {
  if (m.isDeletedForEveryone || m.isDeletedForMe) return false;
  if (m.isForwarded) return false;
  if (m.replyToId != null) return false;
  if (m.reactions.isNotEmpty) return false;
  final hasFile =
      (m.fileUrl?.isNotEmpty ?? false) || (m.localFilePath?.isNotEmpty ?? false);
  if (!hasFile) return false;
  final url = m.fileUrl ?? m.localFilePath ?? '';
  return m.type == 'image' ||
      m.type == 'video' ||
      _isImageUrl(url) ||
      _isVideoUrl(url);
}

/// One row in the message list: either a standalone message or a media album.
sealed class MessageRenderItem {
  const MessageRenderItem();

  /// Timestamp used for date-separator boundaries (newest message in the item).
  DateTime get refTime;

  bool containsId(String id);

  List<Message> get all;
}

class SingleRenderItem extends MessageRenderItem {
  const SingleRenderItem(this.message);
  final Message message;

  @override
  DateTime get refTime => message.time;

  @override
  bool containsId(String id) => message.id == id;

  @override
  List<Message> get all => [message];
}

class AlbumRenderItem extends MessageRenderItem {
  /// Oldest-first (first sent → first cell), matching WhatsApp ordering.
  const AlbumRenderItem(this.messages);
  final List<Message> messages;

  @override
  DateTime get refTime => messages.last.time;

  @override
  bool containsId(String id) => messages.any((m) => m.id == id);

  @override
  List<Message> get all => messages;
}

/// Groups a newest-first message list into render items. When [enableGrouping]
/// is false (e.g. selection mode) every message stays standalone so per-item
/// actions keep working.
List<MessageRenderItem> buildRenderItems(
  List<Message> messages, {
  bool enableGrouping = true,
}) {
  if (!enableGrouping) {
    return messages.map((m) => SingleRenderItem(m)).toList();
  }
  final items = <MessageRenderItem>[];
  var i = 0;
  while (i < messages.length) {
    final head = messages[i];
    if (isAlbumCandidate(head)) {
      // Walk toward older messages collecting an unbroken run from the same
      // sender within the time window.
      final run = <Message>[head];
      var j = i + 1;
      while (j < messages.length) {
        final next = messages[j];
        final gap = run.last.time.difference(next.time).abs();
        if (isAlbumCandidate(next) &&
            next.senderId == head.senderId &&
            next.isMe == head.isMe &&
            gap <= _albumTimeWindow) {
          run.add(next);
          j++;
        } else {
          break;
        }
      }
      if (run.length >= 2) {
        items.add(AlbumRenderItem(run.reversed.toList()));
        i = j;
        continue;
      }
    }
    items.add(SingleRenderItem(head));
    i++;
  }
  return items;
}

/// WhatsApp-style album grid bubble. Lays out 2/3/4/4+ media and exposes a
/// single tap target per cell plus one timestamp for the whole group.
class AlbumMessageTile extends StatelessWidget {
  const AlbumMessageTile({
    super.key,
    required this.messages,
    required this.isHighlighted,
    required this.onOpen,
    required this.onLongPress,
  });

  /// Oldest-first display order.
  final List<Message> messages;
  final bool isHighlighted;

  /// Called with the tapped cell's index into [messages].
  final void Function(int index) onOpen;
  final VoidCallback onLongPress;

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final isMe = messages.last.isMe;
    final width = Responsive.bubbleMaxWidth.clamp(0.0, 250.0).toDouble();

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isHighlighted
                ? const Color(0xFFFFF2A8)
                : isMe
                ? AppColors.outgoingMessageColor
                : Colors.white,
            borderRadius: isMe
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(4),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              children: [
                SizedBox(width: width, child: _buildGrid(width)),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _TimestampPill(message: messages.last),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(double w) {
    final n = messages.length;
    if (n == 2) {
      final h = (w - _gap) / 2;
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(child: _cell(0, h)),
            const SizedBox(width: _gap),
            Expanded(child: _cell(1, h)),
          ],
        ),
      );
    }
    if (n == 3) {
      final h = w * 0.66;
      final rightH = (h - _gap) / 2;
      return SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(flex: 6, child: _cell(0, h)),
            const SizedBox(width: _gap),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(child: _cell(1, rightH)),
                  const SizedBox(height: _gap),
                  Expanded(child: _cell(2, rightH)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // 4 or more → 2x2 with a "+N" overlay on the last visible cell.
    final cellH = (w - _gap) / 2;
    final remaining = n - 4;
    return SizedBox(
      height: w,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _cell(0, cellH)),
                const SizedBox(width: _gap),
                Expanded(child: _cell(1, cellH)),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _cell(2, cellH)),
                const SizedBox(width: _gap),
                Expanded(child: _cell(3, cellH, overflow: remaining)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int index, double size, {int overflow = 0}) {
    final message = messages[index];
    return GestureDetector(
      onTap: () => onOpen(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MediaThumb(message: message),
          if (isVideoMessage(message) && overflow == 0)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 38,
              ),
            ),
          if (overflow > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              alignment: Alignment.center,
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final localPath = message.localFilePath;
    final hasLocal =
        localPath != null && localPath.isNotEmpty && File(localPath).existsSync();
    if (hasLocal && !isVideoMessage(message)) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        cacheWidth: 400,
        errorBuilder: (_, _, _) => _broken(),
      );
    }
    final previewUrl =
        (message.thumbnailUrl != null && message.thumbnailUrl!.isNotEmpty)
        ? message.thumbnailUrl
        : message.fileUrl;
    final url = ApiService.mediaUrl(previewUrl);
    if (url.isEmpty) {
      return Container(color: const Color(0xFF1a1a2e), child: _broken());
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (_, _) => Container(color: Colors.black12),
      errorWidget: (_, _, _) => _broken(),
    );
  }

  Widget _broken() =>
      const Icon(Icons.broken_image, color: Colors.white54, size: 32);
}

class _TimestampPill extends StatelessWidget {
  const _TimestampPill({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('hh:mm a').format(message.time.toLocal()),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 3),
            _tick(message.deliveryState),
          ],
        ],
      ),
    );
  }

  Widget _tick(MessageStatus state) {
    switch (state) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Color(0xFF4FC3F7));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 12, color: Colors.red);
    }
  }
}
