import 'package:flutter/material.dart';

class AppColors {
  static const primaryColor = Color(0xFF9B10A3);
  static const unselectedColor = Color(0xFFB238B8);
  static const floatingButtonColor = Color(0xFFD500F9);
  static const outgoingMessageColor = Color(0xFFF3E5F5);
  static const chatBackgroundColor = Color(0xFFEEE5EE);
  static const scaffoldBackgroundColor = Colors.white;
}

class AppConstants {
  static const String _configuredBaseHost = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static final String baseHost = _configuredBaseHost.replaceFirst(
    RegExp(r'/+$'),
    '',
  );
  static final String apiBaseUrl = '$baseHost/api';
  static final String authBaseUrl = '$baseHost/auth';
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8000/ws/chat/',
  );
}
