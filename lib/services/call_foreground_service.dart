import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CallForegroundService {
  static const MethodChannel _channel = MethodChannel(
    'com.danish.m2m/call_service',
  );

  // _running = the service's actual state; _desiredRunning = the latest target.
  // start()/stop() are fired with unawaited() on rapid state changes
  // (connecting -> active -> failed), so they MUST be serialized  otherwise an
  // in-flight start() can finish *after* a stop() that already bailed on the
  // flag, leaving the foreground service (and its notification) leaked. Every
  // call enqueues onto _operation and a single reconcile loop converges actual
  // to desired.
  static bool _running = false;
  static bool _desiredRunning = false;
  static Future<void> _operation = Future<void>.value();

  static Future<void> start() => _enqueue(true);

  static Future<void> stop() => _enqueue(false);

  static Future<void> _enqueue(bool desired) {
    if (!Platform.isAndroid) return Future<void>.value();
    _desiredRunning = desired;
    _operation = _operation.then((_) => _reconcile());
    return _operation;
  }

  static Future<void> _reconcile() async {
    // Collapse no-op toggles (e.g. start then immediate stop already converged).
    if (_desiredRunning == _running) return;

    if (_desiredRunning) {
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
      // The call may have ended while we awaited permissions  don't start a
      // service nobody wants anymore.
      if (!_desiredRunning) return;
      try {
        await _channel.invokeMethod<void>('startCallForegroundService');
        _running = true;
      } catch (error) {
        debugPrint('Call foreground service start failed: $error');
      }
    } else {
      try {
        await _channel.invokeMethod<void>('stopCallForegroundService');
      } catch (error) {
        debugPrint('Call foreground service stop failed: $error');
      } finally {
        _running = false;
      }
    }
  }
}
