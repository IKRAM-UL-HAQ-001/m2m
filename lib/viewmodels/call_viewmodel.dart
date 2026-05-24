import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/call_event.dart';
import '../models/call_participant.dart';
import '../models/call_session.dart';
import '../services/api_service.dart';
import '../services/call_foreground_service.dart';
import '../services/ios_call_audio_session_service.dart';
import '../services/livekit_call_service.dart';
import '../services/notification_service.dart';

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
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _reconnectGracePeriod = Duration(seconds: 90);
  static const Duration _callActionTimeout = Duration(seconds: 8);
  static const Duration _terminalStateClearDelay = Duration(milliseconds: 1400);

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
  final ValueNotifier<Duration> callDurationNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  Timer? _durationTimer;
  String? _connectingLiveKitCallId;
  String? _connectedLiveKitCallId;
  Future<void>? _joinInFlight;
  Future<void>? _acceptInFlight;
  String? _acceptingCallId;
  DateTime? _acceptStartedAt;
  StreamSubscription<lk.RoomDisconnectedEvent>? _liveKitDisconnectSubscription;
  StreamSubscription<IosCallAudioSessionEvent>? _iosAudioSessionSubscription;
  Timer? _reconnectGraceTimer;
  int _reconnectAttempts = 0;
  bool _manualDisconnectRequested = false;
  bool _recoveringConnection = false;
  Timer? _terminalStateClearTimer;

  CallViewModel() {
    _liveKitService.addListener(_handleMediaStateChanged);
    _liveKitDisconnectSubscription = _liveKitService.disconnectStream.listen(
      _handleLiveKitDisconnected,
    );
    _iosAudioSessionSubscription = IosCallAudioSessionService.events.listen(
      _handleIosAudioSessionEvent,
    );
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
  Duration get callDuration => callDurationNotifier.value;
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
  String get lifecycleDiagnostics =>
      'callState=${_currentState.name} callId=${_currentCall?.id ?? 'none'} '
      'liveKit=${_liveKitService.diagnosticState}';

  String get formattedDuration {
    final duration = callDuration;
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  Future<CallSession?> startCall({
    required int receiverId,
    required String callType,
  }) async {
    resetCurrentCallIfTerminal();
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
    if (!acceptCallFast(callId)) return null;
    final acceptFuture = _acceptInFlight;
    if (acceptFuture != null) {
      await acceptFuture;
    }
    return _currentState == CallState.failed ? null : _currentCall;
  }

  bool acceptCallFast([int? callId]) {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return false;
    if (_acceptingCallId == id.toString() && _acceptInFlight != null) {
      return true;
    }

    _acceptStartedAt = DateTime.now();
    debugPrint('Call accept tapped callId=$id');
    unawaited(NotificationService().dismissIncomingCall(id.toString()));
    _isConnecting = true;
    _errorMessage = null;
    _manualDisconnectRequested = false;
    _setState(CallState.connecting);
    _acceptingCallId = id.toString();
    final acceptFuture = _acceptCallInBackground(id);
    _acceptInFlight = acceptFuture;
    unawaited(
      acceptFuture.whenComplete(() {
        if (_acceptingCallId == id.toString()) {
          _acceptingCallId = null;
          _acceptInFlight = null;
        }
      }),
    );
    return true;
  }

  Future<void> _acceptCallInBackground(int id) async {
    try {
      debugPrint('Backend accept started callId=$id');
      final call = await _apiService.acceptCall(id).timeout(_callActionTimeout);
      debugPrint('Backend accept completed callId=$id');
      _currentCall = call;
      _errorMessage = null;
      if (_manualDisconnectRequested || _isTerminalState(_currentState)) {
        return;
      }
      debugPrint('LiveKit join started callId=$id');
      await joinCallAndConnect(call.id);
      debugPrint('LiveKit join completed callId=$id');
      _logAcceptElapsed('total accept-to-media-connected time', id);
    } on ApiException catch (error) {
      _isConnecting = false;
      _errorMessage = _messageForError(error);
      _setState(_stateForErrorCode(error.code));
    } catch (_) {
      _isConnecting = false;
      _errorMessage = 'Network error. Please try again.';
      _setState(CallState.failed);
    }
  }

  Future<void> rejectCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    debugPrint('Call reject tapped callId=$id');
    NotificationService().dismissIncomingCall(id.toString());
    _manualDisconnectRequested = true;
    _finishCall(CallState.rejected);
    unawaited(_disconnectLiveKit());
    unawaited(
      _finishWithApi(
        () => _apiService.rejectCall(id).timeout(_callActionTimeout),
        CallState.rejected,
        optimistic: true,
        actionName: 'reject',
        callId: id,
      ),
    );
  }

  Future<void> cancelCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    debugPrint('Call cancel tapped callId=$id');
    NotificationService().dismissIncomingCall(id.toString());
    _manualDisconnectRequested = true;
    _finishCall(CallState.ended);
    unawaited(_disconnectLiveKit());
    unawaited(
      _finishWithApi(
        () => _apiService.cancelCall(id).timeout(_callActionTimeout),
        CallState.ended,
        optimistic: true,
        actionName: 'cancel',
        callId: id,
      ),
    );
  }

  Future<void> endCall([int? callId]) async {
    final id = callId ?? int.tryParse(_currentCall?.id ?? '');
    if (id == null) return;
    debugPrint('Call end tapped callId=$id');
    NotificationService().dismissIncomingCall(id.toString());
    _manualDisconnectRequested = true;
    _finishCall(CallState.ended);
    unawaited(_disconnectLiveKit());
    unawaited(
      _finishWithApi(
        () => _apiService.endCall(id).timeout(_callActionTimeout),
        CallState.ended,
        optimistic: true,
        actionName: 'end',
        callId: id,
      ),
    );
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
    debugPrint('Call event received type=${event.type} callId=${call.id}');
    switch (event.type) {
      case 'call_invite':
        if (canStartCall || _currentCall?.id == call.id) {
          _currentCall = call;
          _prepareNewCall(call.callType);
          _setState(CallState.incoming);
        } else {
          debugPrint(
            'Call invite ignored while busy incomingCallId=${call.id} '
            'currentCallId=${_currentCall?.id} state=${_currentState.name}',
          );
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

  void markActiveCallScreenPushed() {
    final callId = int.tryParse(_currentCall?.id ?? '');
    if (callId == null) return;
    debugPrint('Active call route pushed callId=$callId');
    _logAcceptElapsed('total accept-to-active-screen time', callId);
  }

  Future<bool> setIncomingCallFromPush(Map<String, dynamic> data) async {
    final callId = data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return false;
    if (!canStartCall && _currentCall?.id != callId) return false;

    try {
      final call = await _apiService.getCallDetail(int.parse(callId));
      if (call.isTerminal || call.status != 'ringing') return false;
      setIncomingCall(call);
      return true;
    } catch (_) {
      return setIncomingCallFromPushPayload(data);
    }
  }

  bool setIncomingCallFromPushPayload(Map<String, dynamic> data) {
    final callId = data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return false;
    if (!canStartCall && _currentCall?.id != callId) return false;

    final callerName = data['caller_name']?.toString() ?? 'Incoming call';
    final callType = CallType.fromString(data['call_type']);
    setIncomingCall(
      CallSession(
        id: callId,
        uuid: callId,
        caller: CallParticipant(
          id: data['caller_id']?.toString() ?? '',
          name: callerName,
          phone: '',
          avatarUrl: data['caller_profile_picture']?.toString(),
        ),
        receiver: CallParticipant(
          id: ApiService.currentUserId ?? '',
          name: '',
          phone: '',
        ),
        callType: callType,
        status: 'ringing',
        roomName: data['room_name']?.toString() ?? '',
        isActive: true,
      ),
    );
    return true;
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
    _terminalStateClearTimer?.cancel();
    _terminalStateClearTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _currentState = CallState.idle;
    _currentCall = null;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = false;
    _isConnecting = false;
    _errorMessage = null;
    _setCallDuration(Duration.zero);
    _connectedLiveKitCallId = null;
    _connectingLiveKitCallId = null;
    _acceptingCallId = null;
    _acceptInFlight = null;
    _acceptStartedAt = null;
    _manualDisconnectRequested = true;
    _reconnectGraceTimer?.cancel();
    _reconnectGraceTimer = null;
    _reconnectAttempts = 0;
    _recoveringConnection = false;
    unawaited(CallForegroundService.stop());
    unawaited(IosCallAudioSessionService.deactivateAfterCall());
    unawaited(_disconnectLiveKit());
    notifyListeners();
  }

  Future<void> _finishWithApi(
    Future<CallSession> Function() action,
    CallState fallbackState, {
    bool optimistic = false,
    String actionName = 'call action',
    int? callId,
  }) async {
    if (!optimistic) {
      _isConnecting = true;
      notifyListeners();
    }
    try {
      if (callId != null) {
        debugPrint('Backend $actionName started callId=$callId');
      }
      final call = await action();
      debugPrint('Backend $actionName completed callId=${call.id}');
      if (optimistic && _currentCall == null) {
        _errorMessage = null;
        return;
      }
      if (_currentCall == null || _currentCall!.id == call.id) {
        _currentCall = call;
      }
      _errorMessage = null;
      final nextState = _stateFromBackendStatus(
        call.status,
        fallback: fallbackState,
      );
      if (!optimistic || !_isTerminalState(_currentState)) {
        _finishCall(nextState);
      }
    } on ApiException catch (error) {
      if (optimistic && _currentCall == null) return;
      _errorMessage = _messageForError(error);
      if (!optimistic) {
        _finishCall(_stateForErrorCode(error.code));
      } else {
        notifyListeners();
      }
    } catch (_) {
      if (optimistic && _currentCall == null) return;
      _errorMessage = 'Network timeout. Please check call status.';
      if (!optimistic) {
        _finishCall(CallState.failed);
      } else {
        notifyListeners();
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void _prepareNewCall(CallType callType) {
    _durationTimer?.cancel();
    _durationTimer = null;
    _setCallDuration(Duration.zero);
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
    _setCallDuration(
      _currentCall?.durationSeconds != null
          ? Duration(seconds: _currentCall!.durationSeconds)
          : callDuration,
    );
    if (_isTerminalState(state)) {
      NotificationService().dismissIncomingCall(_currentCall?.id);
      unawaited(_disconnectLiveKit());
      _scheduleTerminalStateClear();
    }
    _setState(state);
  }

  Future<void> _joinCallAndConnect(CallSession call, String callId) async {
    _isConnecting = true;
    _errorMessage = null;
    _setState(CallState.connecting);
    try {
      debugPrint('LiveKit credentials request started callId=$callId');
      final credentials = await _apiService.joinCall(int.parse(callId));
      debugPrint('LiveKit credentials request completed callId=$callId');
      await IosCallAudioSessionService.configureForCall(
        isVideo: call.callType == CallType.video,
        defaultToSpeaker: call.callType == CallType.video || _isSpeakerOn,
      );
      debugPrint('LiveKit connect started callId=$callId');
      await _liveKitService.connect(
        serverUrl: credentials.serverUrl,
        token: credentials.token,
        videoEnabled: call.callType == CallType.video,
      );
      debugPrint('LiveKit connect completed callId=$callId');
      _connectedLiveKitCallId = callId;
      _manualDisconnectRequested = false;
      _reconnectAttempts = 0;
      _recoveringConnection = false;
      _reconnectGraceTimer?.cancel();
      _reconnectGraceTimer = null;
      _isConnecting = false;
      _errorMessage = null;
      _setState(CallState.active);
      _startTimerFromCall(call);
    } on ApiException catch (error) {
      _isConnecting = false;
      _errorMessage = _messageForError(error);
      await _releaseBackendCallAfterMediaFailure(callId);
      _setState(_stateForErrorCode(error.code));
    } on CallMediaException catch (error) {
      _isConnecting = false;
      _errorMessage = error.message;
      await _releaseBackendCallAfterMediaFailure(callId);
      _setState(CallState.failed);
    } catch (_) {
      _isConnecting = false;
      _errorMessage = 'Could not connect to the call.';
      await _releaseBackendCallAfterMediaFailure(callId);
      _setState(CallState.failed);
    }
  }

  void _logAcceptElapsed(String label, int callId) {
    final startedAt = _acceptStartedAt;
    if (startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    debugPrint('$label callId=$callId elapsedMs=$elapsed');
  }

  Future<void> _releaseBackendCallAfterMediaFailure(String callId) async {
    try {
      final endedCall = await _apiService.endCall(int.parse(callId));
      _currentCall = endedCall;
    } catch (_) {
      // The original media/join error should remain visible to the user.
    } finally {
      await _disconnectLiveKit();
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

  void _handleLiveKitDisconnected(lk.RoomDisconnectedEvent event) {
    if (_manualDisconnectRequested || _currentCall == null) return;
    if (!_isRecoverableDisconnect(event.reason)) return;
    debugPrint(
      'LiveKit disconnected unexpectedly callId=${_currentCall!.id} reason=${event.reason}',
    );
    _scheduleReconnectRecovery(event.reason?.name ?? 'disconnected');
  }

  bool _isRecoverableDisconnect(lk.DisconnectReason? reason) {
    return reason == null ||
        reason == lk.DisconnectReason.unknown ||
        reason == lk.DisconnectReason.disconnected ||
        reason == lk.DisconnectReason.signalingConnectionFailure ||
        reason == lk.DisconnectReason.reconnectAttemptsExceeded ||
        reason == lk.DisconnectReason.joinFailure;
  }

  void _scheduleReconnectRecovery(String reason) {
    if (_recoveringConnection || _isTerminalState(_currentState)) return;
    _recoveringConnection = true;
    _isConnecting = true;
    _errorMessage = 'Reconnecting...';
    _setState(CallState.reconnecting);
    _reconnectGraceTimer ??= Timer(_reconnectGracePeriod, () {
      debugPrint(
        'LiveKit reconnect grace period expired callId=${_currentCall?.id}',
      );
      _failReconnect('Call connection lost.');
    });
    unawaited(_recoverLiveKitConnection(reason));
  }

  Future<void> handleAppResumed() async {
    final call = _currentCall;
    if (call == null) {
      await restoreCurrentCallIfNeeded();
      return;
    }
    if (_isTerminalState(_currentState)) {
      resetCurrentCallIfTerminal();
      return;
    }
    if (isInCall) {
      await IosCallAudioSessionService.reactivateForCall();
    }

    final callId = int.tryParse(call.id);
    if (callId == null) return;
    try {
      final latestCall = await _apiService.getCallDetail(callId);
      _currentCall = latestCall;
      final latestState = _stateFromBackendStatus(
        latestCall.status,
        fallback: _currentState,
      );
      if (_isTerminalState(latestState)) {
        _finishCall(latestState);
        return;
      }
      if ((latestCall.status == 'accepted' || latestCall.status == 'active') &&
          !_liveKitService.isConnected &&
          !_recoveringConnection) {
        _scheduleReconnectRecovery('app_resumed');
      } else {
        notifyListeners();
      }
    } on ApiException catch (error) {
      if (error.code == 'not_found') {
        await restoreCurrentCallIfNeeded(force: true);
      } else {
        debugPrint('Call resume check failed callId=$callId error=$error');
      }
    } catch (error) {
      debugPrint('Call resume check failed callId=$callId error=$error');
    }
  }

  Future<void> restoreCurrentCallIfNeeded({bool force = false}) async {
    if (!force && _currentCall != null && !_isTerminalState(_currentState)) {
      return;
    }
    try {
      debugPrint('Current call restore started');
      final call = await _apiService.getCurrentCall();
      if (call == null) {
        debugPrint('Current call restore completed result=none');
        if (force) {
          resetCall();
        }
        return;
      }

      _currentCall = call;
      _prepareNewCall(call.callType);
      final restoredState = _stateFromBackendStatus(
        call.status,
        fallback: CallState.ringing,
      );
      debugPrint(
        'Current call restore completed callId=${call.id} state=${restoredState.name}',
      );
      _setState(restoredState);
      if (call.status == 'accepted' || call.status == 'active') {
        _startTimerFromCall(call);
        if (!_liveKitService.isConnected && !_recoveringConnection) {
          _scheduleReconnectRecovery('current_call_restore');
        }
      }
    } catch (error) {
      debugPrint('Current call restore failed: $error');
    }
  }

  Future<void> _recoverLiveKitConnection(String reason) async {
    final call = _currentCall;
    if (call == null) return;
    final callId = int.tryParse(call.id);
    if (callId == null) {
      _failReconnect('Call connection lost.');
      return;
    }

    while (_reconnectAttempts < _maxReconnectAttempts &&
        !_manualDisconnectRequested &&
        !_isTerminalState(_currentState)) {
      _reconnectAttempts++;
      debugPrint(
        'LiveKit reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts callId=${call.id} reason=$reason',
      );
      await Future.delayed(_reconnectDelay);
      try {
        final latestCall = await _apiService.getCallDetail(callId);
        _currentCall = latestCall;
        if (latestCall.status != 'accepted' && latestCall.status != 'active') {
          _finishCall(
            _stateFromBackendStatus(
              latestCall.status,
              fallback: CallState.ended,
            ),
          );
          return;
        }

        final credentials = await _apiService.joinCall(callId);
        await IosCallAudioSessionService.configureForCall(
          isVideo: latestCall.callType == CallType.video && _isVideoEnabled,
          defaultToSpeaker:
              _isSpeakerOn || latestCall.callType == CallType.video,
        );
        await _liveKitService.connect(
          serverUrl: credentials.serverUrl,
          token: credentials.token,
          videoEnabled:
              latestCall.callType == CallType.video && _isVideoEnabled,
        );
        await _restoreMediaState();
        _connectedLiveKitCallId = latestCall.id;
        _isConnecting = false;
        _errorMessage = null;
        _recoveringConnection = false;
        _reconnectAttempts = 0;
        _reconnectGraceTimer?.cancel();
        _reconnectGraceTimer = null;
        _setState(CallState.active);
        return;
      } catch (error) {
        debugPrint(
          'LiveKit reconnect attempt failed callId=${call.id} attempt=$_reconnectAttempts error=$error',
        );
      }
    }

    if (!_manualDisconnectRequested) {
      _failReconnect('Could not reconnect to the call.');
    }
  }

  Future<void> _restoreMediaState() async {
    await IosCallAudioSessionService.reactivateForCall();
    await _liveKitService.muteMicrophone(_isMuted);
    if (_currentCall?.callType == CallType.video) {
      await _liveKitService.enableCamera(_isVideoEnabled);
    }
    await _liveKitService.setSpeakerphoneOn(_isSpeakerOn);
  }

  void _failReconnect(String message) {
    _reconnectGraceTimer?.cancel();
    _reconnectGraceTimer = null;
    _recoveringConnection = false;
    _isConnecting = false;
    _errorMessage = message;
    _finishCall(CallState.failed);
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
    var duration = acceptedAt == null
        ? Duration.zero
        : DateTime.now().difference(acceptedAt);
    if (duration.isNegative) duration = Duration.zero;
    _setCallDuration(duration);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setCallDuration(callDuration + const Duration(seconds: 1));
    });
  }

  void _setCallDuration(Duration duration) {
    if (callDurationNotifier.value == duration) return;
    callDurationNotifier.value = duration;
  }

  void _setState(CallState state) {
    _currentState = state;
    if (isInCall) {
      unawaited(CallForegroundService.start());
      if (state == CallState.active || state == CallState.reconnecting) {
        unawaited(IosCallAudioSessionService.reactivateForCall());
      }
    } else if (_isTerminalState(state) || state == CallState.idle) {
      unawaited(CallForegroundService.stop());
      unawaited(IosCallAudioSessionService.deactivateAfterCall());
    }
    notifyListeners();
  }

  void _handleIosAudioSessionEvent(IosCallAudioSessionEvent event) {
    debugPrint('iOS audio session event received type=${event.type}');
    if (!isInCall || _isTerminalState(_currentState)) return;
    if (event.type == 'audioSessionInterrupted') {
      final phase = event.data['phase']?.toString();
      if (phase == 'ended') {
        unawaited(_handleIosAudioSessionRecovered());
      }
    } else if (event.type == 'audioSessionRouteChanged') {
      unawaited(IosCallAudioSessionService.reactivateForCall());
    }
  }

  Future<void> _handleIosAudioSessionRecovered() async {
    await IosCallAudioSessionService.reactivateForCall();
    await _restoreMediaState();
    if (!_liveKitService.isConnected && !_recoveringConnection) {
      _scheduleReconnectRecovery('ios_audio_session_recovered');
    }
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
      'already_in_call' => 'You are already in a call.',
      'call_not_joinable' => 'Call already ended or is not ready.',
      'livekit_not_configured' => 'Call server is not configured.',
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

  void clearEndedCallState() {
    resetCurrentCallIfTerminal();
  }

  void resetCurrentCallIfTerminal() {
    if (_isTerminalState(_currentState)) {
      resetCall();
    }
  }

  void _scheduleTerminalStateClear() {
    _terminalStateClearTimer?.cancel();
    _terminalStateClearTimer = Timer(_terminalStateClearDelay, () {
      if (_isTerminalState(_currentState)) {
        resetCall();
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    callDurationNotifier.dispose();
    _reconnectGraceTimer?.cancel();
    _terminalStateClearTimer?.cancel();
    _liveKitDisconnectSubscription?.cancel();
    _iosAudioSessionSubscription?.cancel();
    _liveKitService.removeListener(_handleMediaStateChanged);
    unawaited(CallForegroundService.stop());
    unawaited(IosCallAudioSessionService.deactivateAfterCall());
    _liveKitService.dispose();
    super.dispose();
  }
}
