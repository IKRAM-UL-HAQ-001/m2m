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
  static const String _defaultServerIp = '192.168.1.69:8000';
  static const String _serverIpOverride = String.fromEnvironment('SERVER_IP');
  static const String _serverBaseUrlOverride = String.fromEnvironment(
    'SERVER_BASE_URL',
  );
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _authBaseUrlOverride = String.fromEnvironment(
    'AUTH_BASE_URL',
  );
  static const String _wsBaseUrlOverride = String.fromEnvironment(
    'WS_BASE_URL',
  );

  static String get serverIp =>
      _serverIpOverride.isNotEmpty ? _serverIpOverride : _defaultServerIp;

  static String get serverBaseUrl {
    if (_serverBaseUrlOverride.isNotEmpty) {
      return _stripTrailingSlashes(_serverBaseUrlOverride);
    }
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _stripPathSuffix(_apiBaseUrlOverride, '/api');
    }
    if (_authBaseUrlOverride.isNotEmpty) {
      return _stripPathSuffix(_authBaseUrlOverride, '/auth');
    }
    return 'http://$serverIp';
  }

  static String get apiBaseUrl => _apiBaseUrlOverride.isNotEmpty
      ? _stripTrailingSlashes(_apiBaseUrlOverride)
      : '$serverBaseUrl/api';

  static String get authBaseUrl => _authBaseUrlOverride.isNotEmpty
      ? _stripTrailingSlashes(_authBaseUrlOverride)
      : '$serverBaseUrl/auth';

  static String get wsBaseUrl => _wsBaseUrlOverride.isNotEmpty
      ? _wsBaseUrlOverride
      : _webSocketUrlFromServerBaseUrl(serverBaseUrl);

  static String _stripTrailingSlashes(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static String _stripPathSuffix(String value, String suffix) {
    final normalized = _stripTrailingSlashes(value);
    if (normalized.endsWith(suffix)) {
      return normalized.substring(0, normalized.length - suffix.length);
    }
    return normalized;
  }

  static String _webSocketUrlFromServerBaseUrl(String value) {
    final normalized = _stripTrailingSlashes(value);
    final wsBase = normalized.startsWith('https://')
        ? normalized.replaceFirst('https://', 'wss://')
        : normalized.startsWith('http://')
        ? normalized.replaceFirst('http://', 'ws://')
        : normalized;
    return '$wsBase/ws/chat/';
  }
}
