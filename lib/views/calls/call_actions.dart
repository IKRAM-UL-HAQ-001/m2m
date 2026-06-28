import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'outgoing_call_screen.dart';

/// Starts an outgoing call to [receiverId] and pushes the OutgoingCallScreen.
///
/// Mirrors the flow in `chat_detail._startCall` and the old `calls_tab._redial`
/// so every call entry point behaves identically. Captures the
/// Navigator/Messenger before the await to stay safe across the async gap.
Future<void> startCallAndNavigate(
  BuildContext context, {
  required int receiverId,
  required String callType,
}) async {
  final vm = context.read<CallViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  if (!vm.canStartCall) {
    messenger.showSnackBar(
      const SnackBar(content: Text('You are already in a call')),
    );
    return;
  }

  final started = await vm.startCall(receiverId: receiverId, callType: callType);
  if (started == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(vm.errorMessage ?? 'Unable to start call')),
    );
    return;
  }

  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: OutgoingCallScreen.routeName),
      builder: (_) => const OutgoingCallScreen(),
    ),
  );
}

/// WhatsApp-style "Audio call / Video call" chooser. Returns `'audio'`,
/// `'video'`, or `null` if dismissed.
Future<String?> showCallTypeSheet(
  BuildContext context, {
  String? name,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (name != null && name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.call, color: AppColors.primaryColor),
              title: const Text('Audio call'),
              onTap: () => Navigator.of(sheetContext).pop('audio'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppColors.primaryColor),
              title: const Text('Video call'),
              onTap: () => Navigator.of(sheetContext).pop('video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
