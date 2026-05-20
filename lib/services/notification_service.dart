import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().showRemoteMessageNotification(message);
}

class NotificationService {
  static const String _shownPushMessageIdsKey = 'shown_push_message_ids';
  static const String _messageChannelId = 'm2m_messages_custom_v3';
  static const String _messageChannelName = 'M2M Messages';
  static const RawResourceAndroidNotificationSound _messageSound =
      RawResourceAndroidNotificationSound('notification');

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _soundPlayer = AudioPlayer();
  final Set<String> _shownMessageIds = <String>{};
  final Set<String> _soundedMessageIds = <String>{};

  static GlobalKey<NavigatorState>? navigatorKey;
  bool _localNotificationsReady = false;

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

  Future<void> initialize({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;

    try {
      await _requestPermission();
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
    await markRemoteMessageDelivered(message);
    final messageId =
        message.data['message_id']?.toString() ??
        message.data['id']?.toString();
    await _playMessageSound(messageId: messageId);
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
          _handleNotificationTap(data);
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
      sound: _messageSound,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notificationEvent,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _localNotificationsReady = true;
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'New message';
    final body = notification?.body ?? data['body'] ?? 'You have a new message';

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
          sound: _messageSound,
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

  int _notificationIdForMessage(String? messageId) {
    final parsed = int.tryParse(messageId ?? '');
    if (parsed != null) return parsed & 0x7fffffff;
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
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

  void _handleNotificationTap(Map<String, dynamic> data) {
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
}
