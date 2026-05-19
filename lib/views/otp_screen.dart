import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'complete_profile_screen.dart';
import 'responsive_layout.dart';
import 'home_screen.dart';
import 'web_screen_layout.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  void _verifyOtp() async {
    if (_otpController.text.isNotEmpty) {
      final authProvider = Provider.of<AuthViewModel>(context, listen: false);
      try {
        bool success = await authProvider.verifyOtp(_otpController.text);

        if (success && mounted) {
          if (authProvider.isAuthenticated) {
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
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const CompleteProfileScreen(),
              ),
              (route) => false,
            );
          }
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Verify your phone number",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Text(
            "Waiting to automatically detect an SMS sent to",
            style: TextStyle(color: Colors.grey[800]),
          ),
          Text(
            "your phone number",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100.0),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: "- - - - - -",
                counterText: "",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Enter 6-digit code ",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            onPressed: _verifyOtp,
            child: const Text(
              "VERIFY",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
