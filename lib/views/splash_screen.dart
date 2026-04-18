import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'welcome_screen.dart';
import 'responsive_layout.dart';
import 'home_screen.dart';
import 'web_screen_layout.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  void _checkStatus() async {
    final authProvider = Provider.of<AuthViewModel>(context, listen: false);

    // Check for previous session

    await authProvider.checkAuthStatus();

    if (mounted) {
      if (authProvider.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileLayout: HomeScreen(),
              webLayout: WebScreenLayout(),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Image.asset(
              'assets/icon.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              "M2M",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const Spacer(),
            const Text(
              "from",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Text(
              "M2M",
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
