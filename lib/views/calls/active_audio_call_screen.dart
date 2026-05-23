import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'call_screen_helpers.dart';

class ActiveAudioCallScreen extends StatefulWidget {
  static const routeName = '/calls/active-audio';

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
      Future.delayed(const Duration(milliseconds: 250), () {
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
        return CallScreenScaffold(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  'Audio call',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (participant != null) callAvatar(participant, radius: 58),
                const SizedBox(height: 20),
                Text(
                  participant?.name ?? 'Audio call',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                CallStatusText(text: _statusText(vm)),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  CallStatusText(text: vm.errorMessage!, isError: true),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CallCircleButton(
                      icon: vm.isMuted ? Icons.mic_off : Icons.mic,
                      label: vm.isMuted ? 'Muted' : 'Mute',
                      tooltip: vm.isMuted
                          ? 'Unmute microphone'
                          : 'Mute microphone',
                      backgroundColor: vm.isMuted
                          ? AppColors.primaryColor
                          : Colors.grey.shade100,
                      iconColor: vm.isMuted
                          ? Colors.white
                          : AppColors.primaryColor,
                      onPressed: vm.toggleMute,
                    ),
                    CallCircleButton(
                      icon: vm.isSpeakerOn ? Icons.volume_up : Icons.hearing,
                      label: 'Speaker',
                      tooltip: 'Toggle speaker',
                      backgroundColor: vm.isSpeakerOn
                          ? AppColors.primaryColor
                          : Colors.grey.shade100,
                      iconColor: vm.isSpeakerOn
                          ? Colors.white
                          : AppColors.primaryColor,
                      onPressed: vm.toggleSpeaker,
                    ),
                    CallCircleButton(
                      icon: Icons.call_end,
                      label: 'End',
                      tooltip: 'End call',
                      backgroundColor: Colors.red,
                      iconColor: Colors.white,
                      onPressed: () => vm.endCall(),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(CallViewModel vm) {
    return switch (vm.callState) {
      CallState.reconnecting => 'Reconnecting...',
      CallState.connecting => 'Connecting...',
      CallState.failed => 'Call failed',
      CallState.ended => 'Call ended',
      _ => formatCallDuration(vm.callDuration),
    };
  }
}
