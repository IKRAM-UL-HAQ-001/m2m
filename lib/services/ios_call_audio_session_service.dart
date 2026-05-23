import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IosCallAudioSessionEvent {
  final String type;
  final Map<String, dynamic> data;

  const IosCallAudioSessionEvent(this.type, this.data);
}

class IosCallAudioSessionService {
  static const MethodChannel _channel = MethodChannel(
    'com.danish.m2m/ios_audio_session',
  );
  static final StreamController<IosCallAudioSessionEvent> _events =
      StreamController<IosCallAudioSessionEvent>.broadcast();
  static bool _handlerAttached = false;

  static Stream<IosCallAudioSessionEvent> get events {
    _ensureHandlerAttached();
    return _events.stream;
  }

  static Future<void> configureForCall({
    required bool isVideo,
    required bool defaultToSpeaker,
  }) async {
    if (!Platform.isIOS) return;
    _ensureHandlerAttached();
    try {
      await _channel.invokeMethod<void>('configureForCall', {
        'isVideo': isVideo,
        'defaultToSpeaker': defaultToSpeaker,
      });
      debugPrint('iOS audio session configured');
    } catch (error) {
      debugPrint('iOS audio session configure failed: $error');
    }
  }

  static Future<void> reactivateForCall() async {
    if (!Platform.isIOS) return;
    _ensureHandlerAttached();
    try {
      await _channel.invokeMethod<void>('reactivateForCall');
      debugPrint('iOS audio session activated');
    } catch (error) {
      debugPrint('iOS audio session reactivate failed: $error');
    }
  }

  static Future<void> deactivateAfterCall() async {
    if (!Platform.isIOS) return;
    _ensureHandlerAttached();
    try {
      await _channel.invokeMethod<void>('deactivateAfterCall');
      debugPrint('iOS audio session deactivated');
    } catch (error) {
      debugPrint('iOS audio session deactivate failed: $error');
    }
  }

  static void _ensureHandlerAttached() {
    if (_handlerAttached || !Platform.isIOS) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      final data = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      debugPrint('iOS audio session event=${call.method}');
      _events.add(IosCallAudioSessionEvent(call.method, data));
    });
  }
}
