import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_session.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
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
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    context.read<CallViewModel>().addListener(_handleStateChange);
    _timeoutTimer = Timer(const Duration(seconds: 60), _handleTimeout);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    context.read<CallViewModel>().removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    final vm = context.read<CallViewModel>();
    final call = vm.currentCall;
    if (call == null || !mounted) return;

    if (!_navigatedToActive && vm.callState == CallState.active) {
      _navigatedToActive = true;
      _timeoutTimer?.cancel();
      NotificationService().dismissIncomingCall(call.id);
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
      _timeoutTimer?.cancel();
      NotificationService().dismissIncomingCall(call.id);
      Future.delayed(const Duration(milliseconds: 250), () {
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

  void _handleTimeout() {
    if (!mounted || _closing || _navigatedToActive) return;
    final vm = context.read<CallViewModel>();
    final callId = vm.currentCall?.id;
    _closing = true;
    NotificationService().dismissIncomingCall(callId);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        final caller = call?.caller;
        return CallScreenScaffold(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Spacer(),
                if (caller != null) callAvatar(caller, radius: 58),
                const SizedBox(height: 20),
                Text(
                  caller?.name ?? 'Incoming call',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                CallStatusText(
                  text: 'Incoming ${call?.callType.value ?? 'audio'} call',
                ),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  CallStatusText(text: vm.errorMessage!, isError: true),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CallCircleButton(
                      icon: Icons.call_end,
                      label: 'Reject',
                      tooltip: 'Reject call',
                      backgroundColor: Colors.red,
                      iconColor: Colors.white,
                      size: 64,
                      onPressed: vm.isConnecting
                          ? null
                          : () {
                              NotificationService().dismissIncomingCall(
                                call?.id,
                              );
                              vm.rejectCall();
                            },
                    ),
                    CallCircleButton(
                      icon: Icons.call,
                      label: 'Accept',
                      tooltip: 'Accept call',
                      backgroundColor: AppColors.primaryColor,
                      iconColor: Colors.white,
                      size: 64,
                      onPressed: vm.isConnecting
                          ? null
                          : () {
                              NotificationService().dismissIncomingCall(
                                call?.id,
                              );
                              vm.acceptCall();
                            },
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
}
