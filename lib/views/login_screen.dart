import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountry = "United States";
  String _countryCode = "1";

  final Map<String, String> _countryCodes = {
    "United States": "1",
    "Pakistan": "92",
    "India": "91",
  };

  void _requestOtp() async {
    if (_phoneController.text.isNotEmpty) {
      final authProvider = Provider.of<AuthViewModel>(context, listen: false);
      try {
        bool success = await authProvider.requestOtp(
          _phoneController.text,
          countryCode: _countryCode,
        );
        if (success && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OtpScreen()),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Enter your phone number",
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: "m2m will need to verify your phone number. ",
                  ),
                  TextSpan(
                    text: "What's my number?",
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80.0),
            child: Column(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCountry,
                    items: _countryCodes.keys
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Center(
                              child: Text(
                                value,
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCountry = val;
                          _countryCode = _countryCodes[val]!;
                        });
                      }
                    },
                  ),
                ),
                const Divider(color: AppColors.primaryColor, thickness: 1),
                Row(
                  children: [
                    Container(
                      width: 50,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primaryColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "+ $_countryCode",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: "phone number",
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryColor,
                            ),
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Carrier charges may apply",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            onPressed: _requestOtp,
            child: const Text(
              "NEXT",
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
