import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/dio_client.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';

class AuthViewModel extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _currentPhoneNumber = '';
  String _currentCountryCode = '1';
  String? _linkToken;
  Timer? _linkPollingTimer;
  int _linkCountdown = 300;
  bool _postStartupTasksStarted = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get currentPhoneNumber => _currentPhoneNumber;
  String? get linkToken => _linkToken;
  int get linkCountdown => _linkCountdown;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  String _normalizeCountryCode(String countryCode) {
    return countryCode.replaceAll(RegExp(r'\D'), '');
  }

  String _normalizeNationalPhone(String phoneNumber, String countryCode) {
    final countryDigits = _normalizeCountryCode(countryCode);
    var digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final raw = phoneNumber.trim();

    if (digits.startsWith('00$countryDigits')) {
      digits = digits.substring(countryDigits.length + 2);
    } else if (raw.startsWith('+') && digits.startsWith(countryDigits)) {
      digits = digits.substring(countryDigits.length);
    }

    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  Future<void> checkAuthStatus() async {
    debugPrint('[startup] auth check started');
    _isLoading = true;
    notifyListeners();
    await TokenStorage.init();
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated =
        (prefs.getBool('isLoggedIn') ?? false) &&
        ((TokenStorage.accessTokenSync?.isNotEmpty ?? false) ||
            (TokenStorage.refreshTokenSync?.isNotEmpty ?? false));
    ApiService.currentUserId = prefs.getString('user_id');
    if (!_isAuthenticated) {
      _socketService.disconnect();
    }
    _isLoading = false;
    debugPrint(
      '[startup] auth check completed authenticated=$_isAuthenticated',
    );
    notifyListeners();
  }

  Future<void> runPostStartupTasks() async {
    if (!_isAuthenticated || _postStartupTasksStarted) return;
    _postStartupTasksStarted = true;
    try {
      await _socketService.connect();
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
    }
    try {
      await NotificationService.getTokenAndSave();
    } catch (e) {
      debugPrint('FCM token save failed (non-fatal): $e');
    }
  }

  Future<bool> requestOtp(
    String phoneNumber, {
    String countryCode = '1',
  }) async {
    final normalizedCountryCode = _normalizeCountryCode(countryCode);
    final normalizedPhoneNumber = _normalizeNationalPhone(
      phoneNumber,
      normalizedCountryCode,
    );

    _currentPhoneNumber = normalizedPhoneNumber;
    _currentCountryCode = normalizedCountryCode;
    await _apiService.requestOtp(
      normalizedPhoneNumber,
      '+$normalizedCountryCode',
    );
    return true;
  }

  Future<bool> verifyOtp(String otp) async {
    final result = await _apiService.verifyOtp(
      _currentPhoneNumber,
      '+$_currentCountryCode',
      otp,
    );
    if (result.containsKey('access')) {
      final prefs = await SharedPreferences.getInstance();
      await TokenStorage.saveTokens(
        access: result['access'].toString(),
        refresh: result['refresh'].toString(),
      );
      if (result['user'] != null) {
        final uid = result['user']['id'].toString();
        ApiService.currentUserId = uid;
        await prefs.setString('user_id', uid);
        if (result['user']['phone_number'] != null) {
          await prefs.setString(
            'user_phone',
            result['user']['phone_number'].toString(),
          );
        }
        if (result['user']['name'] != null &&
            result['user']['name'].toString().isNotEmpty) {
          await prefs.setString('user_name', result['user']['name'].toString());
        }
        if (result['user']['about'] != null &&
            result['user']['about'].toString().isNotEmpty) {
          await prefs.setString(
            'user_about',
            result['user']['about'].toString(),
          );
        }
        if (result['user']['profile_picture'] != null &&
            result['user']['profile_picture'].toString().isNotEmpty) {
          await prefs.setString(
            'user_profile_picture',
            result['user']['profile_picture'].toString(),
          );
        }
      }
      if (result['user'] != null &&
          result['user']['name'] != null &&
          result['user']['name'].toString().isNotEmpty) {
        await prefs.setBool('isLoggedIn', true);
        _isAuthenticated = true;
        await _socketService.connect();
        await NotificationService.getTokenAndSave();
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> completeProfile(
    String name,
    String? imagePath, {
    String? about,
  }) async {
    final success = await _apiService.completeProfile(
      name,
      imagePath,
      about: about,
    );
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('user_name', name);
      if (about != null) {
        await prefs.setString('user_about', about);
      }
      _isAuthenticated = true;
      await _socketService.connect();
      await NotificationService.getTokenAndSave();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await TokenStorage.clearAll();
    ApiService.currentUserId = null;
    _linkToken = null;
    _linkPollingTimer?.cancel();
    _postStartupTasksStarted = false;
    _isAuthenticated = false;
    _socketService.disconnect();
    notifyListeners();
  }

  Future<void> startWebLinking() async {
    _linkPollingTimer?.cancel();
    _linkToken = await _apiService.generateLinkToken();
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
        if (status['is_active'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await TokenStorage.saveTokens(
            access: status['access'].toString(),
            refresh: status['refresh'].toString(),
          );
          if (status['user'] != null) {
            final uid = status['user']['id'].toString();
            ApiService.currentUserId = uid;
            await prefs.setString('user_id', uid);
            if (status['user']['about'] != null &&
                status['user']['about'].toString().isNotEmpty) {
              await prefs.setString(
                'user_about',
                status['user']['about'].toString(),
              );
            }
            await prefs.setBool('isLoggedIn', true);
            _isAuthenticated = true;
            _linkToken = null;
            timer.cancel();
            await _socketService.connect();
            notifyListeners();
          }
        }
      } catch (_) {
        retries += 1;
        if (retries >= 5) {
          timer.cancel();
        }
      }
    });
  }

  Future<bool> linkDevice(String token) async {
    return _apiService.activateLinkToken(token);
  }

  @override
  void dispose() {
    _linkPollingTimer?.cancel();
    super.dispose();
  }
}
