import 'package:flutter/material.dart';
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

  void _runSync() async {
    setState(() => _isSyncing = true);
    // Simulate sync
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                "Find your contacts on m2m",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "m2m will securely sync your contacts to help you find people you know. This will be stored on our servers to help you connect with your friends.",
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
                      "Syncing contacts...",
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
                    "CONTINUE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
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
                  },
                  child: const Text(
                    "NOT NOW",
                    style: TextStyle(color: AppColors.primaryColor),
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
