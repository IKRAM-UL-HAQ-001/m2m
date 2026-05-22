import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/call_viewmodel.dart';
import 'call_screen_helpers.dart';

class ActiveAudioCallScreen extends StatefulWidget {
  const ActiveAudioCallScreen({super.key});

  @override
  State<ActiveAudioCallScreen> createState() => _ActiveAudioCallScreenState();
}

class _ActiveAudioCallScreenState extends State<ActiveAudioCallScreen> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    context.read<CallViewModel>().addListener(_handleCallState);
  }

  @override
  void dispose() {
    context.read<CallViewModel>().removeListener(_handleCallState);
    super.dispose();
  }

  void _handleCallState() {
    final vm = context.read<CallViewModel>();
    if (!_closed && _isTerminal(vm.callState) && mounted) {
      _closed = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        vm.resetCall();
      });
    }
  }

  bool _isTerminal(CallState state) {
    return state == CallState.ended ||
        state == CallState.rejected ||
        state == CallState.missed ||
        state == CallState.busy ||
        state == CallState.failed;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        final participant = call == null ? null : otherParticipant(call);
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
                    participant?.name ?? 'Audio call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vm.callState == CallState.reconnecting
                        ? 'Reconnecting...'
                        : vm.callState == CallState.connecting
                        ? 'Connecting...'
                        : formatCallDuration(vm.callDuration),
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
                        icon: vm.isMuted ? Icons.mic_off : Icons.mic,
                        onPressed: vm.toggleMute,
                      ),
                      CallCircleButton(
                        icon: vm.isSpeakerOn ? Icons.volume_up : Icons.hearing,
                        onPressed: vm.toggleSpeaker,
                      ),
                      CallCircleButton(
                        icon: Icons.call_end,
                        backgroundColor: Colors.red,
                        onPressed: vm.isConnecting ? null : () => vm.endCall(),
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
