import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/constants.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              return IconButton(
                color: Colors.white,
                icon: Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state.torchState == TorchState.on ? Colors.yellow : Colors.white70,
                ),
                iconSize: 28.0,
                onPressed: () => controller.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              return IconButton(
                color: Colors.white,
                icon: Icon(
                  state.cameraDirection == CameraFacing.front ? Icons.camera_front : Icons.camera_rear,
                ),
                iconSize: 28.0,
                onPressed: () => controller.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Custom Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryColor, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align the QR code within the frame',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
