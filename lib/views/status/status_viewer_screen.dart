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
  double _progress = 0;
  bool _isPaused = false;

  UserStatus get _currentStatus => _statuses[_currentIndex];
  bool get _isMyStatus => widget.statusGroup.isMine;

  @override
  void initState() {
    super.initState();
    _statuses = List<UserStatus>.from(widget.statusGroup.statuses);
    _showCurrentStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
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
              child: Row(
                children: List.generate(
                  _statuses.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: LinearProgressIndicator(
                        value: index < _currentIndex
                            ? 1
                            : index == _currentIndex
                            ? _progress
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
                      onTap: _previousStatus,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _nextStatus,
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
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Reply...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
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
    _progress = 0;
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
      setState(() {
        _progress += 0.05 / duration;
      });
      if (_progress >= 1) {
        _nextStatus();
      }
    });
  }

  void _nextStatus() {
    if (_currentIndex < _statuses.length - 1) {
      setState(() {
        _currentIndex++;
        _progress = 0;
      });
      _showCurrentStatus();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex == 0) {
      setState(() => _progress = 0);
      return;
    }
    setState(() {
      _currentIndex--;
      _progress = 0;
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
