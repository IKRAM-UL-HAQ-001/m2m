import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';

class AuthViewModel extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _currentPhoneNumber = '';

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get currentPhoneNumber => _currentPhoneNumber;
  String? _linkToken;
  String? get linkToken => _linkToken;

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    // Simulate basic splash screen loading delay
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isLoggedIn') ?? false;
    ApiService.currentUserId = prefs.getString('user_id');

    if (_isAuthenticated) {
      await _socketService.connect();
      await NotificationService.getTokenAndSave();
    } else {
      _socketService.disconnect();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> requestOtp(String phoneNumber, {String countryCode = '1'}) async {
    _currentPhoneNumber = phoneNumber;
    return await _apiService.requestOtp(phoneNumber, "+$countryCode");
  }

  Future<bool> verifyOtp(String otp) async {
    final result = await _apiService.verifyOtp(_currentPhoneNumber, otp);
    if (result != null && result.containsKey('access')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', result['access']);
      await prefs.setString('refresh_token', result['refresh']);
      
      // Save userId
      if (result['user'] != null) {
        final uid = result['user']['id'].toString();
        ApiService.currentUserId = uid;
        await prefs.setString('user_id', uid);
      }
      
      // If user already has a name, they might be returning
      if (result['user'] != null && result['user']['name'] != null && result['user']['name'].toString().isNotEmpty) {
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

  Future<bool> completeProfile(String name, String? imagePath) async {
    final success = await _apiService.completeProfile(name, imagePath);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      _isAuthenticated = true;
      
      await _socketService.connect();
      await NotificationService.getTokenAndSave();
      
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.currentUserId = null;
    _linkToken = null;
    _isAuthenticated = false;
    _socketService.disconnect();
    notifyListeners();
  }

  Future<void> startWebLinking() async {
    _linkToken = await _apiService.generateLinkToken();
    notifyListeners();
    if (_linkToken != null) {
      _pollForLinking();
    }
  }

  void _pollForLinking() async {
    while (_linkToken != null && !_isAuthenticated) {
      await Future.delayed(const Duration(seconds: 3));
      final status = await _apiService.checkLinkStatus(_linkToken!);
      if (status != null && status['is_active'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', status['access']);
        await prefs.setString('refresh_token', status['refresh']);
        
        if (status['user'] != null) {
          final uid = status['user']['id'].toString();
          ApiService.currentUserId = uid;
          await prefs.setString('user_id', uid);
          await prefs.setBool('isLoggedIn', true);
          _isAuthenticated = true;
          _linkToken = null;
          await _socketService.connect();
          notifyListeners();
          break;
        }
      }
    }
  }

  Future<bool> linkDevice(String token) async {
    return await _apiService.activateLinkToken(token);
  }
}
