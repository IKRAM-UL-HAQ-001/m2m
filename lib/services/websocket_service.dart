import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

typedef SocketChannelFactory = WebSocketChannel Function(Uri uri);

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
}

class SocketService extends ChangeNotifier {
  SocketService._internal({SocketChannelFactory? channelFactory})
      : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  @visibleForTesting
  factory SocketService.test({required SocketChannelFactory channelFactory}) {
    return SocketService._internal(channelFactory: channelFactory);
  }

  final SocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;

  SocketConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == SocketConnectionState.connected;

  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<MessageStatusUpdate> _messageStatusController =
      StreamController<MessageStatusUpdate>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;
  Stream<MessageStatusUpdate> get messageStatusStream => _messageStatusController.stream;

  Future<void> connect() async {
    if (_connectionState != SocketConnectionState.disconnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;

    _shouldReconnect = true;
    _reconnectTimer?.cancel();
    _updateConnectionState(SocketConnectionState.connecting);
    final wsUrl = '${AppConstants.wsBaseUrl}?token=$token';
    debugPrint('Connecting to WebSocket: $wsUrl');
    
    try {
      final channel = _channelFactory(Uri.parse(wsUrl));
      _channel = channel;
      _channelSubscription = channel.stream.listen(
        _handleSocketData,
        onDone: _handleSocketClosed,
        onError: _handleSocketError,
      );
      await channel.ready;
      if (!identical(_channel, channel)) return;
      _updateConnectionState(SocketConnectionState.connected);
    } catch (e) {
      debugPrint('WebSocket Connection Error: $e');
      _handleDisconnect(triggerReconnect: true);
    }
  }

  void _handleSocketData(dynamic data) {
    try {
      final rawData = Map<String, dynamic>.from(json.decode(data));
      final event = rawData['event'];

      if (event == 'message_status') {
        _messageStatusController.add(MessageStatusUpdate.fromJson(rawData));
        return;
      }

      final messagePayload = rawData['message'] ?? rawData['payload'] ?? rawData;
      final messageData = Map<String, dynamic>.from(
        messagePayload is Map ? messagePayload : rawData,
      );
      messageData['received_at'] = DateTime.now().toIso8601String();

      final message = Message.fromJson(messageData);

      if (!message.isMe) {
        final notificationBody = message.text == '[File]'
            ? 'New ${message.type} message'
            : message.text;
        NotificationService.showLocalNotification(
          title: 'New Message',
          body: notificationBody,
        );
      }

      _messageController.add(message);
    } catch (e) {
      debugPrint('Error handling WS message: $e');
    }
  }

  void _handleSocketClosed() {
    debugPrint('WebSocket Disconnected');
    _handleDisconnect(triggerReconnect: _shouldReconnect);
  }

  void _handleSocketError(Object error) {
    debugPrint('WebSocket Error: $error');
    _handleDisconnect(triggerReconnect: _shouldReconnect);
  }

  void _handleDisconnect({required bool triggerReconnect}) {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;
    _updateConnectionState(SocketConnectionState.disconnected);
    if (triggerReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_shouldReconnect) {
        connect();
      }
    });
  }

  void _updateConnectionState(SocketConnectionState nextState) {
    if (_connectionState == nextState) return;
    _connectionState = nextState;
    notifyListeners();
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    final channel = _channel;
    _channel = null;
    _updateConnectionState(SocketConnectionState.disconnected);
    channel?.sink.close();
  }

  @override
  void dispose() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _messageController.close();
    _messageStatusController.close();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
