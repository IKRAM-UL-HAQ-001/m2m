import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../views/profile_page.dart';

class ProfileQuickModal extends StatelessWidget {
  const ProfileQuickModal({
    super.key,
    required this.userId,
    required this.name,
    this.phone = '',
    this.about = 'Available',
    this.avatarUrl = '',
    this.isOnline = false,
    this.onMessage,
  });

  final String userId;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl;
  final bool isOnline;
  final VoidCallback? onMessage;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String name,
    String phone = '',
    String about = 'Available',
    String avatarUrl = '',
    bool isOnline = false,
    VoidCallback? onMessage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileQuickModal(
        userId: userId,
        name: name,
        phone: phone,
        about: about,
        avatarUrl: avatarUrl,
        isOnline: isOnline,
        onMessage: onMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.isNotEmpty;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: Colors.grey.shade200,
                    child: hasAvatar
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _emptyAvatar(size: 96),
                          )
                        : _emptyAvatar(size: 96),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnline ? 'online' : 'tap for contact info',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _action(
                    context,
                    icon: Icons.message_outlined,
                    label: 'Message',
                    onTap: () {
                      Navigator.pop(context);
                      onMessage?.call();
                    },
                  ),
                  _action(
                    context,
                    icon: Icons.info_outline,
                    label: 'Info',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(
                            userId: userId,
                            name: name,
                            phone: phone,
                            about: about,
                            avatarUrl: avatarUrl,
                            isOnline: isOnline,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyAvatar({required double size}) {
    return Center(
      child: Icon(Icons.person, size: size, color: Colors.grey.shade500),
    );
  }
}
