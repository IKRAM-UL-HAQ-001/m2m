import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_session.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'active_audio_call_screen.dart';
import 'active_video_call_screen.dart';
import 'call_screen_helpers.dart';

class OutgoingCallScreen extends StatefulWidget {
  const OutgoingCallScreen({super.key});

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
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

    if (!_closing && _isTerminal(vm.callState)) {
      _closing = true;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        vm.resetCall();
      });
    }
  }

  bool _isTerminal(CallState state) {
    return {
      CallState.ended,
      CallState.rejected,
      CallState.missed,
      CallState.busy,
      CallState.failed,
    }.contains(state);
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
        final participant = call?.receiver;
        return Scaffold(
          backgroundColor: const Color(0xFF111827),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  if (participant != null) callAvatar(participant, radius: 54),
                  const SizedBox(height: 18),
                  Text(
                    participant?.name ?? 'Calling',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    call == null
                        ? 'Calling'
                        : '${call.callType.value == 'video' ? 'Video' : 'Audio'} call',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    vm.errorMessage ??
                        callStatusText(call?.status ?? 'initiated'),
                    style: TextStyle(
                      color: vm.errorMessage == null
                          ? Colors.white70
                          : Colors.redAccent,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  CallCircleButton(
                    icon: Icons.call_end,
                    backgroundColor: Colors.red,
                    onPressed: vm.isConnecting ? null : () => vm.cancelCall(),
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
