import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

/// One swipeable item in the gallery.
class GalleryMedia {
  const GalleryMedia({
    required this.url,
    required this.isVideo,
    this.localPath,
    this.caption,
    this.heroTag,
  });

  final String url;
  final bool isVideo;
  final String? localPath;
  final String? caption;
  final String? heroTag;
}

/// Full-screen, swipeable viewer for an album of images/videos  the panel that
/// opens when a media cell is tapped. Images pinch-zoom (photo_view); videos
/// play inline. A counter shows the position within the album.
class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<GalleryMedia> items;
  final int initialIndex;

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMany = widget.items.length > 1;
    final caption = widget.items[_index].caption;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: hasMany
            ? Text(
                '${_index + 1} / ${widget.items.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PhotoViewGallery.builder(
              pageController: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (_, _) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              builder: (context, i) {
                final item = widget.items[i];
                if (item.isVideo) {
                  return PhotoViewGalleryPageOptions.customChild(
                    child: _GalleryVideoPage(item: item),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.contained,
                    heroAttributes: item.heroTag != null
                        ? PhotoViewHeroAttributes(tag: item.heroTag!)
                        : null,
                  );
                }
                final localFile = File(item.localPath ?? '');
                final provider = localFile.existsSync()
                    ? FileImage(localFile) as ImageProvider
                    : CachedNetworkImageProvider(item.url);
                return PhotoViewGalleryPageOptions(
                  imageProvider: provider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  heroAttributes: item.heroTag != null
                      ? PhotoViewHeroAttributes(tag: item.heroTag!)
                      : null,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 56,
                    ),
                  ),
                );
              },
            ),
          ),
          if (caption != null && caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                caption,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryVideoPage extends StatefulWidget {
  const _GalleryVideoPage({required this.item});
  final GalleryMedia item;

  @override
  State<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends State<_GalleryVideoPage> {
  VideoPlayerController? _controller;
  Future<void>? _future;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    final localFile = File(widget.item.localPath ?? '');
    final controller = localFile.existsSync()
        ? VideoPlayerController.file(localFile)
        : VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    _controller = controller;
    _future = controller.initialize().then((_) {
      controller.play();
      if (mounted) setState(() => _isPlaying = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() => _isPlaying = c.value.isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || _future == null) return const SizedBox.shrink();
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (!c.value.isInitialized) {
          return const Center(
            child: Icon(Icons.videocam_off, color: Colors.white54, size: 56),
          );
        }
        return GestureDetector(
          onTap: _toggle,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
              if (!_isPlaying)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
