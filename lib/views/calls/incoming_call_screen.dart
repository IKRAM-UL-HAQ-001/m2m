import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_session.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'active_audio_call_screen.dart';
import 'active_video_call_screen.dart';
import 'call_screen_helpers.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _navigatedToActive = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    context.read<CallViewModel>().addListener(_handleStateChange);
  }

  @override
  void dispose() {
    context.read<CallViewModel>().removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    final vm = context.read<CallViewModel>();
    final call = vm.currentCall;
    if (call == null || !mounted) return;

    if (!_navigatedToActive && vm.callState == CallState.active) {
      _navigatedToActive = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _activeScreenFor(call)),
      );
      return;
    }

    final terminal = {
      CallState.ended,
      CallState.rejected,
      CallState.missed,
      CallState.busy,
      CallState.failed,
    }.contains(vm.callState);
    if (!_closing && terminal) {
      _closing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        vm.resetCall();
      });
    }
  }

  Widget _activeScreenFor(CallSession call) {
    return call.callType == CallType.video
        ? const ActiveVideoCallScreen()
        : const ActiveAudioCallScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        final caller = call?.caller;
        return Scaffold(
          backgroundColor: const Color(0xFF111827),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  if (caller != null) callAvatar(caller, radius: 56),
                  const SizedBox(height: 18),
                  Text(
                    caller?.name ?? 'Incoming call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming ${call?.callType.value ?? 'audio'} call',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (vm.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      vm.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CallCircleButton(
                        icon: Icons.call_end,
                        backgroundColor: Colors.red,
                        onPressed: vm.isConnecting
                            ? null
                            : () => vm.rejectCall(),
                      ),
                      CallCircleButton(
                        icon: Icons.call,
                        backgroundColor: Colors.green,
                        onPressed: vm.isConnecting
                            ? null
                            : () => vm.acceptCall(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
