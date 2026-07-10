import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';
import 'web_auth_viewmodel.dart';

/// Read-only profile / settings panel for the web sidebar.
class WebProfileView extends StatefulWidget {
  const WebProfileView({super.key});

  @override
  State<WebProfileView> createState() => _WebProfileViewState();
}

class _WebProfileViewState extends State<WebProfileView> {
  String _name = '';
  String _about = '';
  String _phone = '';
  String _picture = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Paint instantly from the linked-session snapshot in prefs…
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _about = prefs.getString('user_about') ?? '';
      _phone = prefs.getString('user_phone') ?? '';
      _picture = prefs.getString('user_profile_picture') ?? '';
    });
    // …then refresh from the server so the picture/name/about are current
    // even if they changed on the phone after this browser was linked.
    try {
      final result = await ApiService().getProfile();
      final user = result['user'];
      if (user is! Map || !mounted) return;
      final name = user['name']?.toString() ?? '';
      final about = user['about']?.toString() ?? '';
      final phone = user['phone_number']?.toString() ?? '';
      final picture = user['profile_picture']?.toString() ?? '';
      setState(() {
        if (name.isNotEmpty) _name = name;
        if (about.isNotEmpty) _about = about;
        if (phone.isNotEmpty) _phone = phone;
        _picture = picture;
      });
      if (name.isNotEmpty) await prefs.setString('user_name', name);
      if (about.isNotEmpty) await prefs.setString('user_about', about);
      if (phone.isNotEmpty) await prefs.setString('user_phone', phone);
      if (picture.isNotEmpty) {
        await prefs.setString('user_profile_picture', picture);
      }
    } catch (_) {
      // Keep the prefs snapshot on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 60,
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: const Text(
            'Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: _picture.isNotEmpty
                ? CachedNetworkImageProvider(ApiService.mediaUrl(_picture))
                : null,
            child: _picture.isEmpty
                ? const Icon(Icons.person, size: 60, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        _field(Icons.person, 'Name', _name.isEmpty ? '—' : _name),
        _field(Icons.info_outline, 'About', _about.isEmpty ? '—' : _about),
        _field(Icons.phone, 'Phone', _phone.isEmpty ? '—' : _phone),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () => context.read<WebAuthViewModel>().logout(),
          ),
        ),
      ],
    );
  }

  Widget _field(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
