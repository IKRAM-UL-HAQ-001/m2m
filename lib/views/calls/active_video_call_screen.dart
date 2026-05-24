import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';

import '../../models/call_participant.dart';
import '../../utils/constants.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'call_screen_helpers.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  static const routeName = '/calls/active-video';

  const ActiveVideoCallScreen({super.key});

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
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
    final terminal = {
      CallState.ended,
      CallState.rejected,
      CallState.missed,
      CallState.busy,
      CallState.failed,
    }.contains(vm.callState);
    if (!_closed && terminal && mounted) {
      _closed = true;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        vm.resetCall();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        final participant = call == null ? null : otherParticipant(call);
        final remoteVideoTrack = vm.remoteVideoTrack;
        final localVideoTrack = vm.localVideoTrack;
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: remoteVideoTrack != null
                        ? lk.VideoTrackRenderer(remoteVideoTrack)
                        : _RemoteVideoPlaceholder(
                            name: participant?.name ?? 'Video call',
                            status: vm.callState == CallState.reconnecting
                                ? 'Reconnecting...'
                                : vm.callState == CallState.connecting
                                ? 'Connecting...'
                                : vm.callState == CallState.failed
                                ? 'Call failed'
                                : 'Waiting for video',
                            participant: participant,
                          ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: vm.callDurationNotifier,
                        builder: (context, duration, child) {
                          return Text(
                            _statusText(vm, duration),
                            style: const TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: Container(
                    width: 108,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: localVideoTrack != null
                        ? lk.VideoTrackRenderer(localVideoTrack)
                        : Icon(
                            vm.isVideoEnabled
                                ? Icons.person
                                : Icons.videocam_off,
                            color: AppColors.primaryColor,
                            size: 38,
                          ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        runSpacing: 12,
                        spacing: 10,
                        children: [
                          CallCircleButton(
                            icon: vm.isMuted ? Icons.mic_off : Icons.mic,
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
                            icon: vm.isVideoEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            tooltip: 'Toggle camera',
                            backgroundColor: vm.isVideoEnabled
                                ? AppColors.primaryColor
                                : Colors.grey.shade100,
                            iconColor: vm.isVideoEnabled
                                ? Colors.white
                                : AppColors.primaryColor,
                            onPressed: vm.toggleVideo,
                          ),
                          CallCircleButton(
                            icon: Icons.cameraswitch,
                            tooltip: 'Switch camera',
                            onPressed: vm.isVideoEnabled
                                ? vm.switchCamera
                                : null,
                          ),
                          CallCircleButton(
                            icon: vm.isSpeakerOn
                                ? Icons.volume_up
                                : Icons.hearing,
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
                            tooltip: 'End call',
                            backgroundColor: Colors.red,
                            iconColor: Colors.white,
                            onPressed: () => vm.endCall(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(CallViewModel vm, Duration duration) {
    return switch (vm.callState) {
      CallState.reconnecting => 'Reconnecting...',
      CallState.connecting => 'Connecting...',
      CallState.failed => 'Call failed',
      CallState.ended => 'Call ended',
      _ => formatCallDuration(duration),
    };
  }
}

class _RemoteVideoPlaceholder extends StatelessWidget {
  const _RemoteVideoPlaceholder({
    required this.name,
    required this.status,
    required this.participant,
  });

  final String name;
  final String status;
  final CallParticipant? participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.outgoingMessageColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (participant != null) callAvatar(participant!, radius: 56),
          const SizedBox(height: 18),
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          CallStatusText(text: status),
        ],
      ),
    );
  }
}
