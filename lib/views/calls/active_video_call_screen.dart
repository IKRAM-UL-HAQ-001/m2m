import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';

import '../../viewmodels/call_viewmodel.dart';
import 'call_screen_helpers.dart';

class ActiveVideoCallScreen extends StatefulWidget {
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
      Future.delayed(const Duration(milliseconds: 900), () {
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
                  child: Container(
                    color: const Color(0xFF111827),
                    child: remoteVideoTrack != null
                        ? lk.VideoTrackRenderer(remoteVideoTrack)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_off,
                                color: Colors.white38,
                                size: 72,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                participant?.name ?? 'Video call',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                vm.callState == CallState.reconnecting
                                    ? 'Reconnecting...'
                                    : vm.callState == CallState.connecting
                                    ? 'Connecting...'
                                    : 'Waiting for video',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        vm.callState == CallState.reconnecting
                            ? 'Reconnecting...'
                            : formatCallDuration(vm.callDuration),
                        style: const TextStyle(color: Colors.white),
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
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: localVideoTrack != null
                        ? lk.VideoTrackRenderer(localVideoTrack)
                        : Icon(
                            vm.isVideoEnabled
                                ? Icons.person
                                : Icons.videocam_off,
                            color: Colors.white70,
                            size: 38,
                          ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CallCircleButton(
                        icon: vm.isMuted ? Icons.mic_off : Icons.mic,
                        onPressed: vm.toggleMute,
                      ),
                      CallCircleButton(
                        icon: vm.isVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        onPressed: vm.toggleVideo,
                      ),
                      CallCircleButton(
                        icon: Icons.cameraswitch,
                        onPressed: vm.isVideoEnabled ? vm.switchCamera : null,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
