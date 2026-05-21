import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/call_participant.dart';
import '../models/call_session.dart';

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
  CallState _currentState = CallState.idle;
  CallSession? _activeCallSession;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _mockTransitionTimer;
  Timer? _resetTimer;

  CallState get currentState => _currentState;
  CallSession? get activeCallSession => _activeCallSession;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  Duration get callDuration => _callDuration;
  bool get isIncoming => _currentState == CallState.incoming;
  bool get hasActiveSession => _activeCallSession != null;
  bool get isOutgoing =>
      _currentState == CallState.outgoing ||
      _currentState == CallState.ringing ||
      _currentState == CallState.connecting;
  bool get isInCall =>
      _currentState == CallState.connecting ||
      _currentState == CallState.active ||
      _currentState == CallState.reconnecting;
  bool get canStartCall => _activeCallSession == null && _isIdleOrTerminal;

  String get formattedDuration {
    final hours = _callDuration.inHours;
    final minutes = (_callDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> startAudioCall({
    required CallParticipant caller,
    required CallParticipant receiver,
  }) {
    return _startOutgoingCall(
      caller: caller,
      receiver: receiver,
      callType: CallType.audio,
    );
  }

  Future<void> startVideoCall({
    required CallParticipant caller,
    required CallParticipant receiver,
  }) {
    return _startOutgoingCall(
      caller: caller,
      receiver: receiver,
      callType: CallType.video,
    );
  }

  void setIncomingCall(CallSession session) {
    if (!canStartCall) {
      _setState(CallState.busy);
      return;
    }
    _cancelPendingTimers();
    stopTimer();
    _activeCallSession = session.copyWith(status: CallState.incoming.name);
    _isMuted = false;
    _isSpeakerOn = session.callType == CallType.video;
    _isVideoEnabled = session.callType == CallType.video;
    _callDuration = Duration.zero;
    _setState(CallState.incoming);
  }

  Future<void> acceptCall() async {
    if (_activeCallSession == null) return;
    if (!_canTransitionTo(CallState.connecting)) return;
    _cancelPendingTimers();
    _activeCallSession = _activeCallSession!.copyWith(
      status: CallState.connecting.name,
      acceptedAt: DateTime.now(),
    );
    _setState(CallState.connecting);

    _mockTransitionTimer = Timer(const Duration(milliseconds: 700), () {
      if (_activeCallSession == null || _currentState != CallState.connecting) {
        return;
      }
      _activeCallSession = _activeCallSession!.copyWith(
        status: CallState.active.name,
        startedAt: DateTime.now(),
      );
      _setState(CallState.active);
      startTimer();
    });
  }

  void rejectCall() {
    if (_activeCallSession == null) return;
    if (!_canTransitionTo(CallState.rejected)) return;
    _finishCall(CallState.rejected);
  }

  void cancelCall() {
    if (_activeCallSession == null) return;
    if (!_canTransitionTo(CallState.ended)) return;
    _finishCall(CallState.ended);
  }

  void endCall() {
    if (_activeCallSession == null) return;
    if (!_canTransitionTo(CallState.ended)) return;
    _finishCall(CallState.ended);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    notifyListeners();
  }

  void startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void resetCall() {
    _cancelPendingTimers();
    stopTimer();
    _currentState = CallState.idle;
    _activeCallSession = null;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = false;
    _callDuration = Duration.zero;
    notifyListeners();
  }

  void onIncomingCallFromSocket(dynamic event) {
    _handleCallEvent(_normalizeEvent(event, fallbackType: 'call_invite'));
  }

  void onCallAcceptedFromSocket(dynamic event) {
    _handleCallEvent(_normalizeEvent(event, fallbackType: 'call_accepted'));
  }

  void onCallRejectedFromSocket(dynamic event) {
    _handleCallEvent(_normalizeEvent(event, fallbackType: 'call_rejected'));
  }

  void onCallEndedFromSocket(dynamic event) {
    _handleCallEvent(_normalizeEvent(event, fallbackType: 'call_ended'));
  }

  void onCallBusyFromSocket(dynamic event) {
    _handleCallEvent(_normalizeEvent(event, fallbackType: 'call_busy'));
  }

  Future<void> _startOutgoingCall({
    required CallParticipant caller,
    required CallParticipant receiver,
    required CallType callType,
  }) async {
    if (!canStartCall) return;
    _cancelPendingTimers();
    stopTimer();
    _callDuration = Duration.zero;
    _isMuted = false;
    _isSpeakerOn = callType == CallType.video;
    _isVideoEnabled = callType == CallType.video;
    _activeCallSession = _createMockSession(
      caller: caller,
      receiver: receiver,
      callType: callType,
    );
    _setState(CallState.outgoing);

    _mockTransitionTimer = Timer(const Duration(seconds: 2), () {
      if (_activeCallSession == null || _currentState != CallState.outgoing) {
        return;
      }
      _activeCallSession = _activeCallSession!.copyWith(
        status: CallState.ringing.name,
      );
      if (_canTransitionTo(CallState.ringing)) {
        _setState(CallState.ringing);
      }
    });
  }

  void _handleCallEvent(Map<String, dynamic> event) {
    final eventType = (event['type'] ?? event['event'] ?? '').toString();
    switch (eventType) {
      case 'call_invite':
        final session = _sessionFromEvent(event);
        if (session != null) {
          setIncomingCall(session);
        }
        break;
      case 'call_ringing':
        if (_canTransitionTo(CallState.ringing)) {
          _updateSessionStatus(CallState.ringing);
          _setState(CallState.ringing);
        }
        break;
      case 'call_accepted':
        if (_canTransitionTo(CallState.connecting)) {
          _updateSessionStatus(CallState.connecting);
          _setState(CallState.connecting);
        }
        break;
      case 'call_rejected':
        if (_canTransitionTo(CallState.rejected)) {
          _finishCall(CallState.rejected);
        }
        break;
      case 'call_ended':
        if (_canTransitionTo(CallState.ended)) {
          _finishCall(CallState.ended);
        }
        break;
      case 'call_busy':
        if (_canTransitionTo(CallState.busy)) {
          _finishCall(CallState.busy);
        }
        break;
      case 'call_missed':
        if (_canTransitionTo(CallState.missed)) {
          _finishCall(CallState.missed);
        }
        break;
    }
  }

  CallSession _createMockSession({
    required CallParticipant caller,
    required CallParticipant receiver,
    required CallType callType,
  }) {
    final uuid = _mockUuid();
    return CallSession(
      id: uuid,
      uuid: uuid,
      caller: caller,
      receiver: receiver,
      callType: callType,
      status: CallState.outgoing.name,
      roomName: 'mock_call_$uuid',
      startedAt: DateTime.now(),
    );
  }

  void _finishCall(CallState finalState) {
    if (!_isTerminalState(finalState)) return;
    _cancelPendingTimers();
    stopTimer();
    final now = DateTime.now();
    _activeCallSession = _activeCallSession?.copyWith(
      status: finalState.name,
      endedAt: now,
      durationSeconds: _callDuration.inSeconds,
    );
    _setState(finalState);
    _resetTimer = Timer(const Duration(seconds: 2), resetCall);
  }

  void _setState(CallState nextState) {
    if (!_canTransitionTo(nextState)) return;
    if (_currentState == nextState) {
      notifyListeners();
      return;
    }
    _currentState = nextState;
    notifyListeners();
  }

  void _updateSessionStatus(CallState state) {
    _activeCallSession = _activeCallSession?.copyWith(status: state.name);
  }

  bool _canTransitionTo(CallState nextState) {
    if (nextState == _currentState) return true;
    if (_currentState == CallState.idle) {
      return nextState == CallState.outgoing ||
          nextState == CallState.incoming ||
          nextState == CallState.failed;
    }
    if (_isTerminalState(_currentState)) {
      return nextState == CallState.idle;
    }
    switch (_currentState) {
      case CallState.outgoing:
        return nextState == CallState.ringing ||
            nextState == CallState.connecting ||
            _isTerminalState(nextState);
      case CallState.incoming:
        return nextState == CallState.connecting ||
            nextState == CallState.rejected ||
            nextState == CallState.missed ||
            nextState == CallState.ended;
      case CallState.ringing:
        return nextState == CallState.connecting ||
            nextState == CallState.busy ||
            _isTerminalState(nextState);
      case CallState.connecting:
        return nextState == CallState.active ||
            nextState == CallState.reconnecting ||
            _isTerminalState(nextState);
      case CallState.active:
        return nextState == CallState.reconnecting ||
            nextState == CallState.ended ||
            nextState == CallState.failed;
      case CallState.reconnecting:
        return nextState == CallState.active ||
            nextState == CallState.ended ||
            nextState == CallState.failed;
      case CallState.idle:
      case CallState.ended:
      case CallState.missed:
      case CallState.rejected:
      case CallState.busy:
      case CallState.failed:
        return false;
    }
  }

  bool get _isIdleOrTerminal =>
      _currentState == CallState.idle || _isTerminalState(_currentState);

  bool _isTerminalState(CallState state) {
    return state == CallState.ended ||
        state == CallState.missed ||
        state == CallState.rejected ||
        state == CallState.busy ||
        state == CallState.failed;
  }

  Map<String, dynamic> _normalizeEvent(dynamic event, {String? fallbackType}) {
    if (event is Map<String, dynamic>) {
      return {
        if (fallbackType != null) 'type': fallbackType,
        ...event,
      };
    }
    if (event is Map) {
      return {
        if (fallbackType != null) 'type': fallbackType,
        ...Map<String, dynamic>.from(event),
      };
    }
    if (event is String) {
      return {'type': event};
    }
    return {if (fallbackType != null) 'type': fallbackType};
  }

  CallSession? _sessionFromEvent(Map<String, dynamic> event) {
    final payload = event['payload'] is Map
        ? Map<String, dynamic>.from(event['payload'])
        : event;
    final rawSession = payload['session'];
    if (rawSession is Map) {
      return CallSession.fromJson(Map<String, dynamic>.from(rawSession));
    }
    if (payload['caller'] is Map && payload['receiver'] is Map) {
      return CallSession.fromJson(payload);
    }
    return null;
  }

  void _cancelPendingTimers() {
    _mockTransitionTimer?.cancel();
    _mockTransitionTimer = null;
    _resetTimer?.cancel();
    _resetTimer = null;
  }

  String _mockUuid() {
    final random = Random.secure();
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }

  @override
  void dispose() {
    _cancelPendingTimers();
    stopTimer();
    super.dispose();
  }
}
