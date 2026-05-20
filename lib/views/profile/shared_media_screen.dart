import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/shared_media.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class SharedMediaScreen extends StatelessWidget {
  const SharedMediaScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Media, links and docs',
            style: TextStyle(color: Colors.white),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'MEDIA'),
              Tab(text: 'DOCS'),
              Tab(text: 'AUDIO'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MediaTab(userId: userId),
            DocsTab(userId: userId),
            AudioTab(userId: userId),
          ],
        ),
      ),
    );
  }
}

class MediaTab extends StatelessWidget {
  const MediaTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SharedMedia>>(
      future: ApiService().getSharedMedia(userId, type: 'media'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyState(
            icon: Icons.photo_library_outlined,
            text: 'No media shared yet',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.photo_library_outlined,
            text: 'No media shared yet',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final media = items[index];
            final imageUrl = media.thumbnailUrl ?? media.fileUrl;
            return GestureDetector(
              onTap: () => _openMediaViewer(context, items, index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: ApiService.mediaUrl(imageUrl),
                    fit: BoxFit.cover,
                  ),
                  if (media.messageType == 'video')
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openMediaViewer(
    BuildContext context,
    List<SharedMedia> items,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Center(
                child: CachedNetworkImage(
                  imageUrl: ApiService.mediaUrl(item.fileUrl),
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class DocsTab extends StatelessWidget {
  const DocsTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SharedMedia>>(
      future: ApiService().getSharedMedia(userId, type: 'docs'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyState(
            icon: Icons.description_outlined,
            text: 'No documents shared yet',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.description_outlined,
            text: 'No documents shared yet',
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            return ListTile(
              leading: _DocIcon(fileType: doc.extension),
              title: Text(
                doc.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${_formatSize(doc.fileSize)} · ${_formatDate(doc.sentAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.download_outlined,
                  color: AppColors.primaryColor,
                ),
                onPressed: () => _openFile(doc),
              ),
              onTap: () => _openFile(doc),
            );
          },
        );
      },
    );
  }
}

class AudioTab extends StatelessWidget {
  const AudioTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SharedMedia>>(
      future: ApiService().getSharedMedia(userId, type: 'audio'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyState(
            icon: Icons.audiotrack_outlined,
            text: 'No audio shared yet',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.audiotrack_outlined,
            text: 'No audio shared yet',
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final audio = items[index];
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  audio.isVoiceMessage ? Icons.mic : Icons.music_note,
                  color: AppColors.primaryColor,
                ),
              ),
              title: Text(
                audio.isVoiceMessage ? 'Voice message' : audio.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_formatDuration(audio.duration)} · ${_formatDate(audio.sentAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: _AudioPlayButton(audioUrl: audio.fileUrl),
            );
          },
        );
      },
    );
  }
}

class _DocIcon extends StatelessWidget {
  const _DocIcon({required this.fileType});

  final String fileType;

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pdf': Colors.red,
      'doc': Colors.blue,
      'docx': Colors.blue,
      'xls': Colors.green,
      'xlsx': Colors.green,
      'ppt': Colors.orange,
      'pptx': Colors.orange,
      'zip': Colors.amber,
      'rar': Colors.amber,
    };
    final icons = {
      'pdf': Icons.picture_as_pdf,
      'doc': Icons.description,
      'docx': Icons.description,
      'xls': Icons.table_chart,
      'xlsx': Icons.table_chart,
      'ppt': Icons.slideshow,
      'pptx': Icons.slideshow,
      'zip': Icons.folder_zip,
      'rar': Icons.folder_zip,
    };
    final color = colors[fileType] ?? Colors.grey;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icons[fileType] ?? Icons.insert_drive_file, color: color),
    );
  }
}

class _AudioPlayButton extends StatefulWidget {
  const _AudioPlayButton({required this.audioUrl});

  final String audioUrl;

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
        color: AppColors.primaryColor,
      ),
      onPressed: () async {
        if (_isPlaying) {
          await _player.pause();
          if (mounted) setState(() => _isPlaying = false);
        } else {
          await _player.play(UrlSource(widget.audioUrl));
          if (mounted) setState(() => _isPlaying = true);
        }
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}

String _formatSize(int? bytes) {
  if (bytes == null) return 'Unknown size';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(DateTime value) => DateFormat('MMM d, yyyy').format(value);

String _formatDuration(double? seconds) {
  if (seconds == null) return '0:00';
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes;
  final remaining = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remaining';
}

Future<void> _openFile(SharedMedia file) async {
  final uri = Uri.parse(file.fileUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
