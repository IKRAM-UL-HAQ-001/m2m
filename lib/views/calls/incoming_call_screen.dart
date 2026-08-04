import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/call_session.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'active_audio_call_screen.dart';
import 'active_video_call_screen.dart';
import 'call_screen_helpers.dart';

class IncomingCallScreen extends StatefulWidget {
  static const routeName = '/calls/incoming';

  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _navigatedToActive = false;
  bool _closing = false;
  bool _accepting = false;
  Timer? _timeoutTimer;

  // Front-camera self-preview, shown ONLY for incoming video calls so the
  // receiver sees themselves before answering (WhatsApp-style). This runs the
  // camera independently of Chime  Chime can't start the local video tile until
  // the call is joined (which happens on accept). The preview is therefore torn
  // down and the camera fully released the moment the user accepts, so Chime can
  // open the same physical camera without contention. See [_acceptCall].
  CameraController? _cameraController;
  bool _previewReady = false;
  bool _previewStarted = false;

  bool get _isVideoCall =>
      context.read<CallViewModel>().currentCall?.callType == CallType.video;

  @override
  void initState() {
    super.initState();
    context.read<CallViewModel>().addListener(_handleStateChange);
    _timeoutTimer = Timer(const Duration(seconds: 60), _handleTimeout);
    // Own the foreground ringtone for the lifetime of this screen so the call
    // rings exactly once regardless of whether the invite arrived over the
    // WebSocket or via FCM, and is guaranteed to stop when the screen leaves.
    unawaited(NotificationService().startRingtone());
    if (_isVideoCall) {
      unawaited(_startPreview());
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    unawaited(NotificationService().stopRingtone());
    context.read<CallViewModel>().removeListener(_handleStateChange);
    // Reject/timeout/back paths land here without an accept; make sure the
    // camera is never left held open after the screen is gone.
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  Future<void> _startPreview() async {
    if (_previewStarted) return;
    _previewStarted = true;
    try {
      // Don't PROMPT for permission on the incoming screen  that would pop a
      // system dialog over the lock screen mid-ring. Only show the preview if
      // camera access was already granted; otherwise fall back to the avatar.
      // Camera permission is still requested at accept time by the media layer.
      if (!await Permission.camera.isGranted) return;

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      // The screen may have been accepted/closed while the camera was warming
      // up  if so, release immediately and bail.
      if (!mounted || _accepting || _closing) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
      setState(() => _previewReady = true);
    } catch (e) {
      debugPrint('Incoming-call camera preview unavailable: $e');
      await _cameraController?.dispose();
      _cameraController = null;
    }
  }

  /// Fully release the preview camera and AWAIT it, so the physical camera is
  /// free before Chime tries to open it on join. Safe to call more than once.
  Future<void> _releasePreview() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) setState(() => _previewReady = false);
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        // Already disposed / never fully initialised.
      }
    }
  }

  void _handleStateChange() {
    final vm = context.read<CallViewModel>();
    final call = vm.currentCall;
    if (call == null || !mounted) return;

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
      unawaited(_releasePreview());
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
    unawaited(_releasePreview());
    NotificationService().dismissIncomingCall(callId);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _acceptCall(CallViewModel vm, CallSession? call) async {
    if (_accepting || call == null) return;
    debugPrint('Incoming call accept tapped callId=${call.id}');
    setState(() => _accepting = true);
    _navigatedToActive = true;
    _timeoutTimer?.cancel();
    final navigator = Navigator.of(context);
    // Release the camera BEFORE the accept flow runs. The backend accept is a
    // network round-trip and Chime's startLocalVideo only runs after it, so the
    // camera is comfortably free by the time Chime opens it  but we await the
    // release here anyway to guarantee the handoff can never collide.
    await _releasePreview();
    NotificationService().dismissIncomingCall(call.id);
    vm.acceptCallFast();
    vm.markActiveCallScreenPushed();
    navigator.pushReplacement(
      MaterialPageRoute(
        settings: RouteSettings(name: _activeRouteNameFor(call)),
        builder: (_) => _activeScreenFor(call),
      ),
    );
  }

  String _activeRouteNameFor(CallSession call) {
    return call.callType == CallType.video
        ? ActiveVideoCallScreen.routeName
        : ActiveAudioCallScreen.routeName;
  }

  /// Full-bleed, mirrored front-camera feed used as the backdrop for incoming
  /// video calls. Mirrored so it reads like a selfie preview, matching the
  /// in-call self-view convention.
  Widget _buildCameraBackdrop(CameraController controller) {
    final preview = controller.value.previewSize;
    // previewSize is reported in sensor (landscape) orientation; swap for the
    // portrait call screen so BoxFit.cover fills without distortion.
    final previewWidth = preview?.height ?? 1.0;
    final previewHeight = preview?.width ?? 1.0;
    return ClipRect(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..setEntry(0, 0, -1.0),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        final caller = call?.caller;
        final controller = _cameraController;
        final showPreview = _previewReady && controller != null;
        final onDarkBackdrop = showPreview;

        final titleColor = onDarkBackdrop ? Colors.white : null;

        final content = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Spacer(),
              if (!showPreview && caller != null)
                callAvatar(caller, radius: 58),
              if (!showPreview) const SizedBox(height: 20),
              Text(
                caller?.name ?? 'Incoming call',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              CallStatusText(
                text: 'Incoming ${call?.callType.value ?? 'audio'} call',
                color: onDarkBackdrop ? Colors.white70 : null,
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
                    labelColor: onDarkBackdrop ? Colors.white : null,
                    size: 64,
                    onPressed: vm.isConnecting || _accepting
                        ? null
                        : () {
                            unawaited(_releasePreview());
                            NotificationService().dismissIncomingCall(call?.id);
                            vm.rejectCall();
                          },
                  ),
                  CallCircleButton(
                    icon: Icons.call,
                    label: 'Accept',
                    tooltip: 'Accept call',
                    backgroundColor: AppColors.primaryColor,
                    iconColor: Colors.white,
                    labelColor: onDarkBackdrop ? Colors.white : null,
                    size: 64,
                    onPressed: vm.isConnecting || _accepting
                        ? null
                        : () => unawaited(_acceptCall(vm, call)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        );

        return CallScreenScaffold(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showPreview) _buildCameraBackdrop(controller),
              if (showPreview)
                // Scrim so the caller name, status and buttons stay legible on
                // top of a bright camera feed.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              content,
            ],
          ),
        );
      },
    );
  }
}
