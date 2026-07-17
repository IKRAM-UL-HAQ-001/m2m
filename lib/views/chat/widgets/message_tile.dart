import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/message.dart';
import '../../../services/api_service.dart';
import '../../../services/database_service.dart';
import '../../../services/media_storage_service.dart';
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
    this.onOpenStatusReply,
    required this.onOpenMediaPreview,
    required this.onDownloadImage,
    required this.onOpenFile,
    required this.onShowReactionUsers,
    this.onDownloadFile,
    this.isDownloadingFile = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
  });

  final Message message;
  final bool isHighlighted;
  final Set<String> downloadedUrls;
  final ValueChanged<Message> onLongPress;
  final ValueChanged<String?> onReplyTap;
  final ValueChanged<StatusReply>? onOpenStatusReply;
  final ValueChanged<Message> onOpenMediaPreview;
  final ValueChanged<String> onDownloadImage;
  final ValueChanged<String> onOpenFile;
  final void Function(String emoji, List<String> userIds) onShowReactionUsers;

  /// WhatsApp-style: documents that aren't on-device yet are downloaded via
  /// this callback (then opened natively) instead of being launched in the
  /// browser. When null, tapping falls back to [onOpenFile] with the URL.
  final ValueChanged<Message>? onDownloadFile;
  final bool isDownloadingFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final localPath = message.localFilePath;
    final hasLocalFile =
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();
    final hasRemoteFile = message.fileUrl?.isNotEmpty ?? false;
    final hasFile = hasLocalFile || hasRemoteFile;
    final url = message.fileUrl ?? localPath ?? '';
    final isImage = hasFile && (message.type == 'image' || _isImageUrl(url));
    final isAudio = hasFile && (message.type == 'audio' || _isAudioUrl(url));
    final isVideo = hasFile && (message.type == 'video' || _isVideoUrl(url));
    final isDocument = hasFile && !isImage && !isAudio && !isVideo;
    final isDeleted = message.isDeletedForEveryone;

    return GestureDetector(
      onLongPress: () => onLongPress(message),
      onTap: onTap,
      child: Container(
        color: isSelected
            ? const Color(0xFF25D366).withValues(alpha: 0.18)
            : Colors.transparent,
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF25D366)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF25D366)
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
            Expanded(
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
                if (!isDeleted && message.statusReply != null)
                  _buildStatusReplyCard(context, message.statusReply!, isMe),
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
            ),
          ],
        ),
      ),
    );
  }

  // Preview card shown above a status-reply message so the recipient can see
  // which status the reply belongs to. Renders from the snapshot stored on the
  // message, so it works for both sender and receiver and survives the original
  // status expiring. Tapping tries to open the status (handled by the parent).
  Widget _buildStatusReplyCard(
    BuildContext context,
    StatusReply reply,
    bool isMe,
  ) {
    final isText = reply.mediaType == 'text';
    final isVideo = reply.mediaType == 'video';
    final summary = isText
        ? ((reply.caption ?? '').trim().isEmpty
              ? 'Text status'
              : reply.caption!.trim())
        : isVideo
        ? 'Video'
        : 'Photo';

    return InkWell(
      onTap: onOpenStatusReply == null
          ? null
          : () => onOpenStatusReply!(reply),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: AppColors.primaryColor, width: 3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.amp_stories,
                        size: 13,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Replied to status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusThumb(reply, isText: isText, isVideo: isVideo),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusThumb(
    StatusReply reply, {
    required bool isText,
    required bool isVideo,
  }) {
    const double w = 38, h = 50;
    final thumbUrl = (reply.thumbnailUrl?.isNotEmpty ?? false)
        ? reply.thumbnailUrl
        : reply.mediaUrl;

    Widget inner;
    if (isText || thumbUrl == null || thumbUrl.isEmpty) {
      final preview = (reply.caption ?? '').trim();
      inner = Container(
        color: AppColors.primaryColor.withValues(alpha: 0.15),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        child: Text(
          preview.isEmpty ? 'Aa' : preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ),
      );
    } else {
      inner = CachedNetworkImage(
        imageUrl: ApiService.mediaUrl(thumbUrl),
        fit: BoxFit.cover,
        width: w,
        height: h,
        memCacheWidth: 88,
        placeholder: (context, url) =>
            Container(color: Colors.grey.withValues(alpha: 0.2)),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.withValues(alpha: 0.2),
          child: const Icon(Icons.broken_image, size: 16, color: Colors.grey),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            inner,
            if (isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
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
    final localPath = message.localFilePath;
    final hasLocalFile =
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();
    final previewUrl =
        message.thumbnailUrl != null && message.thumbnailUrl!.isNotEmpty
        ? message.thumbnailUrl
        : message.fileUrl;
    final imageUrl = ApiService.mediaUrl(previewUrl);

    final ImageProvider provider = hasLocalFile
        ? FileImage(File(localPath))
        : CachedNetworkImageProvider(imageUrl);
    // Use the real pixel dimensions the backend sends so the bubble matches the
    // image's aspect ratio — no stretching, no cropping. Falls back to reading
    // the decoded image's own size when dimensions aren't recorded.
    final double? knownAspect =
        (message.width != null &&
            message.height != null &&
            message.width! > 0 &&
            message.height! > 0)
        ? message.width! / message.height!
        : null;

    return GestureDetector(
      onTap: () => onOpenMediaPreview(message),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Hero(
              tag: 'media-${message.id}',
              child: _ChatImage(
                provider: provider,
                knownAspect: knownAspect,
                maxWidth: 260,
                maxHeight: 320,
              ),
            ),
          ),
          if ((message.fileUrl?.isNotEmpty ?? false) &&
              !downloadedUrls.contains(message.fileUrl!))
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
    return AudioPlayerWidget(message: message, isMe: isMe);
  }

  Widget _buildDocumentContent(Message message) {
    final fileName =
        message.fileName ??
        (message.fileUrl ?? message.localFilePath ?? 'File')
            .split('/')
            .last
            .split('?')
            .first;
    final localPath = message.localFilePath;
    final hasLocal =
        localPath != null && localPath.isNotEmpty && File(localPath).existsSync();

    // WhatsApp behaviour: not on device yet -> tap downloads it (spinner while
    // in flight), on device -> tap opens with the system's default app.
    final VoidCallback? onTapFile;
    if (isDownloadingFile) {
      onTapFile = null;
    } else if (hasLocal) {
      onTapFile = () => onOpenFile(localPath);
    } else if (onDownloadFile != null) {
      onTapFile = () => onDownloadFile!(message);
    } else {
      onTapFile = () => onOpenFile(message.fileUrl ?? '');
    }

    return InkWell(
      onTap: onTapFile,
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
            if (isDownloadingFile) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (!hasLocal) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryColor),
                ),
                child: const Icon(
                  Icons.download,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
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
  final Message message;
  final bool isMe;
  const AudioPlayerWidget({
    super.key,
    required this.message,
    this.isMe = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isReady = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _localPath = widget.message.localFilePath;
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.localFilePath != oldWidget.message.localFilePath) {
      _localPath = widget.message.localFilePath;
      _isReady = false;
    }
  }

  AudioPlayer get _activePlayer {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _player = player;
    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
    return player;
  }

  Future<bool> _ensureReady() async {
    if (_isReady) return true;
    setState(() => _isLoading = true);
    try {
      final player = _activePlayer;
      var localPath = _localPath;
      if (localPath == null ||
          localPath.isEmpty ||
          !File(localPath).existsSync()) {
        localPath = await MediaStorageService.instance.cacheMessage(
          widget.message,
        );
        if (localPath != null) {
          await AppDatabase().updateMessageLocalFilePath(
            widget.message.id,
            localPath,
          );
          _localPath = localPath;
        }
      }
      if (localPath != null && File(localPath).existsSync()) {
        await player.setSource(DeviceFileSource(localPath));
      } else {
        await player.setSource(
          UrlSource(ApiService.mediaUrl(widget.message.fileUrl)),
        );
      }
      final d = await player.getDuration();
      if (!mounted) return false;
      setState(() {
        if (d != null) _duration = d;
        _isReady = true;
        _isLoading = false;
      });
      return true;
    } catch (e) {
      debugPrint('Audio error: $e');
      if (mounted) setState(() => _isLoading = false);
      return false;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
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
                  await _activePlayer.pause();
                  setState(() => _isPlaying = false);
                } else {
                  final isReady = await _ensureReady();
                  if (!isReady) return;
                  if (_position == _duration && _duration != Duration.zero) {
                    await _activePlayer.seek(Duration.zero);
                  }
                  await _activePlayer.resume();
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
                      if (_isReady) _activePlayer.seek(pos);
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

/// Renders a chat image at its true aspect ratio, scaled to fit within
/// [maxWidth]/[maxHeight]. The bubble's box always matches the image's shape, so
/// the image is never stretched or cropped — large images shrink uniformly to
/// fit (tap to open the full zoomable preview), small ones keep their shape.
///
/// The aspect ratio is taken from the backend-provided pixel dimensions when
/// available ([knownAspect]); otherwise it is read from the decoded image the
/// first time it loads. Until then a neutral 4:3 placeholder box is shown so the
/// layout doesn't jump noticeably.
class _ChatImage extends StatefulWidget {
  const _ChatImage({
    required this.provider,
    required this.knownAspect,
    required this.maxWidth,
    required this.maxHeight,
  });

  final ImageProvider provider;
  final double? knownAspect;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<_ChatImage> {
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  // Cap decode resolution (~2x the max logical width) so a multi-megapixel photo
  // doesn't decode at full size into memory — matches the old memCacheWidth.
  late final ImageProvider _display = ResizeImage.resizeIfNeeded(
    520,
    null,
    widget.provider,
  );

  @override
  void initState() {
    super.initState();
    _aspect = widget.knownAspect;
    if (_aspect == null) _resolveAspect();
  }

  void _resolveAspect() {
    final stream = _display.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width;
        final h = info.image.height;
        if (mounted && w > 0 && h > 0) {
          setState(() => _aspect = w / h);
        }
      },
      onError: (error, stack) {/* keep the placeholder ratio */},
    );
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect ?? (4 / 3);
    // Largest box with this aspect ratio that fits the bubble bounds. Prefer the
    // full available width, then cap by height for tall/portrait images.
    double w = widget.maxWidth;
    double h = w / aspect;
    if (h > widget.maxHeight) {
      h = widget.maxHeight;
      w = h * aspect;
    }

    return SizedBox(
      width: w,
      height: h,
      child: Image(
        image: _display,
        // The box matches the image's aspect ratio, so cover fills it exactly
        // without cropping or distortion.
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return Container(color: Colors.black12);
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      ),
    );
  }
}
