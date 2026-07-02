import 'dart:async';

import 'package:flutter/foundation.dart';

/// Exception thrown by [CallMediaService] implementations when a media
/// operation cannot be completed (e.g. missing permission, network failure).
class CallMediaException implements Exception {
  final String message;

  const CallMediaException(this.message);

  @override
  String toString() => message;
}

/// Provider-neutral media events emitted by [CallMediaService].
enum CallMediaEvent {
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
  remoteJoined,
  remoteLeft,
  localMuted,
  localUnmuted,
  localVideoEnabled,
  localVideoDisabled,
  remoteVideoEnabled,
  remoteVideoDisabled,
}

/// Provider-neutral interface that every media backend (LiveKit, Chime, etc.)
/// must implement.  The [CallViewModel] depends only on this contract so the
/// underlying media provider can be swapped without touching call lifecycle.
abstract class CallMediaService extends ChangeNotifier {
  /// Stream of media events for lifecycle-critical state changes.
  Stream<CallMediaEvent> get mediaEvents;

  // ── Connection state ──────────────────────────────────────────────────

  bool get isConnecting;
  bool get isConnected;
  bool get isReconnecting;
  String? get errorMessage;

  /// Human-readable diagnostic string for debug logs.
  String get diagnosticState;

  // ── Media controls ────────────────────────────────────────────────────

  /// Connect to the media server using [credentials] (provider-specific).
  /// [videoEnabled] indicates whether to start the camera immediately.
  Future<void> connect({
    required Map<String, dynamic> credentials,
    required bool videoEnabled,
  });

  /// Disconnect from the media server and release all resources.
  Future<void> disconnect();

  /// Mute / unmute the local microphone.
  Future<void> setMuted(bool muted);

  /// Enable / disable the local camera.
  Future<void> setCameraEnabled(bool enabled);

  /// Switch between front and back cameras.
  Future<void> switchCamera();

  /// Route audio to speaker (true) or earpiece (false).
  Future<void> setSpeakerEnabled(bool enabled);

  // ── Video state (for UI) ──────────────────────────────────────────────

  /// Whether local video is currently publishing.
  bool get isLocalVideoActive;

  /// Whether a remote participant has joined and is publishing video.
  bool get isRemoteVideoActive;

  /// Whether there is at least one remote audio participant.
  bool get hasRemoteParticipant;

  /// Whether the local microphone is enabled (not muted).
  bool? get isLocalAudioEnabled;
}
