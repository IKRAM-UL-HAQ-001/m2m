import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().showRemoteMessageNotification(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

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

  Future<void> initialize({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;

    try {
      await _requestPermission();
      await _setupLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        showRemoteMessageNotification(message);
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
      alert: true,
      badge: true,
      sound: true,
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
          _handleNotificationTap(data);
        } catch (e) {
          debugPrint('Notification payload decode error: $e');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'm2m_messages',
      'M2M Messages',
      description: 'New message notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
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

    try {
      final messageId = data['message_id']?.toString() ?? data['id']?.toString();
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

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'm2m_messages',
          'M2M Messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF6B00D7),
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
