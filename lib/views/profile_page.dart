import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';
import 'profile/shared_media_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userId,
    required this.name,
    this.phone = '',
    this.about = 'Available',
    this.avatarUrl = '',
    this.isOnline = false,
  });

  final String userId;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl;
  final bool isOnline;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<int> _mediaCountFuture = _loadMediaCount();

  Future<int> _loadMediaCount() async {
    try {
      final results = await Future.wait([
        ApiService().getSharedMedia(widget.userId, type: 'media'),
        ApiService().getSharedMedia(widget.userId, type: 'docs'),
        ApiService().getSharedMedia(widget.userId, type: 'audio'),
      ]);
      return results.fold<int>(0, (count, items) => count + items.length);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.avatarUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Contact info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: hasAvatar
                      ? NetworkImage(widget.avatarUrl)
                      : null,
                  child: hasAvatar
                      ? null
                      : Icon(Icons.person, size: 64, color: Colors.grey[600]),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.phone,
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.about.isNotEmpty ? widget.about : 'Available',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 8, thickness: 8, color: Color(0xFFF3F3F3)),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primaryColor,
            ),
            title: const Text(
              'Media, links and docs',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: FutureBuilder<int>(
              future: _mediaCountFuture,
              builder: (context, snapshot) {
                final count = snapshot.data;
                return Text(count == null ? 'Loading...' : '$count items');
              },
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SharedMediaScreen(userId: widget.userId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
