import 'dart:convert';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart';
import '../models/call_join_credentials.dart';
import '../models/call_session.dart';
import '../models/contact_user.dart';
import '../models/message.dart';
import '../models/shared_media.dart';
import '../models/user_status.dart';
import '../utils/constants.dart';
import 'dio_client.dart';
import 'multipart_helper.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException(this.statusCode, this.message, {this.code});

  @override
  String toString() => code == null
      ? 'ApiException($statusCode): $message'
      : 'ApiException($statusCode, $code): $message';
}

class ChatPage {
  const ChatPage({required this.items, required this.hasMore});

  final List<Chat> items;
  final bool hasMore;
}

class MessagePage {
  const MessagePage({required this.items, required this.nextCursor});

  final List<Message> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

class ContactDiscoveryResult {
  final List<Map<String, dynamic>> onAppContacts;
  final List<Map<String, dynamic>> offAppContacts;

  const ContactDiscoveryResult({
    required this.onAppContacts,
    required this.offAppContacts,
  });
}

/// A single attempt at parsing a phone number: the text to parse and the region
/// to interpret it in (null = the text already carries a '+' country code).
class _PhoneCandidate {
  const _PhoneCandidate(this.text, this.region);

  final String text;
  final IsoCode? region;
}

class ApiService {
  static String? currentUserId;
  static final String baseUrl = AppConstants.apiBaseUrl;
  static final String authUrl = AppConstants.authBaseUrl;
  static final Random _uuidRandom = Random.secure();
  static const String _lastContactsSyncKey = 'last_contacts_sync_at';
  static Future<ContactDiscoveryResult>? _contactsSyncInFlight;
  static final DioClient _dioClient = DioClient()..initialize();

  Dio get _dio => _dioClient.dio;

  Dio get _uploadDio => _dioClient.uploadDio;

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

  Never _throwCallApiError(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    final data = error.response?.data;
    var message = 'Call request failed';
    String? code;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      message = (map['detail'] ?? map['error'] ?? map['message'] ?? message)
          .toString();
      code = map['code']?.toString();
    } else if (data != null) {
      message = data.toString();
    }

    code ??= switch (statusCode) {
      400 => 'validation_error',
      403 => 'permission_denied',
      404 => 'not_found',
      _ => null,
    };

    throw ApiException(statusCode, message, code: code);
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

  Future<String> generateLinkToken({String? deviceName}) async {
    final response = await _dio.get(
      '/auth/generate-link-token/',
      queryParameters: {
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
      },
    );
    return _asMap(response.data)['token'].toString();
  }

  /// Linked web/companion sessions for the current user (shown on the phone's
  /// Linked devices screen). Each entry: {id, device_name, linked_at}.
  Future<List<Map<String, dynamic>>> getLinkedDevices() async {
    final response = await _dio.get('/auth/linked-devices/');
    final data = _asMap(response.data);
    return List<Map<String, dynamic>>.from(
      (data['devices'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
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

  /// Normalize an arbitrarily-formatted phone number to E.164 (+923435149587).
  ///
  /// Handles +/00 international prefixes, national numbers (via the default
  /// country region), spaces/dashes/brackets, and bare country-code numbers.
  /// Backed by libphonenumber (phone_numbers_parser) for correctness, with a
  /// regex heuristic fallback so a contact sync never drops a number the parser
  /// can't recognise. Reusable for other countries: pass e.g. '+1'.
  static String normalizeContactPhone(
    String? phone, {
    String defaultCountryCode = '+92',
  }) {
    final raw = phone ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    final hasLeadingPlus = raw.trimLeft().startsWith('+');
    final isoCode = _isoForCountryCode(defaultCountryCode);

    // Candidate parse inputs, most-specific first.
    final candidates = <_PhoneCandidate>[];
    if (hasLeadingPlus) {
      candidates.add(_PhoneCandidate('+$digits', null));
    } else if (digits.startsWith('00')) {
      // 00 is the international call prefix in many countries -> "+".
      candidates.add(_PhoneCandidate('+${digits.substring(2)}', null));
    } else {
      // National number (e.g. 03435149587) interpreted via the default region,
      // then a bare international fallback (e.g. 923435149587 -> +92...).
      candidates.add(_PhoneCandidate(digits, isoCode));
      candidates.add(_PhoneCandidate('+$digits', null));
    }

    for (final candidate in candidates) {
      try {
        final parsed = PhoneNumber.parse(
          candidate.text,
          destinationCountry: candidate.region,
        );
        if (parsed.isValid()) return parsed.international; // +<cc><nsn> = E.164
      } catch (_) {
        // Try the next candidate / fall back below.
      }
    }

    return _legacyNormalizeContactPhone(raw, defaultCountryCode);
  }

  /// Map a dial code like '+92' to an [IsoCode] region for the parser.
  /// Extend this map to support more default countries.
  static IsoCode _isoForCountryCode(String code) {
    switch (code.replaceAll(RegExp(r'\D'), '')) {
      case '92':
        return IsoCode.PK;
      case '1':
        return IsoCode.US;
      case '44':
        return IsoCode.GB;
      case '91':
        return IsoCode.IN;
      case '971':
        return IsoCode.AE;
      case '966':
        return IsoCode.SA;
      default:
        return IsoCode.PK;
    }
  }

  /// Best-effort heuristic used only when libphonenumber rejects the input.
  static String _legacyNormalizeContactPhone(
    String raw,
    String defaultCountryCode,
  ) {
    var hasLeadingPlus = raw.trimLeft().startsWith('+');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    // Treat a leading 00 international prefix as "+".
    if (!hasLeadingPlus && digits.startsWith('00')) {
      hasLeadingPlus = true;
      digits = digits.substring(2);
    }
    final cleaned = hasLeadingPlus ? '+$digits' : digits;
    if (cleaned.isEmpty) return '';

    final countryCode = defaultCountryCode.startsWith('+')
        ? defaultCountryCode
        : '+$defaultCountryCode';
    final countryDigits = countryCode.replaceAll(RegExp(r'\D'), '');

    if (cleaned.startsWith('+')) return cleaned;
    if (countryDigits == '92') {
      if (cleaned.length == 11 && cleaned.startsWith('03')) {
        return '+92${cleaned.substring(1)}';
      }
      if (cleaned.length == 10 && cleaned.startsWith('3')) {
        return '+92$cleaned';
      }
      if (cleaned.length == 12 && cleaned.startsWith('92')) {
        return '+$cleaned';
      }
    }
    if (cleaned.startsWith('0')) return '$countryCode${cleaned.substring(1)}';
    if (cleaned.startsWith(countryDigits)) return '+$cleaned';
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

    debugPrint('Contact sync local read started');
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    debugPrint('Contact sync local read completed count=${contacts.length}');
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
    debugPrint('Contact sync normalized unique count=${byPhone.length}');
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
    debugPrint('Contact sync started');
    final normalizedContacts = contacts ?? await readDeviceContacts();
    final contactsAlreadyNormalized = contacts == null;
    final uniqueContacts = <String, Map<String, dynamic>>{};
    for (final contact in normalizedContacts) {
      final rawPhone = (contact['phone_number'] ?? contact['phone'] ?? '')
          .toString();
      final phone = contactsAlreadyNormalized
          ? rawPhone
          : normalizeContactPhone(rawPhone);
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
    debugPrint('Contact sync unique payload count=${contactList.length}');

    await _dio.post('/auth/sync-contacts/', data: {'contacts': contactList});
    final onAppContacts = await fetchUsers(contacts: contactList);
    debugPrint('Contact sync registered matches count=${onAppContacts.length}');
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
          final phone = contact['phone']?.toString() ?? '';
          return phone.isNotEmpty &&
              phone != currentUserPhone &&
              !onAppPhones.contains(phone);
        })
        .map(
          (contact) => {
            'phone': contact['phone']?.toString() ?? '',
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
    debugPrint('Contact sync completed');
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

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/auth/complete-profile/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> completeProfile(
    String name,
    String? imagePath, {
    String? about,
    bool removeProfilePicture = false,
  }) async {
    if (imagePath == null) {
      final body = <String, dynamic>{
        'name': name,
        if (removeProfilePicture) 'remove_profile_picture': true,
      };
      if (about != null) body['about'] = about;
      final response = await _dio.post('/auth/complete-profile/', data: body);
      return _asMap(response.data);
    }

    final data = <String, dynamic>{'name': name};
    if (about != null) data['about'] = about;
    data['profile_picture'] = await multipartFromXFile(
      XFile(imagePath),
      filename: imagePath.split('/').last,
    );
    final formData = FormData.fromMap(data);
    final response = await _uploadDio.post(
      '/auth/complete-profile/',
      data: formData,
      options: Options(extra: {'upload': true}),
    );
    return _asMap(response.data);
  }

  Future<ChatPage> getChatsPage({int offset = 0, int limit = 20}) async {
    final response = await _dio.get(
      '/api/chats/',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = _asMap(response.data);
    final results = List<dynamic>.from(data['results'] ?? const []);
    final chats = results
        .map((item) => Chat.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return ChatPage(items: chats, hasMore: data['next'] != null);
  }

  Future<List<Chat>> getChats({int offset = 0, int limit = 20}) async {
    return (await getChatsPage(offset: offset, limit: limit)).items;
  }

  Future<MessagePage> getMessagesPage(
    String chatId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    if (chatId.startsWith('new_')) {
      return const MessagePage(items: [], nextCursor: null);
    }
    final queryParameters = <String, dynamic>{'page_size': pageSize};
    if (cursor != null) queryParameters['cursor'] = cursor;
    final response = await _dio.get(
      '/api/chats/$chatId/messages/',
      queryParameters: queryParameters,
    );
    final data = _asMap(response.data);
    final results = List<dynamic>.from(data['results'] ?? const []);
    final messages = results
        .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final next = data['next']?.toString();
    final nextCursor = next == null || next.isEmpty
        ? null
        : Uri.tryParse(next)?.queryParameters['cursor'];
    return MessagePage(items: messages, nextCursor: nextCursor);
  }

  Future<List<Message>> getMessages(String chatId, {String? cursor}) async {
    return (await getMessagesPage(chatId, cursor: cursor)).items;
  }

  Future<CallSession> startCall({
    required int receiverId,
    required String callType,
  }) async {
    try {
      await _ensureCallAuthReady();
      final response = await _dio.post(
        '/api/calls/start/',
        data: {'receiver_id': receiverId, 'call_type': callType},
      );
      return CallSession.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<CallSession> acceptCall(int callId) {
    return _callAction(callId, 'accept');
  }

  Future<CallSession> rejectCall(int callId) {
    return _callAction(callId, 'reject');
  }

  Future<CallSession> cancelCall(int callId) {
    return _callAction(callId, 'cancel');
  }

  Future<CallSession> endCall(int callId) {
    return _callAction(callId, 'end');
  }

  /// Keep-alive ping while in an active call. Refreshes the call's updated_at
  /// on the server so the stale-call cleanup task does not force-end a healthy
  /// long-running call (~3 min) — media flows through Chime, so nothing else
  /// touches the call row. Best-effort: never throws.
  Future<void> callHeartbeat(int callId) async {
    if (callId <= 0) return;
    try {
      await _ensureCallAuthReady();
      await _dio.post('/api/calls/$callId/heartbeat/', data: {});
    } catch (_) {
      // Non-critical; a few missed pings are tolerated by the server timeout.
    }
  }

  /// Best-effort "this device is ringing" ack over HTTP. Unlike the WebSocket
  /// ack, this works even when the app was just cold-launched from a call push
  /// and the socket isn't connected yet. Never throws — if it fails, the caller
  /// simply stays on "Calling...". Ensures the auth token is loaded first so it
  /// works from a freshly-started isolate.
  Future<void> markCallRinging(int callId) async {
    if (callId <= 0) return;
    try {
      await TokenStorage.getAccessToken();
      await _dio.post('/api/calls/$callId/ringing/', data: {});
    } catch (_) {
      // Intentionally swallowed: ringing ack is non-critical.
    }
  }

  Future<CallSession> getCallDetail(int callId) async {
    try {
      await _ensureCallAuthReady();
      final response = await _dio.get('/api/calls/$callId/');
      return CallSession.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<CallSession?> getCurrentCall() async {
    try {
      await _ensureCallAuthReady();
      final response = await _dio.get('/api/calls/current/');
      final data = _asMap(response.data);
      final callData = data['call'];
      if (callData == null) return null;
      return CallSession.fromJson(Map<String, dynamic>.from(callData as Map));
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<List<CallSession>> getCallHistory() async {
    try {
      final response = await _dio.get('/api/calls/history/');
      final data = _asMap(response.data);
      final results = List<dynamic>.from(data['results'] ?? const []);
      return results
          .map((item) => CallSession.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<CallJoinCredentials> joinCall(int callId) async {
    try {
      await _ensureCallAuthReady();
      final response = await _dio.post('/api/calls/$callId/join/', data: {});
      return CallJoinCredentials.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<CallSession> _callAction(int callId, String action) async {
    try {
      await _ensureCallAuthReady();
      final response = await _dio.post('/api/calls/$callId/$action/', data: {});
      return CallSession.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _throwCallApiError(error);
    }
  }

  Future<void> _ensureCallAuthReady() async {
    await TokenStorage.getAccessToken();
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
    XFile? file,
    String? fileName,
    String? type,
    String? replyTo,
    Map<String, dynamic>? statusReply,
    double? duration,
    void Function(int, int)? onProgress,
  }) async {
    final data = <String, dynamic>{
      'receiver_id': receiverId,
      'encrypted_text': text,
      'client_uuid': clientUuid,
      if (duration != null) 'duration': duration.toStringAsFixed(1),
      'message_type':
          type ?? (file == null ? 'text' : _detectMessageType(file.name)),
      if (file != null)
        'file': await multipartFromXFile(
          file,
          filename: fileName ?? file.name,
        ),
    };
    if (replyTo != null) data['reply_to'] = replyTo;
    // Sent as a JSON string; the backend parses it into the status_reply field.
    if (statusReply != null) data['status_reply'] = jsonEncode(statusReply);
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
    required XFile file,
    required String messageType,
    double? duration,
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'message_type': messageType,
      if (duration != null) 'duration': duration.toStringAsFixed(1),
      'file': await multipartFromXFile(file, filename: file.name),
    });
    final response = await _uploadDio.post(
      '/api/send/',
      data: formData,
      onSendProgress: onProgress,
      options: Options(extra: {'upload': true}),
    );
    return _asMap(response.data);
  }

  String _detectMessageType(String path) {
    final ext = path.split('.').last.toLowerCase();
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
    await TokenStorage.clearAll();
    await _dioClient.clearCache();
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
    await _dio.post('/api/messages/delivered/', data: {'message_ids': intIds});
  }

  Future<void> markChatRead(String chatId) async {
    if (chatId.startsWith('new_')) return;
    await _dio.post(
      '/api/messages/read/',
      data: {'chat_id': int.parse(chatId)},
    );
  }

  Future<void> deleteMessage(String messageId, String deleteType) async {
    final id = int.tryParse(messageId);
    if (id == null) return;
    await _dio.post(
      '/api/delete-message/',
      data: {'message_id': id, 'delete_type': deleteType},
    );
  }

  Future<void> deleteChat(String chatId) async {
    await _dio.post('/api/delete-chat/', data: {'chat_id': int.parse(chatId)});
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
    XFile file,
    String statusType, {
    String privacy = 'all_contacts',
    List<String> userIds = const [],
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'status_type': statusType,
      'privacy': privacy,
      if (userIds.isNotEmpty) 'user_ids': userIds.map(int.parse).toList(),
      'media_file': await multipartFromXFile(file, filename: file.name),
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
