import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart';
import '../models/contact_user.dart';
import '../models/message.dart';
import '../models/shared_media.dart';
import '../models/user_status.dart';
import '../utils/constants.dart';
import 'dio_client.dart';

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

  Dio get _dio {
    DioClient().initialize();
    return DioClient().dio;
  }

  Dio get _uploadDio {
    DioClient().initialize();
    return DioClient().uploadDio;
  }

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

  static String mediaUrl(String? path) => DioClient.mediaUrl(path);

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    return const [];
  }

  Never _throwApiError(Response<dynamic> response) {
    final data = response.data;
    var message = 'Request failed';
    if (data is Map) {
      message = (data['error'] ?? data['detail'] ?? data['message'] ?? message)
          .toString();
    } else if (data != null) {
      message = data.toString();
    }
    throw ApiException(response.statusCode ?? 0, message);
  }

  Future<bool> requestOtp(String phoneNumber, String countryCode) async {
    final response = await _dio.post(
      '/auth/request-otp/',
      data: {'phone_number': phoneNumber, 'country_code': countryCode},
    );
    debugPrint('Request OTP status: ${response.statusCode}');
    return true;
  }

  Future<Map<String, dynamic>> verifyOtp(
    String phoneNumber,
    String countryCode,
    String otp,
  ) async {
    final response = await _dio.post(
      '/auth/verify-otp/',
      data: {
        'phone_number': phoneNumber,
        'country_code': countryCode,
        'otp': otp,
      },
    );
    return _asMap(response.data);
  }

  Future<String> generateLinkToken() async {
    final response = await _dio.get('/auth/generate-link-token/');
    return _asMap(response.data)['token'].toString();
  }

  Future<bool> activateLinkToken(String token) async {
    await _dio.post('/auth/activate-link-token/', data: {'token': token});
    return true;
  }

  Future<Map<String, dynamic>> checkLinkStatus(String token) async {
    final response = await _dio.get('/auth/check-link-status/$token/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> fetchWebSocketTicket() async {
    final response = await _dio.post('/auth/ws-ticket/', data: {});
    return _asMap(response.data);
  }

  Future<String?> getWsTicket() async {
    final data = await fetchWebSocketTicket();
    return data['ticket'] as String?;
  }

  Future<void> sendPresenceHeartbeat() async {
    await _dio.post('/auth/presence/heartbeat/', data: {});
  }

  Future<Map<String, dynamic>> getPresence(String userId) async {
    final response = await _dio.get('/auth/presence/$userId/');
    return _asMap(response.data);
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

    await _dio.post('/auth/sync-contacts/', data: {'contacts': contactList});
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
    if (imagePath == null) {
      final body = {'name': name};
      if (about != null) body['about'] = about;
      await _dio.post('/auth/complete-profile/', data: body);
      return true;
    }

    final data = <String, dynamic>{'name': name};
    if (about != null) data['about'] = about;
    data['profile_picture'] = await MultipartFile.fromFile(
      imagePath,
      filename: imagePath.split('/').last,
    );
    final formData = FormData.fromMap(data);
    await _uploadDio.post(
      '/auth/complete-profile/',
      data: formData,
      options: Options(extra: {'upload': true}),
    );
    return true;
  }

  Future<List<Chat>> getChats({int offset = 0, int limit = 20}) async {
    final response = await _dio.get(
      '/api/chats/',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = _asMap(response.data);
    final results = List<dynamic>.from(data['results'] ?? const []);
    return results
        .map((item) => Chat.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Message>> getMessages(String chatId, {String? cursor}) async {
    if (chatId.startsWith('new_')) return [];
    final queryParameters = <String, dynamic>{'page_size': 30};
    if (cursor != null) queryParameters['cursor'] = cursor;
    final response = await _dio.get(
      '/api/chats/$chatId/messages/',
      queryParameters: queryParameters,
    );
    final data = _asMap(response.data);
    final results = List<dynamic>.from(data['results'] ?? const []);
    return results
        .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> getStatusPrivacy() async {
    final response = await _dio.get('/api/status/privacy/');
    return _asMap(response.data);
  }

  Future<void> updateStatusPrivacy({
    required String privacy,
    required List<String> exceptUserIds,
    required List<String> onlyUserIds,
  }) async {
    await _dio.post(
      '/api/status/privacy/',
      data: {
        'privacy': privacy,
        'except_user_ids': exceptUserIds,
        'only_user_ids': onlyUserIds,
      },
    );
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
    void Function(int, int)? onProgress,
  }) async {
    final data = <String, dynamic>{
      'receiver_id': receiverId,
      'encrypted_text': text,
      'client_uuid': clientUuid,
      if (duration != null) 'duration': duration.toStringAsFixed(1),
      'message_type':
          type ?? (file == null ? 'text' : _detectMessageType(file)),
      if (file != null)
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
    };
    if (replyTo != null) data['reply_to'] = replyTo;
    final formData = FormData.fromMap(data);

    final response = await _uploadDio.post(
      '/api/send/',
      data: formData,
      onSendProgress: onProgress,
      options: Options(extra: {'upload': true}),
    );
    return Message.fromJson(_asMap(response.data));
  }

  Future<Map<String, dynamic>> sendFile({
    required String chatId,
    required File file,
    required String messageType,
    double? duration,
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'message_type': messageType,
      if (duration != null) 'duration': duration.toStringAsFixed(1),
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final response = await _uploadDio.post(
      '/api/send/',
      data: formData,
      onSendProgress: onProgress,
      options: Options(extra: {'upload': true}),
    );
    return _asMap(response.data);
  }

  String _detectMessageType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'].contains(ext)) {
      return 'video';
    }
    if (['mp3', 'm4a', 'aac', 'ogg', 'oga', 'wav', 'opus'].contains(ext)) {
      return 'audio';
    }
    if ([
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'txt',
      'ppt',
      'pptx',
      'csv',
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
    ].contains(ext)) {
      return 'document';
    }
    return 'image';
  }

  Future<List<Map<String, dynamic>>> fetchUsers({
    List<Map<String, dynamic>>? contacts,
  }) async {
    final response = contacts == null
        ? await _dio.get('/auth/list-users/')
        : await _dio.post('/auth/list-users/', data: {'contacts': contacts});
    return _asList(
      response.data,
    ).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> inviteContact(String phone, String contactName) async {
    await _dio.post(
      '/auth/invite-contact/',
      data: {'phone': phone, 'contact_name': contactName},
    );
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.post('/auth/update-fcm-token/', data: {'fcm_token': token});
  }

  Future<bool> deleteAccount(String otp) async {
    await _dio.post('/auth/delete-account/', data: {'otp': otp});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return true;
  }

  Future<void> sendTyping(String chatId, bool isTyping) async {
    await _dio.post(
      '/api/typing/',
      data: {'chat_id': int.parse(chatId), 'is_typing': isTyping},
    );
  }

  Future<void> markMessagesDelivered(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final intIds = messageIds
        .map((id) => int.tryParse(id))
        .where((id) => id != null)
        .cast<int>()
        .toList();
    if (intIds.isEmpty) return;
    await _dio.post(
      '/api/messages/delivered/',
      data: {'message_ids': intIds},
    );
  }

  Future<void> markChatRead(String chatId) async {
    if (chatId.startsWith('new_')) return;
    await _dio.post(
      '/api/messages/read/',
      data: {'chat_id': int.parse(chatId)},
    );
  }

  Future<void> deleteMessage(String messageId, String deleteType) async {
    await _dio.post(
      '/api/delete-message/',
      data: {'message_id': int.parse(messageId), 'delete_type': deleteType},
    );
  }

  Future<void> editMessage(String messageId, String newText) async {
    await _dio.post(
      '/api/edit-message/',
      data: {'message_id': int.parse(messageId), 'encrypted_text': newText},
    );
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    await _dio.post(
      '/api/react/',
      data: {'message_id': int.parse(messageId), 'emoji': emoji},
    );
  }

  Future<Message> forwardMessage({
    required String originalMessageId,
    required String toChatId,
  }) async {
    final response = await _dio.post(
      '/api/forward/',
      data: {
        'message_id': int.parse(originalMessageId),
        'chat_id': int.parse(toChatId),
      },
    );
    return Message.fromJson(_asMap(response.data));
  }

  Future<List<StatusGroup>> fetchStatusFeed() async {
    final response = await _dio.get('/api/status/feed/');
    return _asList(response.data)
        .map(
          (item) =>
              StatusGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<dynamic>> getStatusFeed() async {
    final response = await _dio.get('/api/status/feed/');
    return _asList(response.data);
  }

  Future<List<UserStatus>> fetchMyStatuses() async {
    final response = await _dio.get('/api/status/my/');
    return _asList(response.data)
        .map(
          (item) => UserStatus.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<UserStatus> createTextStatus(
    String text, {
    String backgroundColor = '#6B00D7',
    int fontSize = 28,
    String privacy = 'all_contacts',
    List<String> userIds = const [],
  }) async {
    final response = await _dio.post(
      '/api/status/create/',
      data: {
        'status_type': 'text',
        'text_content': text,
        'background_color': backgroundColor,
        'font_size': fontSize,
        'privacy': privacy,
        'user_ids': userIds.map(int.parse).toList(),
      },
    );
    return UserStatus.fromJson(_asMap(response.data));
  }

  Future<UserStatus> createMediaStatus(
    File file,
    String statusType, {
    String privacy = 'all_contacts',
    List<String> userIds = const [],
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'status_type': statusType,
      'privacy': privacy,
      if (userIds.isNotEmpty) 'user_ids': userIds.map(int.parse).toList(),
      'media_file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final response = await _uploadDio.post(
      '/api/status/create/',
      data: formData,
      onSendProgress: onProgress,
      options: Options(extra: {'upload': true}),
    );
    return UserStatus.fromJson(_asMap(response.data));
  }

  Future<void> markStatusViewed(String statusId) async {
    await _dio.post('/api/status/$statusId/view/', data: {});
  }

  Future<List<StatusViewer>> fetchStatusViewers(String statusId) async {
    final response = await _dio.get('/api/status/$statusId/views/');
    return _asList(response.data)
        .map(
          (item) =>
              StatusViewer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> deleteStatus(String statusId) async {
    final response = await _dio.delete('/api/status/$statusId/delete/');
    if ((response.statusCode ?? 500) < 200 ||
        (response.statusCode ?? 500) >= 300) {
      _throwApiError(response);
    }
  }

  Future<List<SharedMedia>> getSharedMedia(
    String userId, {
    String type = 'media',
  }) async {
    final response = await _dio.get(
      '/api/shared-media/',
      queryParameters: {'user_id': userId, 'type': type},
    );
    return _asList(response.data)
        .map(
          (item) =>
              SharedMedia.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
