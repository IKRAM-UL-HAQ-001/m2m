import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_media_service.dart';

/// Amazon Chime SDK implementation of [CallMediaService].
///
/// All Chime SDK operations are delegated to native platform code via
/// [MethodChannel].  The Flutter side never holds AWS credentials — only
/// the meeting/attendee JSON blobs returned by the Django backend `/join/`.
class ChimeCallService extends CallMediaService {
  static const _channel = MethodChannel('com.danish.m2m/chime');
  static const _eventChannel = EventChannel('com.danish.m2m/chime_events');

  final StreamController<CallMediaEvent> _eventController =
      StreamController<CallMediaEvent>.broadcast();

  StreamSubscription? _nativeEventSubscription;

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isReconnecting = false;
  String? _errorMessage;
  bool _isLocalVideoActive = false;
  bool _isRemoteVideoActive = false;
  bool _hasRemoteParticipant = false;
  bool? _isLocalAudioEnabled;

  ChimeCallService() {
    _listenToNativeEvents();
  }

  // ── CallMediaService overrides ──────────────────────────────────────

  @override
  Stream<CallMediaEvent> get mediaEvents => _eventController.stream;

  @override
  bool get isConnecting => _isConnecting;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isReconnecting => _isReconnecting;

  @override
  String? get errorMessage => _errorMessage;

  @override
  String get diagnosticState =>
      'connection=${_isConnected
          ? "connected"
          : _isReconnecting
          ? "reconnecting"
          : _isConnecting
          ? "connecting"
          : "disconnected"} '
      'localVideo=$_isLocalVideoActive remoteVideo=$_isRemoteVideoActive '
      'remoteParticipant=$_hasRemoteParticipant';

  @override
  bool get isLocalVideoActive => _isLocalVideoActive;

  @override
  bool get isRemoteVideoActive => _isRemoteVideoActive;

  @override
  bool get hasRemoteParticipant => _hasRemoteParticipant;

  @override
  bool? get isLocalAudioEnabled => _isLocalAudioEnabled;

  // ── Connection ──────────────────────────────────────────────────────

  @override
  Future<void> connect({
    required Map<String, dynamic> credentials,
    required bool videoEnabled,
  }) async {
    if (_isConnecting || _isConnected || _isReconnecting) return;

    await _ensurePermissions(videoEnabled: videoEnabled);
    await disconnect();

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();
    _eventController.add(CallMediaEvent.connecting);

    try {
      await _channel.invokeMethod('join', {
        'meeting': credentials['meeting'],
        'attendee': credentials['attendee'],
        'videoEnabled': videoEnabled,
      });
      _isConnected = true;
      _isLocalAudioEnabled = true;
      _isLocalVideoActive = videoEnabled;
      _eventController.add(CallMediaEvent.connected);
      if (videoEnabled) {
        _eventController.add(CallMediaEvent.localVideoEnabled);
      }
    } on PlatformException catch (e) {
      _errorMessage = _messageForPlatformError(e);
      _isConnected = false;
      _eventController.add(CallMediaEvent.failed);
      await disconnect();
      throw CallMediaException(_errorMessage!);
    } catch (error) {
      _errorMessage = 'Could not connect to the call server.';
      _isConnected = false;
      _eventController.add(CallMediaEvent.failed);
      await disconnect();
      throw CallMediaException(_errorMessage!);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnecting = false;
    _isReconnecting = false;

    try {
      await _channel.invokeMethod('leave');
    } catch (e) {
      debugPrint('Chime leave failed: $e');
    }

    _isConnected = false;
    _isLocalVideoActive = false;
    _isRemoteVideoActive = false;
    _hasRemoteParticipant = false;
    _isLocalAudioEnabled = null;
    _errorMessage = null;

    _eventController.add(CallMediaEvent.disconnected);
    notifyListeners();
  }

  // ── Media controls ──────────────────────────────────────────────────

  @override
  Future<void> setMuted(bool muted) async {
    try {
      await _channel.invokeMethod('setMuted', {'muted': muted});
      _isLocalAudioEnabled = !muted;
      notifyListeners();
    } on PlatformException catch (e) {
      throw CallMediaException(e.message ?? 'Mute failed.');
    } catch (e) {
      throw CallMediaException('Mute failed.');
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _ensureCameraPermission();
    try {
      await _channel.invokeMethod('setCameraEnabled', {'enabled': enabled});
      _isLocalVideoActive = enabled;
      _eventController.add(
        enabled
            ? CallMediaEvent.localVideoEnabled
            : CallMediaEvent.localVideoDisabled,
      );
      notifyListeners();
    } on PlatformException catch (e) {
      throw CallMediaException(e.message ?? 'Camera operation failed.');
    } catch (e) {
      throw CallMediaException('Camera operation failed.');
    }
  }

  @override
  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod('switchCamera');
      notifyListeners();
    } on PlatformException catch (e) {
      throw CallMediaException(e.message ?? 'Camera switch failed.');
    } catch (e) {
      throw CallMediaException('Camera switch failed.');
    }
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSpeakerEnabled', {'enabled': enabled});
      notifyListeners();
    } on PlatformException catch (e) {
      throw CallMediaException(e.message ?? 'Speaker routing failed.');
    } catch (e) {
      throw CallMediaException('Speaker routing failed.');
    }
  }

  // ── Native event handling ───────────────────────────────────────────

  void _listenToNativeEvents() {
    _nativeEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: _handleNativeEventError,
    );
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['event']?.toString();
    debugPrint('Chime native event: $type');

    switch (type) {
      case 'connected':
        _isConnected = true;
        _isConnecting = false;
        _isReconnecting = false;
        _eventController.add(CallMediaEvent.connected);
        break;
      case 'reconnecting':
        _isReconnecting = true;
        _eventController.add(CallMediaEvent.reconnecting);
        break;
      case 'disconnected':
        _isConnected = false;
        _isReconnecting = false;
        _eventController.add(CallMediaEvent.disconnected);
        break;
      case 'failed':
        _isConnected = false;
        _isReconnecting = false;
        _errorMessage = event['message']?.toString() ?? 'Call failed.';
        _eventController.add(CallMediaEvent.failed);
        break;
      case 'remoteJoined':
        _hasRemoteParticipant = true;
        _eventController.add(CallMediaEvent.remoteJoined);
        break;
      case 'remoteLeft':
        _hasRemoteParticipant = false;
        _isRemoteVideoActive = false;
        _eventController.add(CallMediaEvent.remoteLeft);
        break;
      case 'localMuted':
        _isLocalAudioEnabled = false;
        _eventController.add(CallMediaEvent.localMuted);
        break;
      case 'localUnmuted':
        _isLocalAudioEnabled = true;
        _eventController.add(CallMediaEvent.localUnmuted);
        break;
      case 'remoteVideoEnabled':
        _isRemoteVideoActive = true;
        _eventController.add(CallMediaEvent.remoteVideoEnabled);
        break;
      case 'remoteVideoDisabled':
        _isRemoteVideoActive = false;
        _eventController.add(CallMediaEvent.remoteVideoDisabled);
        break;
      case 'localVideoEnabled':
        _isLocalVideoActive = true;
        _eventController.add(CallMediaEvent.localVideoEnabled);
        break;
      case 'localVideoDisabled':
        _isLocalVideoActive = false;
        _eventController.add(CallMediaEvent.localVideoDisabled);
        break;
    }
    notifyListeners();
  }

  void _handleNativeEventError(Object error) {
    debugPrint('Chime native event error: $error');
  }

  // ── Permissions ─────────────────────────────────────────────────────

  Future<void> _ensurePermissions({required bool videoEnabled}) async {
    final microphone = await Permission.microphone.status;
    if (!microphone.isGranted) {
      throw const CallMediaException('Microphone permission is required.');
    }
    if (videoEnabled) {
      await _ensureCameraPermission();
    }
  }

  Future<void> _ensureCameraPermission() async {
    final camera = await Permission.camera.status;
    if (!camera.isGranted) {
      throw const CallMediaException('Camera permission is required.');
    }
  }

  // ── Error mapping ───────────────────────────────────────────────────

  String _messageForPlatformError(PlatformException error) {
    debugPrint('Chime platform error: ${error.code} ${error.message}');
    if (error.code == 'PERMISSION_DENIED') {
      return error.message ?? 'Permissions are required for calls.';
    }
    if (error.code == 'SESSION_FAILED') {
      return 'Call session could not be created.';
    }
    return error.message ?? 'Could not connect to the call server.';
  }

  // ── Cleanup ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nativeEventSubscription?.cancel();
    _eventController.close();
    try {
      _channel.invokeMethod('leave');
    } catch (_) {}
    super.dispose();
  }
}
