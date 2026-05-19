import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart';
import '../models/contact_user.dart';
import '../models/message.dart';
import '../models/shared_media.dart';
import '../models/user_status.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ContactDiscoveryResult {
  final List<Map<String, dynamic>> onAppContacts;
  final List<Map<String, dynamic>> offAppContacts;

  const ContactDiscoveryResult({
    required this.onAppContacts,
    required this.offAppContacts,
  });
}

class ApiService {
  static String? currentUserId;
  static final String baseUrl = AppConstants.apiBaseUrl;
  static final String authUrl = AppConstants.authBaseUrl;
  static final Random _uuidRandom = Random.secure();
  static const String _lastContactsSyncKey = 'last_contacts_sync_at';
  static Future<ContactDiscoveryResult>? _contactsSyncInFlight;

  static bool _isRefreshing = false;

  static String createClientUuid() {
    final bytes = List<int>.generate(16, (_) => _uuidRandom.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }

  Future<Map<String, String>> _getHeaders({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$authUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await prefs.setString('access_token', data['access']);
        if (data['refresh'] != null) {
          await prefs.setString('refresh_token', data['refresh']);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Never _throwApiError(http.Response response) {
    String message = 'Request failed';
    try {
      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        message =
            (body['error'] ?? body['detail'] ?? body['message'] ?? message)
                .toString();
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }
    throw ApiException(response.statusCode, message);
  }

  Never _throwNetworkError(Object error, Uri uri) {
    throw ApiException(0, 'Network error for $uri: $error');
  }

  Future<Map<String, dynamic>> _decodeJsonResponse(
    http.Response response, {
    Uri? retryUri,
    String method = 'GET',
    String? retryBody,
  }) async {
    if (response.statusCode == 401 && retryUri != null) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        final retryResponse = method == 'POST'
            ? await http.post(retryUri, headers: newHeaders, body: retryBody)
            : await http.get(retryUri, headers: newHeaders);
        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          return Map<String, dynamic>.from(json.decode(retryResponse.body));
        }
        _throwApiError(retryResponse);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return Map<String, dynamic>.from(json.decode(response.body));
  }

  Future<bool> requestOtp(String phoneNumber, String countryCode) async {
    final uri = Uri.parse('$authUrl/request-otp/');
    debugPrint('Request OTP URL: $uri');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone_number': phoneNumber,
          'country_code': countryCode,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwApiError(response);
      }
      return true;
    } on SocketException catch (error) {
      _throwNetworkError(error, uri);
    } on http.ClientException catch (error) {
      _throwNetworkError(error, uri);
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phoneNumber,
    String countryCode,
    String otp,
  ) async {
    final uri = Uri.parse('$authUrl/verify-otp/');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone_number': phoneNumber,
          'country_code': countryCode,
          'otp': otp,
        }),
      );
      return _decodeJsonResponse(response);
    } on SocketException catch (error) {
      _throwNetworkError(error, uri);
    } on http.ClientException catch (error) {
      _throwNetworkError(error, uri);
    }
  }

  Future<String> generateLinkToken() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$authUrl/generate-link-token/'),
      headers: headers,
    );
    final data = await _decodeJsonResponse(response);
    return data['token'].toString();
  }

  Future<bool> activateLinkToken(String token) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/activate-link-token/'),
      headers: headers,
      body: json.encode({'token': token}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return true;
  }

  Future<Map<String, dynamic>> checkLinkStatus(String token) async {
    final response = await http.get(
      Uri.parse('$authUrl/check-link-status/$token/'),
    );
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> fetchWebSocketTicket() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/ws-ticket/'),
      headers: headers,
      body: json.encode({}),
    );
    return _decodeJsonResponse(response);
  }

  Future<void> sendPresenceHeartbeat() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/presence/heartbeat/'),
      headers: headers,
      body: json.encode({}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<Map<String, dynamic>> getPresence(String userId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$authUrl/presence/$userId/'),
      headers: headers,
    );
    return _decodeJsonResponse(response);
  }

  static String normalizeContactPhone(
    String? phone, {
    String defaultCountryCode = '+92',
  }) {
    final cleaned = (phone ?? '').replaceAll(
      RegExp(r'[\s\-\(\)\[\]\{\}\.]'),
      '',
    );
    if (cleaned.isEmpty) return '';

    final countryCode = defaultCountryCode.startsWith('+')
        ? defaultCountryCode
        : '+$defaultCountryCode';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) return '$countryCode${cleaned.substring(1)}';
    if (cleaned.startsWith('92')) return '+$cleaned';
    return cleaned;
  }

  Future<List<Map<String, dynamic>>> readDeviceContacts() async {
    var permission = await Permission.contacts.status;
    if (!permission.isGranted) {
      permission = await Permission.contacts.request();
    }

    if (!permission.isGranted) {
      throw ApiException(
        403,
        'Contacts permission is required to sync contacts.',
      );
    }

    final flutterContactsGranted = await FlutterContacts.requestPermission(
      readonly: true,
    );
    if (!flutterContactsGranted) {
      throw ApiException(
        403,
        'Contacts permission is required to sync contacts.',
      );
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final byPhone = <String, Map<String, dynamic>>{};
    for (final contact in contacts) {
      final displayName = contact.displayName.trim();
      for (final phone in contact.phones) {
        final normalized = normalizeContactPhone(phone.number);
        if (normalized.isEmpty) continue;
        byPhone.putIfAbsent(normalized, () {
          return {
            'phone_number': normalized,
            'phone': normalized,
            'name': displayName,
            'contact_name': displayName,
          };
        });
      }
    }
    return byPhone.values.toList();
  }

  Future<ContactDiscoveryResult> syncContacts([
    List<Map<String, dynamic>>? contacts,
  ]) async {
    if (contacts == null && _contactsSyncInFlight != null) {
      return _contactsSyncInFlight!;
    }

    final syncFuture = _syncContactsInternal(contacts);
    if (contacts == null) {
      _contactsSyncInFlight = syncFuture;
      syncFuture.whenComplete(() => _contactsSyncInFlight = null);
    }
    return syncFuture;
  }

  Future<ContactDiscoveryResult> _syncContactsInternal(
    List<Map<String, dynamic>>? contacts,
  ) async {
    final normalizedContacts = contacts ?? await readDeviceContacts();
    final uniqueContacts = <String, Map<String, dynamic>>{};
    for (final contact in normalizedContacts) {
      final phone = normalizeContactPhone(
        (contact['phone_number'] ?? contact['phone'] ?? '').toString(),
      );
      if (phone.isEmpty) continue;
      final name = (contact['name'] ?? contact['contact_name'] ?? '')
          .toString();
      uniqueContacts.putIfAbsent(phone, () {
        return {
          'phone_number': phone,
          'phone': phone,
          'name': name,
          'contact_name': name,
        };
      });
    }
    final contactList = uniqueContacts.values.toList();

    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/sync-contacts/'),
      headers: headers,
      body: json.encode({'contacts': contactList}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    final onAppContacts = await fetchUsers(contacts: contactList);
    final onAppPhones = onAppContacts
        .map((contact) => normalizeContactPhone(contact['phone']?.toString()))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    final prefs = await SharedPreferences.getInstance();
    final currentUserPhone = normalizeContactPhone(
      prefs.getString('user_phone'),
    );
    final offAppContacts = contactList
        .where((contact) {
          final phone = normalizeContactPhone(contact['phone']?.toString());
          return phone.isNotEmpty &&
              phone != currentUserPhone &&
              !onAppPhones.contains(phone);
        })
        .map(
          (contact) => {
            'phone': normalizeContactPhone(contact['phone']?.toString()),
            'contact_name': (contact['contact_name'] ?? contact['name'] ?? '')
                .toString(),
            'has_account': false,
          },
        )
        .toList();

    await prefs.setInt(
      _lastContactsSyncKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return ContactDiscoveryResult(
      onAppContacts: onAppContacts,
      offAppContacts: offAppContacts,
    );
  }

  Future<bool> shouldSyncContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastContactsSyncKey);
    if (lastSync == null) return true;
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    return DateTime.now().difference(lastSyncTime) > const Duration(hours: 24);
  }

  Future<bool> completeProfile(
    String name,
    String? imagePath, {
    String? about,
  }) async {
    final url = Uri.parse('$authUrl/complete-profile/');
    final headers = await _getHeaders();
    if (imagePath == null) {
      final body = {'name': name};
      if (about != null) body['about'] = about;
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwApiError(response);
      }
      return true;
    }

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _getHeaders(json: false));
    request.fields['name'] = name;
    if (about != null) request.fields['about'] = about;
    request.files.add(
      await http.MultipartFile.fromPath('profile_picture', imagePath),
    );
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return true;
  }

  Future<List<Chat>> getChats({int offset = 0, int limit = 20}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/chats/?offset=$offset&limit=$limit');
    final response = await http.get(uri, headers: headers);
    final data = await _decodeJsonResponse(response);
    final results = List<dynamic>.from(data['results'] ?? const []);
    return results
        .map((item) => Chat.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Message>> getMessages(String chatId, {String? cursor}) async {
    if (chatId.startsWith('new_')) return [];
    final headers = await _getHeaders();
    final suffix = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final response = await http.get(
      Uri.parse('$baseUrl/chats/$chatId/messages/$suffix'),
      headers: headers,
    );
    final data = await _decodeJsonResponse(response);
    final results = List<dynamic>.from(data['results'] ?? const []);
    return results
        .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> getStatusPrivacy() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/status/privacy/'),
      headers: headers,
    );
    return _decodeJsonResponse(response);
  }

  Future<void> updateStatusPrivacy({
    required String privacy,
    required List<String> exceptUserIds,
    required List<String> onlyUserIds,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/status/privacy/'),
      headers: headers,
      body: json.encode({
        'privacy': privacy,
        'except_user_ids': exceptUserIds,
        'only_user_ids': onlyUserIds,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<List<ContactUser>> getAppContacts() async {
    final result = await syncContacts();
    return result.onAppContacts
        .where((contact) => contact['id'] != null || contact['user_id'] != null)
        .map((contact) => ContactUser.fromJson(contact))
        .toList();
  }

  Future<Message> sendMessage(
    String receiverId,
    String text, {
    required String clientUuid,
    File? file,
    String? type,
    String? replyTo,
    double? duration,
  }) async {
    final url = Uri.parse('$baseUrl/send/');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _getHeaders(json: false));
    request.fields['receiver_id'] = receiverId;
    request.fields['encrypted_text'] = text;
    request.fields['client_uuid'] = clientUuid;
    if (replyTo != null) {
      request.fields['reply_to'] = replyTo;
    }
    if (duration != null) {
      request.fields['duration'] = duration.toStringAsFixed(1);
    }
    // message_type is set below based on file extension when file is present
    if (file == null) {
      request.fields['message_type'] = type ?? 'text';
    }

    if (file != null) {
      final ext = file.path.split('.').last.toLowerCase();
      String contentType;
      String subtype;
      String detectedType;

      if (['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'].contains(ext)) {
        contentType = 'video';
        subtype = ext == 'mov'
            ? 'quicktime'
            : (ext == 'mkv' ? 'x-matroska' : 'mp4');
        detectedType = 'video';
      } else if (['mp3'].contains(ext)) {
        contentType = 'audio';
        subtype = 'mpeg';
        detectedType = 'audio';
      } else if (['m4a', 'aac'].contains(ext)) {
        contentType = 'audio';
        subtype = 'mp4';
        detectedType = 'audio';
      } else if (['ogg', 'oga'].contains(ext)) {
        contentType = 'audio';
        subtype = 'ogg';
        detectedType = 'audio';
      } else if (['wav'].contains(ext)) {
        contentType = 'audio';
        subtype = 'wav';
        detectedType = 'audio';
      } else if (['pdf'].contains(ext)) {
        contentType = 'application';
        subtype = 'pdf';
        detectedType = 'document';
      } else if (['doc', 'docx'].contains(ext)) {
        contentType = 'application';
        subtype = 'msword';
        detectedType = 'document';
      } else if (['xls', 'xlsx'].contains(ext)) {
        contentType = 'application';
        subtype = 'vnd.ms-excel';
        detectedType = 'document';
      } else if (['txt'].contains(ext)) {
        contentType = 'text';
        subtype = 'plain';
        detectedType = 'document';
      } else if (['png'].contains(ext)) {
        contentType = 'image';
        subtype = 'png';
        detectedType = 'image';
      } else if (['gif'].contains(ext)) {
        contentType = 'image';
        subtype = 'gif';
        detectedType = 'image';
      } else if (['webp'].contains(ext)) {
        contentType = 'image';
        subtype = 'webp';
        detectedType = 'image';
      } else {
        // Default: treat as image/jpeg for jpg/jpeg and anything else
        contentType = 'image';
        subtype = 'jpeg';
        detectedType = 'image';
      }

      // Explicit type parameter overrides detection
      request.fields['message_type'] = type ?? detectedType;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType(contentType, subtype),
        ),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return Message.fromJson(
      Map<String, dynamic>.from(json.decode(response.body)),
    );
  }

  Future<List<Map<String, dynamic>>> fetchUsers({
    List<Map<String, dynamic>>? contacts,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$authUrl/list-users/');
    final response = contacts == null
        ? await http.get(uri, headers: headers)
        : await http.post(
            uri,
            headers: headers,
            body: json.encode({'contacts': contacts}),
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  Future<void> inviteContact(String phone, String contactName) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/invite-contact/'),
      headers: headers,
      body: json.encode({'phone': phone, 'contact_name': contactName}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> updateFcmToken(String token) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/update-fcm-token/'),
      headers: headers,
      body: json.encode({'fcm_token': token}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<bool> deleteAccount(String otp) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$authUrl/delete-account/'),
      headers: headers,
      body: json.encode({'otp': otp}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return true;
  }

  Future<void> sendTyping(String chatId, bool isTyping) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/typing/'),
      headers: headers,
      body: json.encode({'chat_id': int.parse(chatId), 'is_typing': isTyping}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> markMessagesDelivered(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/messages/delivered/'),
      headers: headers,
      body: json.encode({'message_ids': messageIds}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> markChatRead(String chatId) async {
    if (chatId.startsWith('new_')) return;
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/messages/read/'),
      headers: headers,
      body: json.encode({'chat_id': int.parse(chatId)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> deleteMessage(String messageId, String deleteType) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/delete-message/'),
      headers: headers,
      body: json.encode({
        'message_id': int.parse(messageId),
        'delete_type': deleteType,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/edit-message/'),
      headers: headers,
      body: json.encode({
        'message_id': int.parse(messageId),
        'encrypted_text': newText,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/react/'),
      headers: headers,
      body: json.encode({'message_id': int.parse(messageId), 'emoji': emoji}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<Message> forwardMessage({
    required String originalMessageId,
    required String toChatId,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/forward/'),
      headers: headers,
      body: json.encode({
        'message_id': int.parse(originalMessageId),
        'chat_id': int.parse(toChatId),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return Message.fromJson(
      Map<String, dynamic>.from(json.decode(response.body)),
    );
  }

  Future<List<StatusGroup>> fetchStatusFeed() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/status/feed/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return List<dynamic>.from(json.decode(response.body))
        .map((item) => StatusGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<UserStatus>> fetchMyStatuses() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/status/my/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return List<dynamic>.from(json.decode(response.body))
        .map((item) => UserStatus.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<UserStatus> createTextStatus(
    String text, {
    String backgroundColor = '#6B00D7',
    int fontSize = 28,
    String privacy = 'all_contacts',
    List<String> userIds = const [],
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/status/create/'),
      headers: headers,
      body: json.encode({
        'status_type': 'text',
        'text_content': text,
        'background_color': backgroundColor,
        'font_size': fontSize,
        'privacy': privacy,
        'user_ids': userIds.map(int.parse).toList(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return UserStatus.fromJson(
      Map<String, dynamic>.from(json.decode(response.body)),
    );
  }

  Future<UserStatus> createMediaStatus(
    File file,
    String statusType, {
    String privacy = 'all_contacts',
    List<String> userIds = const [],
  }) async {
    final url = Uri.parse('$baseUrl/status/create/');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _getHeaders(json: false));
    request.fields['status_type'] = statusType;
    request.fields['privacy'] = privacy;
    if (userIds.isNotEmpty) {
      request.fields['user_ids'] = json.encode(userIds.map(int.parse).toList());
    }
    request.files.add(
      await http.MultipartFile.fromPath('media_file', file.path),
    );
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return UserStatus.fromJson(
      Map<String, dynamic>.from(json.decode(response.body)),
    );
  }

  Future<void> markStatusViewed(String statusId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/status/$statusId/view/'),
      headers: headers,
      body: json.encode({}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<List<StatusViewer>> fetchStatusViewers(String statusId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/status/$statusId/views/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return List<dynamic>.from(json.decode(response.body))
        .map((item) => StatusViewer.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> deleteStatus(String statusId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/status/$statusId/delete/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
  }

  Future<List<SharedMedia>> getSharedMedia(
    String userId, {
    String type = 'media',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/shared-media/?user_id=$userId&type=$type');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(response);
    }
    return List<dynamic>.from(json.decode(response.body))
        .map((item) => SharedMedia.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
