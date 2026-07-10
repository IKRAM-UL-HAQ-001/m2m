import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen media viewer for the web client (network-only).
class WebMediaViewer {
  static void open(
    BuildContext context, {
    required String url,
    required bool isVideo,
    String? caption,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _MediaDialog(url: url, isVideo: isVideo, caption: caption),
    );
  }
}

class _MediaDialog extends StatefulWidget {
  final String url;
  final bool isVideo;
  final String? caption;
  const _MediaDialog({
    required this.url,
    required this.isVideo,
    this.caption,
  });

  @override
  State<_MediaDialog> createState() => _MediaDialogState();
}

class _MediaDialogState extends State<_MediaDialog> {
  VideoPlayerController? _controller;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;
      _init = controller.initialize().then((_) {
        controller.play();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: widget.isVideo ? _video() : _image(),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _image() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.contain,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (_, _, _) =>
            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }

  Widget _video() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        return GestureDetector(
          onTap: () => setState(() {
            controller.value.isPlaying
                ? controller.pause()
                : controller.play();
          }),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}
