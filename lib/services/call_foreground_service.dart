import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CallForegroundService {
  static const MethodChannel _channel = MethodChannel(
    'com.danish.m2m/call_service',
  );

  static bool _running = false;

  static Future<void> start() async {
    if (!Platform.isAndroid || _running) return;
    final microphone = await Permission.microphone.status;
    if (!microphone.isGranted) {
      debugPrint(
        'Call foreground service start skipped: microphone permission not granted',
      );
      return;
    }
    var notifications = await Permission.notification.status;
    if (notifications.isDenied) {
      notifications = await Permission.notification.request();
    }
    if (notifications.isDenied || notifications.isPermanentlyDenied) {
      debugPrint(
        'Call foreground notification permission is denied; Android may hide '
        'the ongoing call notification on Android 13+',
      );
    }
    try {
      await _channel.invokeMethod<void>('startCallForegroundService');
      _running = true;
    } catch (error) {
      debugPrint('Call foreground service start failed: $error');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod<void>('stopCallForegroundService');
    } catch (error) {
      debugPrint('Call foreground service stop failed: $error');
    } finally {
      _running = false;
    }
  }
}
