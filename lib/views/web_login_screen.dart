import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/constants.dart';
import 'responsive_layout.dart';
import 'home_screen.dart';
import 'web_screen_layout.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).startWebLinking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    // Auto navigation when authenticated
    if (authViewModel.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileLayout: HomeScreen(),
              webLayout: WebScreenLayout(),
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            color: AppColors.primaryColor,
          ),
          Center(
            child: Container(
              width: 1000,
              height: 600,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(50.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "To use m2m on your computer:",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildInstruction(1, "Open m2m on your phone"),
                          _buildInstruction(
                            2,
                            "Tap Menu or Settings and select Linked Devices",
                          ),
                          _buildInstruction(
                            3,
                            "Point your phone to this screen to capture the code",
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              "Need help to get started?",
                              style: TextStyle(color: AppColors.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: authViewModel.linkToken != null
                                ? Image.network(
                                    "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${authViewModel.linkToken}",
                                    height: 250,
                                    width: 250,
                                  )
                                : const SizedBox(
                                    height: 250,
                                    width: 250,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: true,
                                onChanged: (v) {},
                                activeColor: AppColors.primaryColor,
                              ),
                              const Text(
                                "Keep me signed in",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: MediaQuery.of(context).size.width / 2 - 500,
            child: Row(
              children: [
                Image.asset('assets/icon.png', width: 40, height: 40),
                const SizedBox(width: 15),
                const Text(
                  "M2M WEB",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[200],
            child: Text(
              number.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
