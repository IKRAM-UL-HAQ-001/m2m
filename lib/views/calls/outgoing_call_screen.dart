import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_session.dart';
import '../../utils/constants.dart';
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
      Future.delayed(const Duration(milliseconds: 250), () {
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
        return CallScreenScaffold(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.primaryColor,
                  backgroundColor: AppColors.outgoingMessageColor,
                ),
                const Spacer(),
                if (participant != null) callAvatar(participant, radius: 58),
                const SizedBox(height: 20),
                Text(
                  participant?.name ?? 'Calling',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                CallStatusText(
                  text: call == null
                      ? 'Calling...'
                      : '${call.callType == CallType.video ? 'Video' : 'Audio'} call',
                ),
                const SizedBox(height: 20),
                CallStatusText(
                  text:
                      vm.errorMessage ??
                      '${callStatusText(call?.status ?? 'initiated')}...',
                  isError: vm.errorMessage != null,
                ),
                const Spacer(),
                CallCircleButton(
                  icon: Icons.call_end,
                  label: 'Cancel',
                  tooltip: 'Cancel call',
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                  size: 64,
                  onPressed: vm.isConnecting ? null : () => vm.cancelCall(),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}
