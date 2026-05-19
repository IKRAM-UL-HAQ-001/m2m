import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'responsive_layout.dart';
import 'web_screen_layout.dart';

class ContactSyncScreen extends StatefulWidget {
  const ContactSyncScreen({super.key});

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  bool _isSyncing = false;
  final ApiService _apiService = ApiService();

  Future<void> _runSync() async {
    setState(() => _isSyncing = true);
    try {
      await _apiService.syncContacts();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _isSyncing = false);
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sync contacts. Please try again.'),
          ),
        );
        setState(() => _isSyncing = false);
      }
      return;
    }

    if (mounted) {
      _navigateToHome();
    }
  }

  void _skipSync() {
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ResponsiveLayout(
          mobileLayout: HomeScreen(),
          webLayout: WebScreenLayout(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.contacts,
                size: 80,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 30),
              const Text(
                'Find your contacts on m2m',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Allow contact access to find existing M2M users and keep your chat list relevant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 60),
              if (_isSyncing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryColor),
                    SizedBox(height: 20),
                    Text(
                      'Syncing contacts...',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _runSync,
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _skipSync,
                  child: const Text(
                    'SKIP',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
