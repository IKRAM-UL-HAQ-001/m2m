import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/dio_client.dart';
import '../services/websocket_service.dart';
import 'browser_info.dart';

/// Web-only auth. Unlike the mobile [AuthViewModel] this has no local database,
/// media cache, push tokens or dart:io dependencies  the web client is
/// online-only and authenticates by linking to a phone via a QR token.
class WebAuthViewModel extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _linkToken;
  Timer? _linkPollingTimer;
  int _linkCountdown = 300;
  bool _socketStarted = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get linkToken => _linkToken;
  int get linkCountdown => _linkCountdown;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    await TokenStorage.init();
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated =
        (prefs.getBool('isLoggedIn') ?? false) &&
        ((TokenStorage.accessTokenSync?.isNotEmpty ?? false) ||
            (TokenStorage.refreshTokenSync?.isNotEmpty ?? false));
    ApiService.currentUserId = prefs.getString('user_id');
    _isLoading = false;
    notifyListeners();
    if (_isAuthenticated) {
      unawaited(_startSocket());
    }
  }

  Future<void> _startSocket() async {
    if (_socketStarted) return;
    _socketStarted = true;
    try {
      await _socketService.connect();
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
    }
  }

  Future<void> startWebLinking() async {
    _linkPollingTimer?.cancel();
    try {
      _linkToken = await _apiService.generateLinkToken(
        deviceName: describeThisDevice(),
      );
    } catch (e) {
      debugPrint('generateLinkToken failed: $e');
      _linkToken = null;
      notifyListeners();
      // Back off before retrying: an immediate 2s retry loop hammers the
      // server and trips the link-token rate limit (429s make it worse).
      _linkPollingTimer = Timer(const Duration(seconds: 20), startWebLinking);
      return;
    }
    _linkCountdown = 300;
    notifyListeners();
    _startBoundedLinkPolling();
  }

  void _startBoundedLinkPolling() {
    int retries = 0;
    _linkPollingTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      _linkCountdown -= 2;
      if (_linkCountdown <= 0 || _linkToken == null || _isAuthenticated) {
        timer.cancel();
        if (!_isAuthenticated) {
          await startWebLinking();
        }
        return;
      }
      notifyListeners();

      try {
        final status = await _apiService.checkLinkStatus(_linkToken!);
        retries = 0;
        if (status['is_active'] == true && status['access'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await TokenStorage.saveTokens(
            access: status['access'].toString(),
            refresh: status['refresh'].toString(),
          );
          if (status['user'] != null) {
            final user = Map<String, dynamic>.from(status['user'] as Map);
            final uid = user['id'].toString();
            ApiService.currentUserId = uid;
            await prefs.setString('user_id', uid);
            final phone = user['phone_number']?.toString() ?? '';
            final name = user['name']?.toString() ?? '';
            final about = user['about']?.toString() ?? '';
            final picture = user['profile_picture']?.toString() ?? '';
            if (phone.isNotEmpty) await prefs.setString('user_phone', phone);
            if (name.isNotEmpty) await prefs.setString('user_name', name);
            if (about.isNotEmpty) await prefs.setString('user_about', about);
            if (picture.isNotEmpty) {
              await prefs.setString('user_profile_picture', picture);
            }
          }
          await prefs.setBool('isLoggedIn', true);
          // Remember which link token this browser session came from so
          // logout can deactivate its record on the server (and it disappears
          // from the phone's Linked devices list).
          await prefs.setString('web_link_token', _linkToken!);
          _isAuthenticated = true;
          _linkToken = null;
          timer.cancel();
          await _startSocket();
          notifyListeners();
        }
      } catch (_) {
        retries += 1;
        if (retries >= 5) timer.cancel();
      }
    });
  }

  Future<void> logout() async {
    _linkPollingTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    // Deactivate this browser's session record server-side while our JWT is
    // still valid, so the phone's Linked devices list stays accurate. Best
    // effort  a dead server shouldn't block local logout.
    final linkToken = prefs.getString('web_link_token');
    if (linkToken != null && linkToken.isNotEmpty) {
      try {
        await _apiService.unlinkDevice(token: linkToken);
      } catch (e) {
        debugPrint('unlinkDevice on logout failed: $e');
      }
      await prefs.remove('web_link_token');
    }
    await TokenStorage.clearAll();
    await DioClient().clearCache();
    await prefs.setBool('isLoggedIn', false);
    ApiService.currentUserId = null;
    _linkToken = null;
    _socketStarted = false;
    _isAuthenticated = false;
    _socketService.disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _linkPollingTimer?.cancel();
    super.dispose();
  }
}
