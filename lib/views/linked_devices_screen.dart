import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/constants.dart';
import 'qr_scanner_screen.dart';


class LinkedDevicesScreen extends StatelessWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked devices', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: Image.asset(
              'assets/linked_devices.png',
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.devices, size: 150, color: AppColors.primaryColor.withValues(alpha: 0.3));
              },
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Use m2m on other devices',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Use m2m on Web, Desktop or other devices without keeping your phone online.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  if (result != null && context.mounted) {
                    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                    final success = await authViewModel.linkDevice(result.toString());
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Device linked successfully!' : 'Failed to link device.'),
                          backgroundColor: success ? AppColors.primaryColor : Colors.red,
                        ),
                      );
                    }
                  }

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'LINK A DEVICE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  'Your personal messages are end-to-end encrypted',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
