import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/message.dart';
import '../../../services/api_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/responsive.dart';

class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.message,
    required this.isHighlighted,
    required this.downloadedUrls,
    required this.onLongPress,
    required this.onReplyTap,
    required this.onOpenMediaPreview,
    required this.onDownloadImage,
    required this.onOpenFile,
    required this.onShowReactionUsers,
  });

  final Message message;
  final bool isHighlighted;
  final Set<String> downloadedUrls;
  final ValueChanged<Message> onLongPress;
  final ValueChanged<String?> onReplyTap;
  final ValueChanged<Message> onOpenMediaPreview;
  final ValueChanged<String> onDownloadImage;
  final ValueChanged<String> onOpenFile;
  final void Function(String emoji, List<String> userIds) onShowReactionUsers;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final hasFile = message.fileUrl != null && message.fileUrl!.isNotEmpty;
    final url = message.fileUrl ?? '';
    final isImage = hasFile && (message.type == 'image' || _isImageUrl(url));
    final isAudio = hasFile && (message.type == 'audio' || _isAudioUrl(url));
    final isVideo = hasFile && (message.type == 'video' || _isVideoUrl(url));
    final isDocument = hasFile && !isImage && !isAudio && !isVideo;
    final isDeleted = message.isDeletedForEveryone;

    return GestureDetector(
      onLongPress: () => onLongPress(message),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.bubbleMaxWidth),
          child: Container(
            padding: const EdgeInsets.all(8),
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
                      bottomRight: Radius.circular(3),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted
                      ? AppColors.primaryColor.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: isHighlighted ? 8 : 2,
                  offset: Offset(0, isHighlighted ? 2 : 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDeleted)
                  Text(
                    '🚫 This message was deleted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                if (!isDeleted && message.replyToId != null)
                  _buildReplyQuote(message, isMe),
                if (!isDeleted && message.isForwarded) _buildForwardedLabel(),
                if (!isDeleted && isImage) _buildImageContent(message),
                if (!isDeleted && isVideo) _buildVideoContent(message),
                if (!isDeleted && isAudio) _buildAudioContent(message, isMe),
                if (!isDeleted && isDocument) _buildDocumentContent(message),
                if (!isDeleted &&
                    message.text.isNotEmpty &&
                    message.text != '[File]') ...[
                  if (hasFile) const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ],
                const SizedBox(height: 2),
                _buildTimestampRow(message, isMe),
                if (message.reactions.isNotEmpty) _buildReactions(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyQuote(Message message, bool isMe) {
    return InkWell(
      onTap: () => onReplyTap(message.replyToId),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(color: AppColors.primaryColor, width: 3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _replySummary(
                  text: message.replyToText,
                  type: message.replyToType,
                  fileName: message.replyToFileName,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (_hasReplyMedia(message)) ...[
              const SizedBox(width: 8),
              _buildReplyMediaThumb(
                type: message.replyToType,
                fileUrl: message.replyToFileUrl,
                thumbnailUrl: message.replyToThumbnailUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasReplyMedia(Message message) {
    return (message.replyToFileUrl != null &&
            message.replyToFileUrl!.isNotEmpty) ||
        (message.replyToThumbnailUrl != null &&
            message.replyToThumbnailUrl!.isNotEmpty) ||
        message.replyToType == 'image' ||
        message.replyToType == 'video' ||
        message.replyToType == 'audio' ||
        message.replyToType == 'document';
  }

  String _replySummary({
    required String? text,
    required String? type,
    required String? fileName,
  }) {
    final cleanText = (text ?? '').trim();
    if (cleanText.isNotEmpty && cleanText != '[File]') return cleanText;
    switch (type) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'document':
        return fileName?.isNotEmpty == true ? fileName! : 'Document';
      default:
        return cleanText.isNotEmpty ? cleanText : 'Message';
    }
  }

  Widget _buildReplyMediaThumb({
    required String? type,
    required String? fileUrl,
    required String? thumbnailUrl,
  }) {
    final isImage =
        type == 'image' || (fileUrl != null && _isImageUrl(fileUrl));
    final isVideo =
        type == 'video' || (fileUrl != null && _isVideoUrl(fileUrl));
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final previewUrl = ApiService.mediaUrl(
      hasThumbnail || isImage ? (thumbnailUrl ?? fileUrl) : null,
    );

    if (previewUrl.isNotEmpty && (isImage || isVideo)) {
      return _replyImageTile(
        imageUrl: previewUrl,
        showPlay: isVideo,
        fallbackType: type,
      );
    }
    if (isVideo) return _replyVideoTile();
    return _replyIcon(type);
  }

  Widget _replyImageTile({
    required String imageUrl,
    required bool showPlay,
    required String? fallbackType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            width: 44,
            height: 44,
            memCacheWidth: 88,
            memCacheHeight: 88,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _replyIcon(fallbackType),
          ),
          if (showPlay) _replyPlayBadge(),
        ],
      ),
    );
  }

  Widget _replyVideoTile() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 22,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          _replyPlayBadge(),
        ],
      ),
    );
  }

  Widget _replyPlayBadge() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
    );
  }

  Widget _replyIcon(String? type) {
    final icon = switch (type) {
      'image' => Icons.image,
      'video' => Icons.videocam,
      'audio' => Icons.mic,
      'document' => Icons.insert_drive_file,
      _ => Icons.reply,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 22, color: Colors.black45),
    );
  }

  Widget _buildForwardedLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.reply, size: 13, color: Colors.black45),
          SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(Message message) {
    final imageUrl = ApiService.mediaUrl(message.fileUrl);
    return GestureDetector(
      onTap: () => onOpenMediaPreview(message),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Hero(
              tag: 'media-${message.id}',
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 180,
                  maxWidth: 260,
                  minHeight: 140,
                  maxHeight: 320,
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(width: 220, height: 180, color: Colors.black12),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          ),
          if (!downloadedUrls.contains(message.fileUrl!))
            Positioned(
              right: 4,
              bottom: 4,
              child: GestureDetector(
                onTap: () => onDownloadImage(message.fileUrl!),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(Message message) {
    return GestureDetector(
      onTap: () => onOpenMediaPreview(message),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 220,
          height: 130,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
              SizedBox(height: 6),
              Text(
                'Tap to play',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(Message message, bool isMe) {
    return AudioPlayerWidget(url: message.fileUrl!, isMe: isMe);
  }

  Widget _buildDocumentContent(Message message) {
    final fileName =
        message.fileName ?? message.fileUrl!.split('/').last.split('?').first;
    return InkWell(
      onTap: () => onOpenFile(message.fileUrl!),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file,
              color: AppColors.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                style: const TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampRow(Message message, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (message.editedAt != null) ...[
          const Text(
            'edited',
            style: TextStyle(color: Colors.black45, fontSize: 11),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          DateFormat('hh:mm a').format(message.time.toLocal()),
          style: const TextStyle(color: Colors.black45, fontSize: 11),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          _buildTick(message.deliveryState),
        ],
      ],
    );
  }

  Widget _buildReactions(Message message) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.entries.map((entry) {
          return GestureDetector(
            onTap: () => onShowReactionUsers(entry.key, entry.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                '${entry.key} ${entry.value.length}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTick(MessageStatus state) {
    switch (state) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 13, color: Colors.black38);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: Colors.black38);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 13, color: Colors.black38);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 13, color: Color(0xFF4FC3F7));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 13, color: Colors.red);
    }
  }

  bool _isImageUrl(String url) {
    final l = url.toLowerCase().split('?').first;
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.gif') ||
        l.endsWith('.webp');
  }

  bool _isAudioUrl(String url) {
    final l = url.toLowerCase().split('?').first;
    return l.endsWith('.mp3') ||
        l.endsWith('.m4a') ||
        l.endsWith('.aac') ||
        l.endsWith('.wav') ||
        l.endsWith('.ogg') ||
        l.endsWith('.opus');
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
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;
  const AudioPlayerWidget({super.key, required this.url, this.isMe = false});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player
        .setSource(UrlSource(widget.url))
        .then((_) async {
          final d = await _player.getDuration();
          if (mounted) {
            setState(() {
              if (d != null) _duration = d;
              _isLoading = false;
            });
          }
        })
        .catchError((e) {
          if (mounted) setState(() => _isLoading = false);
        });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sliderValue = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isLoading) return;
              try {
                if (_isPlaying) {
                  await _player.pause();
                  setState(() => _isPlaying = false);
                } else {
                  if (_position == _duration && _duration != Duration.zero) {
                    await _player.seek(Duration.zero);
                  }
                  await _player.resume();
                  setState(() => _isPlaying = true);
                }
              } catch (e) {
                debugPrint('Audio error: $e');
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryColor,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    trackHeight: 2.5,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: sliderValue,
                    onChanged: (v) {
                      final pos = Duration(
                        milliseconds: (v * _duration.inMilliseconds).round(),
                      );
                      _player.seek(pos);
                    },
                    activeColor: AppColors.primaryColor,
                    inactiveColor: Colors.grey[300],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _isPlaying ? _fmt(_position) : _fmt(_duration),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
