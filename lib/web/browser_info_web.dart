// This file is only reachable via the `dart.library.html` conditional import
// in browser_info.dart, so it never compiles into the mobile app.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// WhatsApp-style device label from the browser's userAgent,
/// e.g. "Chrome on Linux", "Safari on macOS", "Edge on Windows".
String describeThisDevice() {
  final ua = html.window.navigator.userAgent;

  final String browser;
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('OPR/') || ua.contains('Opera')) {
    browser = 'Opera';
  } else if (ua.contains('Chrome/')) {
    browser = 'Chrome';
  } else if (ua.contains('Firefox/')) {
    browser = 'Firefox';
  } else if (ua.contains('Safari/')) {
    browser = 'Safari';
  } else {
    browser = 'Browser';
  }

  final String os;
  if (ua.contains('Windows')) {
    os = 'Windows';
  } else if (ua.contains('Android')) {
    os = 'Android';
  } else if (ua.contains('iPhone') || ua.contains('iPad')) {
    os = 'iOS';
  } else if (ua.contains('Mac OS')) {
    os = 'macOS';
  } else if (ua.contains('Linux')) {
    os = 'Linux';
  } else {
    os = 'Unknown OS';
  }

  return '$browser on $os';
}
