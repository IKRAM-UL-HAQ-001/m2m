import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../utils/constants.dart';
import 'api_service.dart';
import 'notification_service.dart';

typedef SocketChannelFactory = WebSocketChannel Function(Uri uri);
typedef TicketProvider = Future<Map<String, dynamic>> Function();

enum SocketConnectionState { disconnected, connecting, connected }

class SocketService extends ChangeNotifier {
  SocketService._internal({
    SocketChannelFactory? channelFactory,
    TicketProvider? ticketProvider,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _ticketProvider = ticketProvider;

  String? _activeChatId;
  String? get activeChatId => _activeChatId;
  void setActiveChatId(String? chatId) => _activeChatId = chatId;

  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  @visibleForTesting
  factory SocketService.test({
    required SocketChannelFactory channelFactory,
    TicketProvider? ticketProvider,
  }) {
    return SocketService._internal(
      channelFactory: channelFactory,
      ticketProvider: ticketProvider,
    );
  }

  final SocketChannelFactory _channelFactory;
  final TicketProvider? _ticketProvider;
  final ApiService _apiService = ApiService();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _shouldReconnect = true;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;

  SocketConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == SocketConnectionState.connected;

  final StreamController<Message> _messageController =
      StreamController<Message>.broadcast();
  final StreamController<MessageStatusUpdate> _messageStatusController =
      StreamController<MessageStatusUpdate>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageEditController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeleteController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _reactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _statusEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;
  Stream<MessageStatusUpdate> get messageStatusStream =>
      _messageStatusController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get messageEditStream =>
      _messageEditController.stream;
  Stream<Map<String, dynamic>> get messageDeleteStream =>
      _messageDeleteController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;
  Stream<Map<String, dynamic>> get statusEventStream =>
      _statusEventController.stream;

  Future<void> connect() async {
    if (_connectionState != SocketConnectionState.disconnected) return;

    _shouldReconnect = true;
    _reconnectTimer?.cancel();
    _updateConnectionState(SocketConnectionState.connecting);

    try {
      final ticketData =
          await (_ticketProvider?.call() ?? _apiService.fetchWebSocketTicket());
      final ticket = ticketData['ticket'].toString();
      final wsUrl = '${AppConstants.wsBaseUrl}?ticket=$ticket';
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
      _startHeartbeat();
    } catch (e) {
      _handleDisconnect(triggerReconnect: true);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        _channel?.sink.add(jsonEncode({'event': 'heartbeat'}));
        await _apiService.sendPresenceHeartbeat();
      } catch (_) {}
    });
  }

  void _handleSocketData(dynamic data) {
    try {
      final rawData = Map<String, dynamic>.from(json.decode(data));
      final event = rawData['type'] ?? rawData['event'];
      if (event == 'message_status' || event == 'status_update') {
        final payload = rawData['payload'] is Map
            ? Map<String, dynamic>.from(rawData['payload'])
            : rawData;
        _messageStatusController.add(MessageStatusUpdate.fromJson(payload));
        return;
      }
      if (event == 'typing') {
        _typingController.add(
          Map<String, dynamic>.from(rawData['payload'] ?? const {}),
        );
        return;
      }
      if (event == 'message_edited') {
        _messageEditController.add(
          Map<String, dynamic>.from(rawData['payload'] ?? const {}),
        );
        return;
      }
      if (event == 'message_deleted') {
        _messageDeleteController.add(
          Map<String, dynamic>.from(rawData['payload'] ?? const {}),
        );
        return;
      }
      if (event == 'reaction_update') {
        _reactionController.add(
          Map<String, dynamic>.from(rawData['payload'] ?? const {}),
        );
        return;
      }
      if (event == 'new_user_status' || event == 'status_viewed') {
        final payload = Map<String, dynamic>.from(
          rawData['payload'] ?? const {},
        );
        payload['event'] = event;
        _statusEventController.add(payload);
        return;
      }
      if (event != null && event != 'chat_message') {
        return;
      }

      final messagePayload =
          rawData['message'] ?? rawData['payload'] ?? rawData;
      final messageData = Map<String, dynamic>.from(
        messagePayload is Map ? messagePayload : rawData,
      );
      final message = Message.fromJson(messageData);

      if (!message.isMe && message.chatId != _activeChatId) {
        final notificationBody = message.text == '[File]'
            ? 'New ${message.type} message'
            : message.text;
        NotificationService.showLocalNotification(
          title: 'New Message',
          body: notificationBody,
        );
      }

      _messageController.add(message);
      if (!message.isMe) {
        markDelivered([message.id]);
      }
    } catch (_) {}
  }

  void sendChatOpened(String chatId) {
    if (_channel == null || chatId.startsWith('new_')) return;
    _channel?.sink.add(jsonEncode({'type': 'chat_opened', 'chat_id': chatId}));
  }

  void markDelivered(List<String> messageIds) {
    if (_channel == null || messageIds.isEmpty) return;
    _channel?.sink.add(
      jsonEncode({'type': 'messages_delivered', 'message_ids': messageIds}),
    );
    _apiService.markMessagesDelivered(messageIds).catchError((_) {});
  }

  void _handleSocketClosed() {
    _handleDisconnect(triggerReconnect: _shouldReconnect);
  }

  void _handleSocketError(Object error) {
    _handleDisconnect(triggerReconnect: _shouldReconnect);
  }

  void _handleDisconnect({required bool triggerReconnect}) {
    _heartbeatTimer?.cancel();
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
    _heartbeatTimer?.cancel();
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
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageController.close();
    _messageStatusController.close();
    _typingController.close();
    _messageEditController.close();
    _messageDeleteController.close();
    _reactionController.close();
    _statusEventController.close();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
