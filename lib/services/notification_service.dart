import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'callkit_service.dart';

class IncomingCallNotificationTap {
  final Map<String, dynamic> data;
  final String? actionId;

  const IncomingCallNotificationTap({required this.data, this.actionId});
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint(
      '[push_timing] background FCM received at ${DateTime.now().toIso8601String()} '
      'message_id=${message.data['message_id'] ?? message.data['id'] ?? 'none'} '
      'call_id=${message.data['call_id'] ?? 'none'} type=${message.data['type'] ?? 'message'}',
    );
  }
  await NotificationService().showRemoteMessageNotification(message);
}

class NotificationService {
  static const String _shownPushMessageIdsKey = 'shown_push_message_ids';
  static const String _messageChannelId = 'm2m_messages_default_v1';
  static const String _messageChannelName = 'M2M Messages';
  static const String _incomingCallChannelId = 'm2m_incoming_calls_ringtone_v2';
  static const String _incomingCallChannelName = 'Incoming calls';
  static const String acceptCallActionId = 'accept_call';
  static const String rejectCallActionId = 'reject_call';
  static const MethodChannel _ringtoneChannel = MethodChannel(
    'com.danish.m2m/ringtone',
  );

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _soundPlayer = AudioPlayer();
  final StreamController<IncomingCallNotificationTap>
  _incomingCallTapController =
      StreamController<IncomingCallNotificationTap>.broadcast();
  final Set<String> _shownMessageIds = <String>{};
  final Set<String> _soundedMessageIds = <String>{};
  final Set<String> _shownIncomingCallIds = <String>{};
  String? _activeChatId;
  String? _activeChatParticipantId;

  static GlobalKey<NavigatorState>? navigatorKey;
  bool _localNotificationsReady = false;
  bool _firebaseListenersReady = false;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  Stream<IncomingCallNotificationTap> get incomingCallTapStream =>
      _incomingCallTapController.stream;

  static Future<void> getTokenAndSave() {
    return _instance._saveToken();
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) {
    return _instance._showNotification(title: title, body: body, data: data);
  }

  static Future<void> playMessageSound({String? messageId}) {
    return _instance._playMessageSound(messageId: messageId);
  }

  /// Called for every incoming foreground push that represents a chat message.
  /// The chat list registers this so it refreshes live even when the WebSocket
  /// momentarily lags or drops (push delivery is the reliable safety net).
  static void Function(Map<String, dynamic> data)? onForegroundMessageData;

  static void setActiveChatId(String? chatId) {
    _instance._activeChatId = chatId;
    // Opening a chat clears its pending notifications from the tray, the same
    // way reading a WhatsApp chat dismisses its notifications.
    if (chatId != null && chatId.isNotEmpty) {
      unawaited(_instance.clearChatNotifications(chatId));
    }
  }

  static void setActiveChatParticipantId(String? participantId) {
    _instance._activeChatParticipantId = participantId;
  }

  static bool isActiveChat(String? chatId) {
    return chatId != null &&
        chatId.isNotEmpty &&
        _instance._activeChatId == chatId;
  }

  static bool isActiveChatParticipant(String? participantId) {
    return participantId != null &&
        participantId.isNotEmpty &&
        _instance._activeChatParticipantId == participantId;
  }

  Future<void> initialize({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;

    try {
      await _setupLocalNotifications();

      if (!_firebaseListenersReady) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        FirebaseMessaging.onMessage.listen((message) {
          _logPushTiming('foreground FCM received', message.data);
          handleForegroundRemoteMessage(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _logPushTiming('notification opened', message.data);
          unawaited(markRemoteMessageDelivered(message));
          _handleNotificationTap(message.data);
        });

        _fcm.onTokenRefresh.listen((token) {
          _logPushTiming('FCM token refresh received');
          _uploadToken(token);
        });
        _firebaseListenersReady = true;
      }

      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        _logPushTiming('initial FCM message received', initial.data);
        unawaited(markRemoteMessageDelivered(initial));
        _handleNotificationTap(initial.data);
      }

      unawaited(_requestPermissionAndSaveToken());
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  Future<void> _requestPermissionAndSaveToken() async {
    try {
      debugPrint('[startup] notification permission requested');
      await _requestPermission();
      debugPrint('[startup] notification permission completed');
      await _saveToken();
    } catch (e) {
      debugPrint('Notification permission/token setup error: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _logPushTiming(
      'notification permission=${settings.authorizationStatus.name}',
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
  }

  Future<void> handleForegroundRemoteMessage(RemoteMessage message) async {
    if (_isIncomingCallPayload(message.data)) {
      // App is in the FOREGROUND: present the in-app incoming-call screen
      // directly (this is the reliable, OEM-independent path  it does NOT touch
      // the native CallKit activity, which some OEMs like MIUI gate behind
      // background-launch restrictions). CallKit is only used when the app is
      // backgrounded/terminated (see showRemoteMessageNotification). The screen
      // owns a single ringtone; de-duped against the WebSocket invite by call id.
      _incomingCallTapController.add(
        IncomingCallNotificationTap(data: message.data),
      );
      return;
    }
    await markRemoteMessageDelivered(message);
    // Keep the chat list live regardless of WebSocket health.
    onForegroundMessageData?.call(message.data);
    final messageId =
        message.data['message_id']?.toString() ??
        message.data['id']?.toString();
    if (_isMessageForActiveChat(message.data)) {
      await _playMessageSound(messageId: messageId);
      return;
    }

    final notification = message.notification;
    await _showNotification(
      title: notification?.title ?? message.data['title'] ?? 'New message',
      body:
          notification?.body ??
          message.data['body'] ??
          'You have a new message',
      data: message.data,
    );
  }

  Future<void> _setupLocalNotifications() async {
    if (_localNotificationsReady) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _handleNotificationTap(data, actionId: details.actionId);
        } catch (e) {
          debugPrint('Notification payload decode error: $e');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _messageChannelId,
      _messageChannelName,
      description: 'New message notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notificationEvent,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const callChannel = AndroidNotificationChannel(
      _incomingCallChannelId,
      _incomingCallChannelName,
      description: 'Full-screen incoming call alerts',
      importance: Importance.max,
      playSound: true,
      sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(callChannel);

    _localNotificationsReady = true;

    final launchDetails = await _local.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    final payload = response?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(payload));
        _logPushTiming('local launch notification received', data);
        _handleNotificationTap(data, actionId: response?.actionId);
      } catch (e) {
        debugPrint('Launch notification payload decode error: $e');
      }
    }
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'New message';
    final body = notification?.body ?? data['body'] ?? 'You have a new message';

    if (_isIncomingCallPayload(data)) {
      _logPushTiming('remote incoming call notification handling', data);
      // Android: the native CallKit-style screen handles ringtone + full-screen
      // launch from the terminated/background state (no Flutter UI boot, single
      // ringtone). iOS keeps the full-screen-intent notification path.
      if (CallkitService.isSupported) {
        // The push reached this device  ack ringing over HTTP so the caller
        // sees "Ringing..." even if the app is never opened (mirrors the old
        // showIncomingCallNotification behaviour; markCallRinging loads the auth
        // token itself and is idempotent).
        final callId = data['call_id']?.toString();
        if (callId != null && callId.isNotEmpty) {
          unawaited(ApiService().markCallRinging(int.tryParse(callId) ?? 0));
        }
        await CallkitService.showIncoming(Map<String, dynamic>.from(data));
      } else {
        await showIncomingCallNotification(data);
      }
      return;
    }

    // Android/iOS already render notification+data messages while the app is
    // backgrounded or terminated. Some platform versions also invoke the
    // background Dart handler; showing another local notification here would
    // produce two alerts for the same message.
    if (notification != null) {
      _logPushTiming('remote notification already displayed by OS', data);
      await markRemoteMessageDelivered(message);
      return;
    }

    _logPushTiming('remote message notification handling', data);
    await _showNotification(title: title, body: body, data: data);
    await markRemoteMessageDelivered(message);
  }

  Future<void> markRemoteMessageDelivered(RemoteMessage message) async {
    try {
      final data = message.data;
      final messageId =
          data['message_id']?.toString() ?? data['id']?.toString();
      if (messageId != null) {
        await ApiService().markMessagesDelivered([messageId]);
      }
    } catch (e) {
      debugPrint('FCM delivery callback error: $e');
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final messageId = data['message_id']?.toString() ?? data['id']?.toString();
    // Reserve the ID before asynchronous plugin initialization. A WebSocket
    // event and foreground FCM event can arrive together and otherwise both
    // pass the dedupe check while awaiting setup.
    if (messageId != null && !_shownMessageIds.add(messageId)) {
      return;
    }
    if (messageId != null && await _wasPushMessageAlreadyShown(messageId)) {
      _shownMessageIds.remove(messageId);
      return;
    }
    if (messageId != null) {
      Future.delayed(const Duration(minutes: 10), () {
        _shownMessageIds.remove(messageId);
      });
    }

    final chatId = data['chat_id']?.toString() ?? data['chat']?.toString();
    final senderId =
        data['sender_id']?.toString() ?? data['sender']?.toString();
    final senderName =
        data['sender_name']?.toString() ?? data['title']?.toString() ?? title;

    // One stable notification per sender (WhatsApp-style): the first message
    // posts a notification, subsequent messages from the same person UPDATE that
    // same notification (same id) and stack their text in an inbox/messaging
    // list. The id is derived from the sender (falls back to the chat) so it is
    // identical across messages  never a random id or timestamp.
    final groupKey = chatId ?? senderId;
    final group = await _accumulateMessageGroup(
      groupKey: groupKey,
      senderName: senderName,
      line: body,
    );
    final count = group.count;
    final notificationId = _messageNotificationId(senderId, chatId);

    // Title shows the sender plus the unread count once more than one is pending,
    // e.g. "Ali (3 new messages)".
    final displayTitle = count > 1
        ? '$senderName ($count new messages)'
        : senderName;
    final summaryLine = count > 1 ? '$count new messages' : senderName;

    try {
      await _setupLocalNotifications();
      await _local.show(
        notificationId,
        displayTitle,
        // Collapsed line shows the most recent message; expanded view (inbox
        // style) shows each message stacked below the other.
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _messageChannelId,
            _messageChannelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF6B00D7),
            playSound: true,
            // Only ring/buzz for the freshest message; updates to an existing
            // notification stay silent so a burst doesn't vibrate repeatedly.
            onlyAlertOnce: count > 1,
            number: count,
            audioAttributesUsage: AudioAttributesUsage.notificationEvent,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            styleInformation: count > 1
                ? InboxStyleInformation(
                    group.lines,
                    contentTitle: displayTitle,
                    summaryText: summaryLine,
                  )
                : BigTextStyleInformation(body, contentTitle: displayTitle),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: count <= 1,
            badgeNumber: count,
            // Groups this sender's alerts into a single iOS notification thread.
            threadIdentifier: groupKey ?? 'm2m_messages',
          ),
        ),
        payload: jsonEncode(data),
      );
      if (chatId != null && chatId.isNotEmpty) {
        await _recordChatNotification(chatId, notificationId);
      }
      _logPushTiming('local message notification shown', data);
    } catch (_) {
      if (messageId != null) _shownMessageIds.remove(messageId);
      rethrow;
    }
  }

  // Per-chat notification ids are persisted (not just in-memory) because a push
  // can be rendered by the background isolate while the UI isolate is dead;
  // both write here so the chat screen can later clear them on open.
  static String _chatNotifKey(String chatId) => 'chat_notif_ids:$chatId';

  Future<void> _recordChatNotification(
    String chatId,
    int notificationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _chatNotifKey(chatId);
      final ids = prefs.getStringList(key) ?? <String>[];
      final idStr = notificationId.toString();
      ids.remove(idStr);
      ids.add(idStr);
      final capped = ids.length > 50 ? ids.sublist(ids.length - 50) : ids;
      await prefs.setStringList(key, capped);
    } catch (e) {
      debugPrint('Record chat notification error: $e');
    }
  }

  /// Dismiss every tray notification belonging to [chatId]. Safe to call when
  /// none are pending.
  Future<void> clearChatNotifications(String chatId) async {
    if (chatId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _chatNotifKey(chatId);
      final ids = prefs.getStringList(key);
      if (ids == null || ids.isEmpty) return;
      await _setupLocalNotifications();
      for (final idStr in ids) {
        final id = int.tryParse(idStr);
        if (id != null) await _local.cancel(id);
      }
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Clear chat notifications error: $e');
    }
    // Reset the running unread count/lines so the next message starts a fresh
    // "1 new message" notification instead of resuming the old tally.
    await _clearMessageGroup(chatId);
  }

  Future<void> showIncomingCallNotification(Map<String, dynamic> data) async {
    await _setupLocalNotifications();
    final callId = data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;
    if (!_shownIncomingCallIds.add(callId)) return;
    Future.delayed(const Duration(minutes: 2), () {
      _shownIncomingCallIds.remove(callId);
    });

    // The push reached this device (app backgrounded/terminated): ack ringing
    // over HTTP so the caller sees "Ringing..." even if the app is never
    // opened. Works from the FCM background isolate  markCallRinging loads the
    // auth token itself. Idempotent and best-effort.
    unawaited(ApiService().markCallRinging(int.tryParse(callId) ?? 0));

    final callerName = data['caller_name']?.toString();
    final callType = data['call_type']?.toString() == 'video'
        ? 'video'
        : 'audio';
    final title = callerName == null || callerName.isEmpty
        ? 'Incoming call'
        : callerName;
    final body = 'Incoming $callType call';

    await startRingtone();

    await _local.show(
      _notificationIdForIncomingCall(callId),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _incomingCallChannelId,
          _incomingCallChannelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF6B00D7),
          playSound: true,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/ringtone',
          ),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 60000,
          actions: const [
            AndroidNotificationAction(
              rejectCallActionId,
              'Reject',
              showsUserInterface: true,
              semanticAction: SemanticAction.delete,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              acceptCallActionId,
              'Accept',
              showsUserInterface: true,
              semanticAction: SemanticAction.call,
              cancelNotification: true,
            ),
          ],
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode(data),
    );
    _logPushTiming('local incoming call notification shown', data);
  }

  Future<void> dismissIncomingCall(String? callId) async {
    await stopRingtone();
    if (callId == null || callId.isEmpty) return;
    _shownIncomingCallIds.remove(callId);
    await _local.cancel(_notificationIdForIncomingCall(callId));
  }

  Future<void> clearSessionState() async {
    await stopRingtone();
    _activeChatId = null;
    _activeChatParticipantId = null;
    _shownMessageIds.clear();
    _soundedMessageIds.clear();
    _shownIncomingCallIds.clear();
    try {
      await _setupLocalNotifications();
      await _local.cancelAll();
    } catch (e) {
      debugPrint('Notification cancel all error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (key) =>
            key == _shownPushMessageIdsKey ||
            key.startsWith('chat_notif_ids:') ||
            key.startsWith('notif_group:'),
      );
      for (final key in keys.toList()) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Notification session clear error: $e');
    }
  }

  // A stable notification id per sender (falls back to the chat). Kept inside
  // 0..0x3fffffff so it never collides with the incoming-call id space, which
  // lives at 0x40000000+.
  int _messageNotificationId(String? senderId, String? chatId) {
    final basis = (senderId != null && senderId.isNotEmpty)
        ? senderId
        : (chatId ?? '');
    return basis.hashCode & 0x3fffffff;
  }

  static String _notifGroupKey(String groupKey) => 'notif_group:$groupKey';

  /// Adds [line] to the running list of pending messages for [groupKey] and
  /// returns the updated count + lines (most-recent last, capped). Persisted so
  /// the background isolate and the UI isolate accumulate into the same bucket.
  Future<_MessageGroup> _accumulateMessageGroup({
    required String? groupKey,
    required String senderName,
    required String line,
  }) async {
    if (groupKey == null || groupKey.isEmpty) {
      return _MessageGroup(count: 1, lines: [line]);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notifGroupKey(groupKey);
      final lines = <String>[
        ...(prefs.getStringList(key) ?? const <String>[]),
        line,
      ];
      // Inbox style renders at most ~5-7 rows; keep the latest handful.
      final capped = lines.length > 6 ? lines.sublist(lines.length - 6) : lines;
      await prefs.setStringList(key, capped);
      // The true count (may exceed the displayed lines) lives in its own key.
      final countKey = '$key:count';
      final count = (prefs.getInt(countKey) ?? 0) + 1;
      await prefs.setInt(countKey, count);
      return _MessageGroup(count: count, lines: capped);
    } catch (e) {
      debugPrint('Notification group accumulate error: $e');
      return _MessageGroup(count: 1, lines: [line]);
    }
  }

  Future<void> _clearMessageGroup(String groupKey) async {
    if (groupKey.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notifGroupKey(groupKey);
      await prefs.remove(key);
      await prefs.remove('$key:count');
    } catch (e) {
      debugPrint('Notification group clear error: $e');
    }
  }

  int _notificationIdForIncomingCall(String callId) {
    final parsed = int.tryParse(callId);
    if (parsed != null) return (parsed & 0x3fffffff) + 0x40000000;
    return callId.hashCode & 0x7fffffff;
  }

  Future<bool> _wasPushMessageAlreadyShown(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownIds = prefs.getStringList(_shownPushMessageIdsKey) ?? [];
      if (shownIds.contains(messageId)) return true;
      final nextIds = <String>[
        messageId,
        ...shownIds,
      ].take(80).toList(growable: false);
      await prefs.setStringList(_shownPushMessageIdsKey, nextIds);
      return false;
    } catch (e) {
      debugPrint('Notification dedupe error: $e');
      return false;
    }
  }

  Future<void> _playMessageSound({String? messageId}) async {
    if (messageId != null && !_soundedMessageIds.add(messageId)) {
      return;
    }
    if (messageId != null) {
      Future.delayed(const Duration(minutes: 10), () {
        _soundedMessageIds.remove(messageId);
      });
    }
    try {
      await _soundPlayer.stop();
      await _soundPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Message sound error: $e');
    }
  }

  bool _isIncomingCallPayload(Map<String, dynamic> data) {
    return data['type']?.toString() == 'incoming_call' &&
        data['call_id'] != null;
  }

  bool _isMessageForActiveChat(Map<String, dynamic> data) {
    final chatId = data['chat_id']?.toString() ?? data['chat']?.toString();
    final senderId =
        data['sender_id']?.toString() ?? data['sender']?.toString();
    return isActiveChat(chatId) || isActiveChatParticipant(senderId);
  }

  void _handleNotificationTap(Map<String, dynamic> data, {String? actionId}) {
    if (_isIncomingCallPayload(data)) {
      stopRingtone();
      _incomingCallTapController.add(
        IncomingCallNotificationTap(data: data, actionId: actionId),
      );
      return;
    }

    final chatId = data['chat_id']?.toString();
    final senderId = data['sender_id']?.toString();
    final navState = navigatorKey?.currentState;

    if (chatId == null || navState == null) return;

    navState.pushNamed(
      '/chat',
      arguments: {'chat_id': chatId, 'sender_id': senderId},
    );
  }

  Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _uploadToken(token);
      } else {
        _logPushTiming('FCM token missing');
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      await ApiService().updateFcmToken(token);
      _logPushTiming('FCM token upload success');
    } catch (e) {
      debugPrint('FCM token upload error: $e');
    }
  }

  void _logPushTiming(String event, [Map<String, dynamic>? data]) {
    if (!kDebugMode) return;
    final messageId =
        data?['message_id']?.toString() ?? data?['id']?.toString();
    final callId = data?['call_id']?.toString();
    final type = data?['type']?.toString() ?? 'message';
    debugPrint(
      '[push_timing] $event at ${DateTime.now().toIso8601String()} '
      'message_id=${messageId ?? 'none'} call_id=${callId ?? 'none'} type=$type',
    );
  }

  Future<void> startRingtone() async {
    if (!Platform.isAndroid) return;
    try {
      await _ringtoneChannel.invokeMethod('startIncomingCallRingtone');
    } catch (e) {
      debugPrint('Error starting native ringtone: $e');
    }
  }

  Future<void> stopRingtone() async {
    if (!Platform.isAndroid) return;
    try {
      await _ringtoneChannel.invokeMethod('stopIncomingCallRingtone');
    } catch (e) {
      debugPrint('Error stopping native ringtone: $e');
    }
  }
}

/// Running tally of pending messages from a single sender, used to render a
/// grouped (inbox-style) notification that updates in place.
class _MessageGroup {
  const _MessageGroup({required this.count, required this.lines});

  final int count;
  final List<String> lines;
}
