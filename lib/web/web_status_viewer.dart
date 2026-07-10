import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/user_status.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'web_status_viewmodel.dart';

/// Full-screen story-style viewer for one [StatusGroup].
class WebStatusViewer extends StatefulWidget {
  final StatusGroup group;
  const WebStatusViewer({super.key, required this.group});

  static Future<void> open(BuildContext context, StatusGroup group) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebStatusViewer(group: group)),
    );
  }

  @override
  State<WebStatusViewer> createState() => _WebStatusViewerState();
}

class _WebStatusViewerState extends State<WebStatusViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  int _index = 0;
  VideoPlayerController? _videoController;

  static const _imageDuration = Duration(seconds: 5);

  List<UserStatus> get _statuses => widget.group.statuses;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _start();
  }

  void _start() {
    final status = _statuses[_index];
    if (!widget.group.isMine && !status.isViewed) {
      context.read<WebStatusViewModel>().markViewed(status.id);
    }
    _videoController?.dispose();
    _videoController = null;

    if (status.statusType == 'video' && status.mediaUrl != null) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(ApiService.mediaUrl(status.mediaUrl)),
      );
      _videoController = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller.play();
        _progress
          ..duration = controller.value.duration
          ..forward(from: 0);
        setState(() {});
      });
    } else {
      _progress
        ..duration = _imageDuration
        ..forward(from: 0);
    }
  }

  void _next() {
    if (_index < _statuses.length - 1) {
      setState(() => _index++);
      _start();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _start();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _statuses[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: List.generate(_statuses.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _progressBar(i),
                    ),
                  );
                }),
              ),
            ),
            _headerRow(),
            Expanded(
              child: GestureDetector(
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < width / 3) {
                    _prev();
                  } else {
                    _next();
                  }
                },
                child: Center(child: _content(status)),
              ),
            ),
            if (widget.group.isMine) _ownerFooter(status),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(int i) {
    return SizedBox(
      height: 3,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, _) {
          double value;
          if (i < _index) {
            value = 1;
          } else if (i == _index) {
            value = _progress.value;
          } else {
            value = 0;
          }
          return LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          );
        },
      ),
    );
  }

  Widget _headerRow() {
    final owner = widget.group.owner;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[700],
            backgroundImage:
                (owner.profilePictureUrl?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(
                    ApiService.mediaUrl(owner.profilePictureUrl),
                  )
                : null,
            child: (owner.profilePictureUrl?.isEmpty ?? true)
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              owner.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _content(UserStatus status) {
    switch (status.statusType) {
      case 'text':
        return Container(
          color: _colorFromHex(status.backgroundColor),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Text(
            status.textContent,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: status.fontSize.toDouble(),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'video':
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        return AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        );
      default:
        return CachedNetworkImage(
          imageUrl: ApiService.mediaUrl(status.mediaUrl),
          fit: BoxFit.contain,
          placeholder: (_, _) =>
              const CircularProgressIndicator(color: Colors.white),
          errorWidget: (_, _, _) =>
              const Icon(Icons.broken_image, color: Colors.white54, size: 64),
        );
    }
  }

  Widget _ownerFooter(UserStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showViewers(status),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${status.viewCount}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () async {
              await context.read<WebStatusViewModel>().deleteStatus(status.id);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showViewers(UserStatus status) {
    _progress.stop();
    showModalBottomSheet(
      context: context,
      builder: (_) => FutureBuilder<List<StatusViewer>>(
        future: context.read<WebStatusViewModel>().fetchViewers(status.id),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final viewers = snapshot.data!;
          if (viewers.isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('No views yet')),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: viewers
                .map(
                  (v) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (v.pictureUrl?.isNotEmpty ?? false)
                          ? CachedNetworkImageProvider(
                              ApiService.mediaUrl(v.pictureUrl),
                            )
                          : null,
                      child: (v.pictureUrl?.isEmpty ?? true)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(v.name),
                  ),
                )
                .toList(),
          );
        },
      ),
    ).whenComplete(() => _progress.forward());
  }

  Color _colorFromHex(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? AppColors.primaryColor.toARGB32());
  }
}
