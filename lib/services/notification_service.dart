import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class IncomingCallNotificationTap {
  final Map<String, dynamic> data;
  final String? actionId;

  const IncomingCallNotificationTap({required this.data, this.actionId});
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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

  static void setActiveChatId(String? chatId) {
    _instance._activeChatId = chatId;
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

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        handleForegroundRemoteMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data);
      });

      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationTap(initial.data);
        });
      }

      debugPrint('[startup] notification permission requested');
      await _requestPermission();
      debugPrint('[startup] notification permission completed');
      await _saveToken();

      _fcm.onTokenRefresh.listen((token) {
        _uploadToken(token);
      });
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
  }

  Future<void> handleForegroundRemoteMessage(RemoteMessage message) async {
    if (_isIncomingCallPayload(message.data)) {
      await showIncomingCallNotification(message.data);
      _incomingCallTapController.add(
        IncomingCallNotificationTap(data: message.data),
      );
      return;
    }
    await markRemoteMessageDelivered(message);
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
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationTap(data, actionId: response?.actionId);
        });
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
      await showIncomingCallNotification(data);
      return;
    }

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
    await _setupLocalNotifications();
    final messageId = data['message_id']?.toString() ?? data['id']?.toString();
    if (messageId != null && !_shownMessageIds.add(messageId)) {
      return;
    }
    if (messageId != null && await _wasPushMessageAlreadyShown(messageId)) {
      return;
    }
    if (messageId != null) {
      Future.delayed(const Duration(minutes: 10), () {
        _shownMessageIds.remove(messageId);
      });
    }

    await _local.show(
      _notificationIdForMessage(messageId),
      title,
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
          audioAttributesUsage: AudioAttributesUsage.notificationEvent,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> showIncomingCallNotification(Map<String, dynamic> data) async {
    await _setupLocalNotifications();
    final callId = data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;
    if (!_shownIncomingCallIds.add(callId)) return;
    Future.delayed(const Duration(minutes: 2), () {
      _shownIncomingCallIds.remove(callId);
    });

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
  }

  Future<void> dismissIncomingCall(String? callId) async {
    await stopRingtone();
    if (callId == null || callId.isEmpty) return;
    _shownIncomingCallIds.remove(callId);
    await _local.cancel(_notificationIdForIncomingCall(callId));
  }

  int _notificationIdForMessage(String? messageId) {
    final parsed = int.tryParse(messageId ?? '');
    if (parsed != null) return parsed & 0x7fffffff;
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
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
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      await ApiService().updateFcmToken(token);
    } catch (e) {
      debugPrint('FCM token upload error: $e');
    }
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
