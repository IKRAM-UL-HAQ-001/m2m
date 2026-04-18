import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'web_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebLoginScreen();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            Text(
              "Welcome to M2M",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const Spacer(),
            Image.asset(
              'assets/icon.png',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: "Read our "),
                    TextSpan(
                      text: "Privacy Policy",
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    const TextSpan(
                      text: ". Tap 'Agree and continue' to accept the ",
                    ),
                    TextSpan(
                      text: "Terms of Service",
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 80,
                  vertical: 15,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text(
                "AGREE AND CONTINUE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
