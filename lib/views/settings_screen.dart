import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and will delete all your chats, messages, and profile data from our servers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _deleteAccount(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final apiService = ApiService();
    final success = await apiService.deleteAccount();

    if (!context.mounted) return;
    Navigator.pop(context); // Hide loading indicator

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account and data deleted successfully')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.key, color: Colors.grey),
            title: const Text('Account'),
            subtitle: const Text('Security notifications, change number'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.grey),
            title: const Text('Privacy'),
            subtitle: const Text('Block contacts, disappearing messages'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Delete account and all data permanently'),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }
}
