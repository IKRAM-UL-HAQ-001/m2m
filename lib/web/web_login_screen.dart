import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../utils/constants.dart';
import 'web_auth_viewmodel.dart';

/// WhatsApp-Web-style QR link screen. Shows a QR encoding the link token; the
/// phone app scans it to authorise this browser session.
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
      context.read<WebAuthViewModel>().startWebLinking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<WebAuthViewModel>();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Use M2M on your computer',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _step(1, 'Open M2M on your phone'),
                    _step(2, 'Tap Menu, then Linked devices'),
                    _step(3, 'Tap Link a device'),
                    _step(4, 'Point your phone at this screen to scan the QR code'),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              _qrPanel(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryColor,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _qrPanel(WebAuthViewModel auth) {
    final token = auth.linkToken;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 240,
          height: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: token == null
              ? const Center(child: CircularProgressIndicator())
              : QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  gapless: false,
                ),
        ),
        const SizedBox(height: 12),
        Text(
          token == null
              ? 'Generating code…'
              : 'Code refreshes in ${auth.linkCountdown}s',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }
}
