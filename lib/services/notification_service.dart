import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:m2m/services/api_service.dart';

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      log('Error playing sound: $e');
    }
  }

  static Future<void> initialize() async {
    try {
      // Request permission (iOS/Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('User granted permission');
      }

      // Android notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel_v2',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await _localNotifications.initialize(initializationSettings);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log("Foreground message received: ${message.messageId}");
        
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;
        Map<String, dynamic> data = message.data;

        // Determine contents
        String title = notification?.title ?? data['title'] ?? 'New Message';
        String body = notification?.body ?? data['body'] ?? 'You have a new message';

        _playSound(); // Always try to play custom sound in foreground

        _localNotifications.show(
          message.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          ),
        );
      });
    } catch (e) {
      log("Error during NotificationService.initialize: $e");
    }
  }

  static Future<void> showLocalNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel_v2',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  static Future<void> getTokenAndSave() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      log("FCM Token: $token");
      // Save token to backend via ApiService
      await ApiService.updateFcmToken(token);
    }
  }
}

// Global background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log("Handling a background message: ${message.messageId}");

  // Only show if there's no automatic notification from FCM
  // (usually happens for data-only messages)
  if (message.notification == null) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel_v2',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    // Re-initialize for background process if needed
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await localNotifications.initialize(initializationSettings);

    final AudioPlayer backgroundAudioPlayer = AudioPlayer();
    try {
      await backgroundAudioPlayer.play(AssetSource('sounds/notification.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      log('Error playing background sound: $e');
    }

    final data = message.data;
    final title = data['title'] ?? 'New Message';
    final body = data['body'] ?? 'You have a new message';

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}
