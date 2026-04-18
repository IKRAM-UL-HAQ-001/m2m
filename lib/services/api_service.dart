import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../utils/constants.dart';

class ApiService {
  static String? currentUserId;
  static const String baseUrl = AppConstants.apiBaseUrl; 
  static const String authUrl = AppConstants.authBaseUrl; 

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return headers;
  }

  Future<bool> requestOtp(String phoneNumber, String countryCode) async {
    try {
      final url = '$authUrl/request-otp/';
      debugPrint('=== Requesting OTP ===');
      debugPrint('URL: $url');
      debugPrint('Phone: $phoneNumber, Country: $countryCode');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone_number': phoneNumber,
          'country_code': countryCode,
        }),
      );
      
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 400;
    } catch (e) {
      debugPrint('!!! Error requesting OTP: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone_number': phoneNumber,
          'otp': otp,
        }),
      );
      debugPrint('Verify OTP status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return null;
    }
  }

  Future<String?> generateLinkToken() async {
    try {
      final response = await http.get(Uri.parse('$authUrl/generate-link-token/'));
      if (response.statusCode == 200) {
        return json.decode(response.body)['token'];
      }
      return null;
    } catch (e) {
      debugPrint('Error generating link token: $e');
      return null;
    }
  }

  Future<bool> activateLinkToken(String token) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$authUrl/activate-link-token/'),
        headers: headers,
        body: json.encode({'token': token}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error activating link token: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkLinkStatus(String token) async {
    try {
      final response = await http.get(Uri.parse('$authUrl/check-link-status/$token/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking link status: $e');
      return null;
    }
  }


  Future<bool> completeProfile(String name, String? imagePath) async {
    try {
      final url = Uri.parse('$authUrl/complete-profile/');
      final headers = await _getHeaders();
      
      // If we have an image, we should use MultiPart request
      // For now, we'll try a simple JSON if no image, or just name
      if (imagePath == null) {
        final response = await http.post(
          url,
          headers: headers,
          body: json.encode({'name': name}),
        );
        return response.statusCode == 200;
      } else {
        var request = http.MultipartRequest('POST', url);
        request.headers.addAll(headers);
        request.fields['name'] = name;
        request.files.add(await http.MultipartFile.fromPath('profile_picture', imagePath));
        
        var response = await request.send();
        return response.statusCode == 200;
      }
    } catch (e) {
      debugPrint('Error completing profile: $e');
      return false;
    }
  }

  Future<List<Chat>> getChats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats/'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Chat.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chats');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  Future<List<Message>> getMessages(String chatId) async {
    if (chatId.startsWith('new_')) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats/$chatId/messages/'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }
  Future<Message?> sendMessage(String receiverId, String text, {File? file, String? type}) async {
    try {
      final url = Uri.parse('$baseUrl/send/');
      var request = http.MultipartRequest('POST', url);
      
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      request.fields['receiver_id'] = receiverId;
      request.fields['encrypted_text'] = text;
      request.fields['client_time'] = DateTime.now().toIso8601String();
      
      if (type != null) {
        request.fields['message_type'] = type;
      } else {
        request.fields['message_type'] = file != null ? 'image' : 'text';
      }

      if (file != null) {
        String contentType = 'image';
        String subtype = 'jpeg';
        
        if (file.path.endsWith('.pdf')) {
          contentType = 'application';
          subtype = 'pdf';
          if (type == null) request.fields['message_type'] = 'document';
        } else if (file.path.endsWith('.m4a') || file.path.endsWith('.mp3')) {
          contentType = 'audio';
          subtype = 'mpeg';
          if (type == null) request.fields['message_type'] = 'audio';
        }

        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType(contentType, subtype),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Message.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final url = Uri.parse('$authUrl/list-users/');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        if (response.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('access_token');
          debugPrint('Token cleared due to 401');
        }
        debugPrint('Error fetching users: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching users: $e');
      return [];
    }
  }
  
  static Future<void> updateFcmToken(String token) async {
    try {
      final api = ApiService();
      final headers = await api._getHeaders();
      await http.post(
        Uri.parse('$authUrl/complete-profile/'),
        headers: headers,
        body: json.encode({'fcm_token': token}),
      );
      debugPrint('FCM Token updated successfully');
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$authUrl/delete-account/'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Clear all user data locally
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }
}

