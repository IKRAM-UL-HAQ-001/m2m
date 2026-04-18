import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class SocketService extends ChangeNotifier {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final wsUrl = '${AppConstants.wsBaseUrl}?token=$token';
    debugPrint('Connecting to WebSocket: $wsUrl');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          debugPrint('WebSocket Message Received: $data');
          _handleMessage(data);
        },
        onDone: () {
          debugPrint('WebSocket Disconnected');
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket Connection Error: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> rawData = json.decode(data);
      final Map<String, dynamic> messageData = rawData['message'] ?? rawData;
      
      messageData['received_at'] = DateTime.now().toIso8601String();
      
      final message = Message.fromJson(messageData);
      
      // Play sound/show notification if message is from someone else
      if (!message.isMe) {
        NotificationService.showLocalNotification(
          title: 'New Message',
          body: message.text,
        );
      }
      
      _messageController.add(message);
    } catch (e) {
      debugPrint('Error handling WS message: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageController.close();
    _channel?.sink.close();
    super.dispose();
  }
}
