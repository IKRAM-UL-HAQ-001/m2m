import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/user_status.dart';
import '../../services/api_service.dart';
import '../../viewmodels/status_viewmodel.dart';
import 'status_tab.dart';

class StatusViewerScreen extends StatefulWidget {
  const StatusViewerScreen({super.key, required this.statusGroup});

  final StatusGroup statusGroup;

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  Timer? _timer;
  VideoPlayerController? _videoController;
  late List<UserStatus> _statuses;
  int _currentIndex = 0;
  // Story progress is a notifier so the 50ms ticker repaints only the thin
  // progress bar via a ValueListenableBuilder — not the whole full-screen
  // image/video viewer (which a setState every 50ms was doing = 20 rebuilds/s).
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool _isPaused = false;

  // Reply composer state. Kept as proper controller/focus-node fields (created
  // once, disposed once) so tapping reply reliably opens the keyboard instead of
  // flickering to a black screen.
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _sendingReply = false;

  UserStatus get _currentStatus => _statuses[_currentIndex];
  bool get _isMyStatus => widget.statusGroup.isMine;

  @override
  void initState() {
    super.initState();
    _statuses = List<UserStatus>.from(widget.statusGroup.statuses);
    // Pause the story while the user is composing a reply, resume when the
    // keyboard is dismissed.
    _replyFocusNode.addListener(_onReplyFocusChanged);
    _showCurrentStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    _progress.dispose();
    _replyFocusNode.removeListener(_onReplyFocusChanged);
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _onReplyFocusChanged() {
    if (_replyFocusNode.hasFocus) {
      if (!_isPaused) _pauseTimer();
    } else {
      if (_isPaused) _resumeTimer();
    }
  }

  /// True when a reply was in progress and got dismissed — used so a tap on the
  /// story area closes the keyboard instead of advancing to the next status.
  bool _dismissReplyIfOpen() {
    if (_replyFocusNode.hasFocus) {
      _replyFocusNode.unfocus();
      return true;
    }
    return false;
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      await ApiService().sendMessage(
        widget.statusGroup.owner.id,
        text,
        clientUuid: ApiService.createClientUuid(),
      );
      _replyController.clear();
      if (!mounted) return;
      _replyFocusNode.unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send reply: $e')));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_statuses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      // Full-screen story viewer: never let the Scaffold shrink the body when the
      // keyboard opens (that resize is what blanked the image/video to black).
      // The reply bar lifts itself above the keyboard using viewInsets instead.
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onLongPressStart: (_) => _pauseTimer(),
        onLongPressEnd: (_) => _resumeTimer(),
        child: Stack(
          children: [
            Positioned.fill(child: _buildStatusContent()),
            Positioned(
              top: topPadding + 8,
              left: 8,
              right: 8,
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, progress, _) => Row(
                  children: List.generate(
                    _statuses.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: index < _currentIndex
                              ? 1
                              : index == _currentIndex
                              ? progress
                              : 0,
                          backgroundColor: Colors.white38,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topPadding + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    backgroundImage: _ownerHasPhoto
                        ? CachedNetworkImageProvider(
                            ApiService.mediaUrl(
                              widget.statusGroup.owner.profilePictureUrl,
                            ),
                          )
                        : null,
                    child: _ownerHasPhoto
                        ? null
                        : const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.statusGroup.owner.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeAgo(_currentStatus.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_isMyStatus)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.white,
                      onSelected: (value) {
                        if (value == 'delete') _confirmDeleteCurrentStatus();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_dismissReplyIfOpen()) return;
                        _previousStatus();
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_dismissReplyIfOpen()) return;
                        _nextStatus();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isMyStatus)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showViewersList,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentStatus.viewCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                // Lift the reply bar above the keyboard. With
                // resizeToAvoidBottomInset:false this is the only thing that
                // moves when the keyboard animates — the story behind stays put.
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                child: _buildReplyBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white70),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _sendReply(),
                decoration: const InputDecoration(
                  hintText: 'Reply...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: _sendingReply
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendingReply ? null : _sendReply,
            ),
          ],
        ),
      ),
    );
  }

  bool get _ownerHasPhoto {
    final url = widget.statusGroup.owner.profilePictureUrl;
    return url != null && url.isNotEmpty;
  }

  Widget _buildStatusContent() {
    final status = _currentStatus;
    if (status.statusType == 'text') {
      return ColoredBox(
        color: _parseColor(status.backgroundColor),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              status.textContent,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: status.fontSize.toDouble(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    if (status.statusType == 'video') {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    final imageUrl = status.mediaUrl ?? status.thumbnailUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 56),
      );
    }
    return CachedNetworkImage(
      imageUrl: ApiService.mediaUrl(imageUrl),
      fit: BoxFit.contain,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 56),
      ),
    );
  }

  Future<void> _showCurrentStatus() async {
    final statusViewModel = context.read<StatusViewModel>();
    _timer?.cancel();
    _progress.value = 0;
    _isPaused = false;
    await _videoController?.dispose();
    _videoController = null;

    final status = _currentStatus;
    if (!_isMyStatus) {
      statusViewModel.markViewed(status.id).catchError((_) {});
    }

    if (status.statusType == 'video' &&
        status.mediaUrl != null &&
        status.mediaUrl!.isNotEmpty) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(status.mediaUrl!),
      );
      _videoController = controller;
      await controller.initialize();
      await controller.play();
      if (!mounted) return;
      setState(() {});
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final duration = _currentStatus.statusType == 'video'
        ? (_currentStatus.duration ??
              _videoController?.value.duration.inSeconds.toDouble() ??
              15)
        : 5.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _isPaused) return;
      // Updates the notifier only — repaints the progress bar, not the screen.
      _progress.value += 0.05 / duration;
      if (_progress.value >= 1) {
        _nextStatus();
      }
    });
  }

  void _nextStatus() {
    if (_currentIndex < _statuses.length - 1) {
      _progress.value = 0;
      setState(() {
        _currentIndex++;
      });
      _showCurrentStatus();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex == 0) {
      _progress.value = 0;
      return;
    }
    _progress.value = 0;
    setState(() {
      _currentIndex--;
    });
    _showCurrentStatus();
  }

  void _pauseTimer() {
    setState(() => _isPaused = true);
    _videoController?.pause();
  }

  void _resumeTimer() {
    setState(() => _isPaused = false);
    _videoController?.play();
  }

  void _showViewersList() {
    _pauseTimer();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<List<StatusViewer>>(
          future: context.read<StatusViewModel>().fetchViewers(
            _currentStatus.id,
          ),
          builder: (context, snapshot) {
            final viewers = snapshot.data ?? const <StatusViewer>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: viewers.isEmpty ? 1 : viewers.length,
                separatorBuilder: (context, index) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  if (viewers.isEmpty) {
                    return const ListTile(title: Text('No views yet'));
                  }
                  final viewer = viewers[index];
                  final hasPhoto =
                      viewer.pictureUrl != null &&
                      viewer.pictureUrl!.isNotEmpty;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: hasPhoto
                          ? CachedNetworkImageProvider(
                              ApiService.mediaUrl(viewer.pictureUrl!),
                            )
                          : null,
                      child: hasPhoto ? null : const Icon(Icons.person),
                    ),
                    title: Text(viewer.name),
                    subtitle: Text(timeAgo(viewer.viewedAt)),
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(_resumeTimer);
  }

  Future<void> _confirmDeleteCurrentStatus() async {
    _pauseTimer();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete status?'),
        content: const Text('This status update will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteCurrentStatus();
    } else {
      _resumeTimer();
    }
  }

  Future<void> _deleteCurrentStatus() async {
    final statusId = _currentStatus.id;
    try {
      await context.read<StatusViewModel>().deleteStatus(statusId);
      if (!mounted) return;
      setState(() {
        _statuses.removeWhere((status) => status.id == statusId);
        if (_currentIndex >= _statuses.length) {
          _currentIndex = _statuses.isEmpty ? 0 : _statuses.length - 1;
        }
      });
      if (_statuses.isEmpty) {
        Navigator.pop(context);
        return;
      }
      _showCurrentStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete status: $e')));
      _resumeTimer();
    }
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? const Color(0xFF128C7E) : Color(parsed);
  }
}
