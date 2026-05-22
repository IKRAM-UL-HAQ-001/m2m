import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/call_event.dart';
import '../models/call_participant.dart';
import '../models/call_session.dart';
import '../services/api_service.dart';
import '../services/livekit_call_service.dart';

enum CallState {
  idle,
  outgoing,
  incoming,
  ringing,
  connecting,
  active,
  reconnecting,
  ended,
  missed,
  rejected,
  busy,
  failed,
}

class CallViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LiveKitCallService _liveKitService = LiveKitCallService();

  CallState _currentState = CallState.idle;
  CallSession? _currentCall;
  List<CallSession> _callHistory = [];
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;
  bool _isConnecting = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  String? _connectingLiveKitCallId;
  String? _connectedLiveKitCallId;
  Future<void>? _joinInFlight;

  CallViewModel() {
    _liveKitService.addListener(_handleMediaStateChanged);
  }

  CallState get currentState => _currentState;
  CallState get callState => _currentState;
  CallSession? get currentCall => _currentCall;
  CallSession? get activeCallSession => _currentCall;
  LiveKitCallService get liveKitService => _liveKitService;
  lk.VideoTrack? get localVideoTrack => _liveKitService.localVideoTrack;
  lk.VideoTrack? get remoteVideoTrack => _liveKitService.remoteVideoTrack;
  List<CallSession> get callHistory => List.unmodifiable(_callHistory);
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isConnecting => _isConnecting;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get errorMessage => _errorMessage;
  Duration get callDuration => _callDuration;
  bool get isIncoming => _currentState == CallState.incoming;
  bool get hasActiveSession => _currentCall != null;
  bool get canStartCall =>
      _currentCall == null || _isTerminalState(_currentState);
  bool get isOutgoing =>
      _currentState == CallState.outgoing ||
      _currentState == CallState.ringing ||
      _currentState == CallState.connecting;
  bool get isInCall =>
      _currentState == CallState.connecting ||
      _currentState == CallState.active ||
      _currentState == CallState.reconnecting;

  String get formattedDuration {
    final hours = _callDuration.inHours;
    final minutes = (_callDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  Future<CallSession?> startCall({
    required int receiverId,
    required String callType,
  }) async {
    if (!canStartCall) {
      _setError('You are already in a call.');
      _setState(CallState.busy);
      return null;
    }
    _prepareNewCall(CallType.fromString(callType));
    _setState(CallState.outgoing);
    _isConnecting = true;
    notifyListeners();
    try {
      final call = await _apiService.startCall(
        receiverId: receiverId,
        callType: callType,
      );
      _currentCall = call;
      _isConnecting = false;
      _errorMessage = null;
      _setState(
        _stateFromBackendStatus(call.status, fallback: CallState.ringing),
      );
      return call;
    } on ApiException catch (error) {
      _isConnecting = false;
      _errorMessage = _messageForError(error);
      _setState(_stateForErrorCode(error.code));
      return null;
    } catch (_) {
      _isConnecting = false;
      _errorMessage = 'Network error. Please try again.';
      _setState(CallState.failed);
      return null;
    }
  }

  Future<void> startAudioCall({
    required CallParticipant caller,
    required CallParticipant receiver,
  }) {
    return startCall(
      receiverId: int.tryParse(receiver.id) ?? 0,
      callType: CallType.audio.value,
    );
  }

  Future<void> startVideoCall({
    required CallParticipant caller,
    required CallParticipant receiver,
  }) {
    return startCall(
      receiverId: int.tryParse(receiver.id) ?? 0,
      callType: CallType.video.value,
    );
  }

  Future<CallSession?> acceptCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return null;
    _isConnecting = true;
    _setState(CallState.connecting);
    try {
      final call = await _apiService.acceptCall(id);
      _currentCall = call;
      _errorMessage = null;
      await joinCallAndConnect(call.id);
      return _currentState == CallState.failed ? null : call;
    } on ApiException catch (error) {
      _isConnecting = false;
      _errorMessage = _messageForError(error);
      _setState(_stateForErrorCode(error.code));
      return null;
    } catch (_) {
      _isConnecting = false;
      _errorMessage = 'Network error. Please try again.';
      _setState(CallState.failed);
      return null;
    }
  }

  Future<void> rejectCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    await _disconnectLiveKit();
    await _finishWithApi(() => _apiService.rejectCall(id), CallState.rejected);
  }

  Future<void> cancelCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    await _disconnectLiveKit();
    await _finishWithApi(() => _apiService.cancelCall(id), CallState.ended);
  }

  Future<void> endCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    await _disconnectLiveKit();
    await _finishWithApi(() => _apiService.endCall(id), CallState.ended);
  }

  Future<void> joinCallAndConnect([String? callId]) async {
    final call = _currentCall;
    final id = callId ?? call?.id;
    if (call == null || id == null || id.isEmpty) return;
    if (_connectedLiveKitCallId == id && _liveKitService.isConnected) return;
    if (_connectingLiveKitCallId == id && _joinInFlight != null) {
      await _joinInFlight;
      return;
    }

    _connectingLiveKitCallId = id;
    _joinInFlight = _joinCallAndConnect(call, id);
    try {
      await _joinInFlight;
    } finally {
      _joinInFlight = null;
      _connectingLiveKitCallId = null;
    }
  }

  Future<void> loadCallHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _callHistory = await _apiService.getCallHistory();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Could not load call history.';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void handleCallEvent(CallEvent event) {
    final call = event.call;
    switch (event.type) {
      case 'call_invite':
        if (canStartCall || _currentCall?.id == call.id) {
          _currentCall = call;
          _prepareNewCall(call.callType);
          _setState(CallState.incoming);
        }
        break;
      case 'call_ringing':
        _mergeCall(call);
        _setState(CallState.ringing);
        break;
      case 'call_accepted':
        _mergeCall(call);
        unawaited(joinCallAndConnect(call.id));
        break;
      case 'call_rejected':
        _finishFromEvent(call, CallState.rejected);
        break;
      case 'call_cancelled':
      case 'call_ended':
        _finishFromEvent(call, CallState.ended);
        break;
      case 'call_missed':
        _finishFromEvent(call, CallState.missed);
        break;
      case 'call_busy':
        _finishFromEvent(call, CallState.busy);
        break;
      case 'call_failed':
        _finishFromEvent(call, CallState.failed);
        break;
    }
  }

  void setIncomingCall(CallSession session) {
    _currentCall = session;
    _prepareNewCall(session.callType);
    _setState(CallState.incoming);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
    unawaited(
      _liveKitService.muteMicrophone(_isMuted).catchError(_handleMediaError),
    );
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
    unawaited(
      _liveKitService
          .setSpeakerphoneOn(_isSpeakerOn)
          .catchError(_handleMediaError),
    );
  }

  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    notifyListeners();
    unawaited(
      _liveKitService.enableCamera(_isVideoEnabled).catchError((error) {
        _isVideoEnabled = !_isVideoEnabled;
        _handleMediaError(error);
      }),
    );
  }

  void switchCamera() {
    unawaited(_liveKitService.switchCamera().catchError(_handleMediaError));
  }

  void resetCall() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _currentState = CallState.idle;
    _currentCall = null;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = false;
    _isConnecting = false;
    _errorMessage = null;
    _callDuration = Duration.zero;
    _connectedLiveKitCallId = null;
    _connectingLiveKitCallId = null;
    unawaited(_disconnectLiveKit());
    notifyListeners();
  }

  Future<void> _finishWithApi(
    Future<CallSession> Function() action,
    CallState fallbackState,
  ) async {
    _isConnecting = true;
    notifyListeners();
    try {
      final call = await action();
      _currentCall = call;
      _errorMessage = null;
      _finishCall(
        _stateFromBackendStatus(call.status, fallback: fallbackState),
      );
    } on ApiException catch (error) {
      _errorMessage = _messageForError(error);
      _finishCall(_stateForErrorCode(error.code));
    } catch (_) {
      _errorMessage = 'Network error. Please try again.';
      _finishCall(CallState.failed);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void _prepareNewCall(CallType callType) {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = Duration.zero;
    _isMuted = false;
    _isSpeakerOn = callType == CallType.video;
    _isVideoEnabled = callType == CallType.video;
    _errorMessage = null;
  }

  void _mergeCall(CallSession call) {
    if (_currentCall == null || _currentCall!.id == call.id) {
      _currentCall = call;
    }
  }

  void _finishFromEvent(CallSession call, CallState state) {
    _mergeCall(call);
    _finishCall(state);
  }

  void _finishCall(CallState state) {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = _currentCall?.durationSeconds != null
        ? Duration(seconds: _currentCall!.durationSeconds)
        : _callDuration;
    if (_isTerminalState(state)) {
      unawaited(_disconnectLiveKit());
    }
    _setState(state);
  }

  Future<void> _joinCallAndConnect(CallSession call, String callId) async {
    _isConnecting = true;
    _errorMessage = null;
    _setState(CallState.connecting);
    try {
      final credentials = await _apiService.joinCall(int.parse(callId));
      await _liveKitService.connect(
        serverUrl: credentials.serverUrl,
        token: credentials.token,
        videoEnabled: call.callType == CallType.video,
      );
      _connectedLiveKitCallId = callId;
      _isConnecting = false;
      _errorMessage = null;
      _setState(CallState.active);
      _startTimerFromCall(call);
    } on ApiException catch (error) {
      _isConnecting = false;
      _errorMessage = _messageForError(error);
      _setState(_stateForErrorCode(error.code));
    } on CallMediaException catch (error) {
      _isConnecting = false;
      _errorMessage = error.message;
      _setState(CallState.failed);
    } catch (_) {
      _isConnecting = false;
      _errorMessage = 'Could not connect to the call.';
      _setState(CallState.failed);
    }
  }

  Future<void> _disconnectLiveKit() async {
    _connectedLiveKitCallId = null;
    try {
      await _liveKitService.disconnect();
    } catch (_) {
      // The backend call state is the source of truth; disconnect failures should
      // not block ending or resetting the call.
    }
  }

  void _handleMediaStateChanged() {
    if (_currentState == CallState.active && _liveKitService.isReconnecting) {
      _currentState = CallState.reconnecting;
    } else if (_currentState == CallState.reconnecting &&
        _liveKitService.isConnected) {
      _currentState = CallState.active;
    }
    notifyListeners();
  }

  void _handleMediaError(Object error) {
    _errorMessage = error is CallMediaException
        ? error.message
        : 'Call media action failed.';
    notifyListeners();
  }

  void _startTimerFromCall(CallSession call) {
    _durationTimer?.cancel();
    final acceptedAt = call.acceptedAt;
    _callDuration = acceptedAt == null
        ? Duration.zero
        : DateTime.now().difference(acceptedAt);
    if (_callDuration.isNegative) _callDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _setState(CallState state) {
    _currentState = state;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  CallState _stateFromBackendStatus(
    String status, {
    required CallState fallback,
  }) {
    return switch (status) {
      'initiated' => CallState.outgoing,
      'ringing' => CallState.ringing,
      'accepted' || 'active' => CallState.active,
      'rejected' => CallState.rejected,
      'cancelled' || 'ended' => CallState.ended,
      'missed' => CallState.missed,
      'busy' => CallState.busy,
      'failed' => CallState.failed,
      _ => fallback,
    };
  }

  CallState _stateForErrorCode(String? code) {
    return switch (code) {
      'user_busy' || 'caller_busy' => CallState.busy,
      'not_found' => CallState.ended,
      'permission_denied' => CallState.failed,
      _ => CallState.failed,
    };
  }

  String _messageForError(ApiException error) {
    return switch (error.code) {
      'user_busy' => 'User is busy.',
      'caller_busy' => 'You are already in a call.',
      'permission_denied' => 'You do not have permission for this call.',
      'not_found' => 'Call not found.',
      'validation_error' => error.message,
      _ => error.message,
    };
  }

  bool _isTerminalState(CallState state) {
    return state == CallState.ended ||
        state == CallState.missed ||
        state == CallState.rejected ||
        state == CallState.busy ||
        state == CallState.failed;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _liveKitService.removeListener(_handleMediaStateChanged);
    _liveKitService.dispose();
    super.dispose();
  }
}
