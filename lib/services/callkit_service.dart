import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';

/// Thin wrapper around `flutter_callkit_incoming` that owns the NATIVE
/// full-screen incoming-call experience on Android: it shows a system-level
/// call screen (over the lock screen, and over other apps when the "Display
/// over other apps" permission is granted), plays a single managed ringtone,
/// and works from a terminated app with no Flutter boot.
///
/// It is the SOLE ringtone owner for incoming calls on Android — the old
/// notification-channel ringtone and the in-app `IncomingCallScreen` ringtone
/// must NOT run alongside it, or the bell doubles again.
///
/// Gated to Android: iOS still uses the existing notification + Flutter
/// `IncomingCallScreen` flow because CallKit needs a VoIP (PushKit) push, which
/// the backend doesn't send yet.
class CallkitService {
  CallkitService._();

  /// CallKit/the package key calls by a UUID. We derive it deterministically
  /// from our integer call id so the background isolate, the foreground isolate
  /// and `end()` all address the same call without any shared storage.
  static String uuidForCall(String callId) {
    final digits = callId.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.padLeft(12, '0');
    return '00000000-0000-0000-0000-${tail.substring(tail.length - 12)}';
  }

  static bool get isSupported => Platform.isAndroid;

  static StreamSubscription<CallEvent?>? _eventSub;

  /// Subscribe to native accept/decline/end actions. Keeps the package's own
  /// event types contained here so the rest of the app deals in plain values.
  /// [onAccept] receives the original payload (`extra`) so the caller can
  /// rebuild the call session; [onDecline]/[onEnded] receive our call id.
  static void listen({
    required void Function(Map<String, dynamic> extra) onAccept,
    required void Function(String? callId) onDecline,
    void Function(String? callId)? onEnded,
  }) {
    if (!isSupported) return;
    _eventSub?.cancel();
    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          onAccept(extraFromEvent(event));
          break;
        case Event.actionCallDecline:
          onDecline(callIdFromEvent(event));
          break;
        case Event.actionCallTimeout:
        case Event.actionCallEnded:
          onEnded?.call(callIdFromEvent(event));
          break;
        default:
          break;
      }
    });
  }

  static void disposeListener() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  /// Recovery path for Android cold starts. If the native answer action wakes
  /// the app before Flutter's EventChannel is listening, the plugin still
  /// persists the accepted call in activeCalls(). Polling this lets us run the
  /// normal accept/join path instead of leaving only CallKit's "Hang up"
  /// notification on screen.
  static Future<Map<String, dynamic>?> acceptedActiveCallExtra() async {
    if (!isSupported) return null;
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is! List || activeCalls.isEmpty) return null;

      for (final item in activeCalls) {
        if (item is! Map) continue;
        final call = Map<String, dynamic>.from(item);
        if (call['isAccepted'] != true) continue;

        final extraRaw = call['extra'];
        final extra = extraRaw is Map
            ? Map<String, dynamic>.from(extraRaw)
            : <String, dynamic>{};
        final callId =
            extra['call_id']?.toString() ??
            callIdFromUuid(call['id']?.toString());
        if (callId == null || callId.isEmpty) continue;
        extra['call_id'] = callId;
        extra['caller_name'] ??= call['nameCaller']?.toString();
        extra['call_type'] ??= call['type'] == 1 ? 'video' : 'audio';
        return extra;
      }
    } catch (e) {
      debugPrint('CallkitService.acceptedActiveCallExtra failed: $e');
    }
    return null;
  }

  static String? callIdFromUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;
    final last = uuid.split('-').last;
    final parsed = int.tryParse(last);
    if (parsed == null || parsed <= 0) return null;
    return parsed.toString();
  }

  // In-memory de-dupe: the invite arrives over BOTH the WebSocket and FCM, so
  // show() can be called twice for one call in the same isolate. Showing the
  // same id twice would restart the ringtone.
  static final Set<String> _shownCallIds = <String>{};

  /// Present the native incoming-call UI for an FCM/WS payload. Safe to call
  /// more than once for the same call.
  static Future<void> showIncoming(Map<String, dynamic> data) async {
    if (!isSupported) return;
    final callId = data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;
    if (!_shownCallIds.add(callId)) return;

    final callerName =
        (data['caller_name']?.toString().trim().isNotEmpty ?? false)
        ? data['caller_name'].toString()
        : 'Incoming call';
    final isVideo = data['call_type']?.toString() == 'video';
    final avatarRaw = data['caller_profile_picture']?.toString();
    final avatar = (avatarRaw != null && avatarRaw.isNotEmpty)
        ? ApiService.mediaUrl(avatarRaw)
        : null;

    final params = CallKitParams(
      id: uuidForCall(callId),
      nameCaller: callerName,
      appName: 'M2M',
      avatar: avatar,
      handle: isVideo ? 'Incoming video call' : 'Incoming audio call',
      type: isVideo ? 1 : 0,
      // Auto-dismiss the ringing UI if nothing else ends it (e.g. the caller
      // cancels while we're terminated and no cancel push arrives).
      duration: 60000,
      textAccept: 'Answer',
      textDecline: 'Decline',
      // Carry the whole payload through so the accept handler can rebuild the
      // call session (call_id, caller_id, room_name, chime creds, …).
      extra: <String, dynamic>{...data, 'call_id': callId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowCallID: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#6B00D7',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming calls',
        // Show over the lock screen and (with the over-other-apps permission)
        // launch full-screen over whatever is on screen.
        isShowFullLockedScreen: true,
        isImportant: true,
        isBot: false,
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('CallkitService.showIncoming failed: $e');
      _shownCallIds.remove(callId);
    }
  }

  /// Dismiss the native UI + stop the ringtone for one call.
  static Future<void> end(String? callId) async {
    if (!isSupported || callId == null || callId.isEmpty) return;
    _shownCallIds.remove(callId);
    try {
      await FlutterCallkitIncoming.endCall(uuidForCall(callId));
    } catch (e) {
      debugPrint('CallkitService.end failed: $e');
    }
  }

  static Future<void> endAll() async {
    if (!isSupported) return;
    _shownCallIds.clear();
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('CallkitService.endAll failed: $e');
    }
  }

  /// The original payload we stashed in `extra` when showing the call.
  static Map<String, dynamic> extraFromEvent(CallEvent event) {
    final body = event.body;
    if (body is Map && body['extra'] is Map) {
      return Map<String, dynamic>.from(body['extra'] as Map);
    }
    return <String, dynamic>{};
  }

  static String? callIdFromEvent(CallEvent event) {
    final extra = extraFromEvent(event);
    final id = extra['call_id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// Ask for the permissions the native full-screen experience needs:
  /// full-screen-intent (Android 14+) and "Display over other apps"
  /// (SYSTEM_ALERT_WINDOW), the latter being what lets the call screen appear
  /// over other apps while the phone is unlocked. Best-effort and idempotent.
  static Future<void> ensurePermissions() async {
    if (!isSupported) return;
    try {
      final canFullScreen =
          await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (canFullScreen == false) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      debugPrint('CallkitService full-screen permission check failed: $e');
    }
    // "Display over other apps" — what lets the native call screen launch over
    // whatever is on screen while the phone is unlocked. Requesting it sends the
    // user to a system settings toggle; only do so when not already granted.
    try {
      if (!await Permission.systemAlertWindow.isGranted) {
        await Permission.systemAlertWindow.request();
      }
    } catch (e) {
      debugPrint('CallkitService overlay permission request failed: $e');
    }
  }
}
