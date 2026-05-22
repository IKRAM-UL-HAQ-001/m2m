import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

class CallMediaException implements Exception {
  final String message;

  const CallMediaException(this.message);

  @override
  String toString() => message;
}

class LiveKitCallService extends ChangeNotifier {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _isConnecting = false;
  bool _isCameraFront = true;
  String? _errorMessage;

  lk.Room? get room => _room;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  lk.ConnectionState get connectionState =>
      _room?.connectionState ?? lk.ConnectionState.disconnected;
  bool get isConnected => connectionState == lk.ConnectionState.connected;
  bool get isReconnecting => connectionState == lk.ConnectionState.reconnecting;
  lk.LocalParticipant? get localParticipant => _room?.localParticipant;
  lk.RemoteParticipant? get remoteParticipant {
    final participants = _room?.remoteParticipants.values;
    if (participants == null || participants.isEmpty) return null;
    return participants.first;
  }

  lk.LocalVideoTrack? get localVideoTrack {
    final publications = localParticipant?.videoTrackPublications;
    if (publications == null || publications.isEmpty) return null;
    for (final publication in publications) {
      if (!publication.muted && publication.track != null) {
        return publication.track;
      }
    }
    return null;
  }

  lk.RemoteVideoTrack? get remoteVideoTrack {
    final publications = remoteParticipant?.videoTrackPublications;
    if (publications == null || publications.isEmpty) return null;
    for (final publication in publications) {
      if (!publication.muted &&
          publication.subscribed == true &&
          publication.track != null) {
        return publication.track;
      }
    }
    return null;
  }

  Future<void> connect({
    required String serverUrl,
    required String token,
    required bool videoEnabled,
  }) async {
    if (_isConnecting || isConnected || isReconnecting) return;

    await _ensurePermissions(videoEnabled: videoEnabled);
    await disconnect();

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    room.addListener(_handleRoomChanged);
    _listener = room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) => notifyListeners())
      ..on<lk.RoomReconnectedEvent>((_) => notifyListeners())
      ..on<lk.RoomDisconnectedEvent>((_) => notifyListeners())
      ..on<lk.ParticipantConnectedEvent>((_) => notifyListeners())
      ..on<lk.ParticipantDisconnectedEvent>((_) => notifyListeners())
      ..on<lk.TrackSubscribedEvent>((_) => notifyListeners())
      ..on<lk.TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<lk.TrackMutedEvent>((_) => notifyListeners())
      ..on<lk.TrackUnmutedEvent>((_) => notifyListeners())
      ..on<lk.LocalTrackPublishedEvent>((_) => notifyListeners())
      ..on<lk.LocalTrackUnpublishedEvent>((_) => notifyListeners());

    try {
      await room.connect(serverUrl, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(
        videoEnabled,
        cameraCaptureOptions: const lk.CameraCaptureOptions(
          cameraPosition: lk.CameraPosition.front,
        ),
      );
      _isCameraFront = true;
    } catch (error) {
      _errorMessage = _messageForConnectError(error);
      await disconnect();
      throw CallMediaException(_errorMessage!);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;

    room.removeListener(_handleRoomChanged);
    await _listener?.dispose();
    _listener = null;
    _room = null;
    _isConnecting = false;

    await room.disconnect();
    await room.dispose();
    notifyListeners();
  }

  Future<void> muteMicrophone(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
    notifyListeners();
  }

  Future<void> enableCamera(bool enabled) async {
    await _ensureCameraPermission();
    await _room?.localParticipant?.setCameraEnabled(
      enabled,
      cameraCaptureOptions: lk.CameraCaptureOptions(
        cameraPosition: _isCameraFront
            ? lk.CameraPosition.front
            : lk.CameraPosition.back,
      ),
    );
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final room = _room;
    if (room == null) return;
    _isCameraFront = !_isCameraFront;
    await room.localParticipant?.setCameraEnabled(
      true,
      cameraCaptureOptions: lk.CameraCaptureOptions(
        cameraPosition: _isCameraFront
            ? lk.CameraPosition.front
            : lk.CameraPosition.back,
      ),
    );
    notifyListeners();
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    await _room?.setSpeakerOn(enabled);
    notifyListeners();
  }

  Future<void> _ensurePermissions({required bool videoEnabled}) async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw const CallMediaException('Microphone permission is required.');
    }
    if (videoEnabled) {
      await _ensureCameraPermission();
    }
  }

  Future<void> _ensureCameraPermission() async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      throw const CallMediaException('Camera permission is required.');
    }
  }

  String _messageForConnectError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('token')) {
      return 'Call token expired. Please try again.';
    }
    return 'Could not connect to the call.';
  }

  void _handleRoomChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.removeListener(_handleRoomChanged);
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }
}
