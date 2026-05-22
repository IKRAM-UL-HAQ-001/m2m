import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/models/message.dart';
import 'package:m2m/services/api_service.dart';
import 'package:m2m/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketSink implements WebSocketSink {
  FakeWebSocketSink(this._controller);

  final StreamController<dynamic> _controller;
  bool isClosed = false;

  @override
  void add(dynamic event) => _controller.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    isClosed = true;
    await _controller.close();
  }

  @override
  Future<void> get done => _controller.done;
}

class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel({Future<void>? ready})
    : _ready = ready ?? Future.value();

  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  late final FakeWebSocketSink _sink = FakeWebSocketSink(_controller);
  final Future<void> _ready;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => _ready;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  void addIncoming(dynamic data) => _controller.add(data);

  bool get sinkClosed => _sink.isClosed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.currentUserId = '1';
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
  });

  test(
    'SocketService connect is idempotent and can reconnect after disconnect',
    () async {
      final firstReady = Completer<void>();
      final secondReady = Completer<void>();
      final channels = [
        FakeWebSocketChannel(ready: firstReady.future),
        FakeWebSocketChannel(ready: secondReady.future),
      ];
      var connectionAttempts = 0;

      final service = SocketService.test(
        channelFactory: (_) => channels[connectionAttempts++],
        ticketProvider: () async => {'ticket': 'fake-ticket'},
      );

      final firstConnect = service.connect();
      await Future<void>.delayed(Duration.zero);
      final secondConnect = service.connect();
      await Future<void>.delayed(Duration.zero);

      expect(connectionAttempts, 1);
      expect(service.connectionState, SocketConnectionState.connecting);

      firstReady.complete();
      await Future.wait([firstConnect, secondConnect]);

      expect(service.connectionState, SocketConnectionState.connected);

      service.disconnect();
      expect(service.connectionState, SocketConnectionState.disconnected);
      expect(channels.first.sinkClosed, isTrue);

      final reconnectFuture = service.connect();
      await Future<void>.delayed(Duration.zero);
      expect(connectionAttempts, 2);
      expect(service.connectionState, SocketConnectionState.connecting);

      secondReady.complete();
      await reconnectFuture;

      expect(service.connectionState, SocketConnectionState.connected);
      service.dispose();
    },
  );

  test(
    'SocketService emits chat messages and message status updates',
    () async {
      final channel = FakeWebSocketChannel();
      final service = SocketService.test(
        channelFactory: (_) => channel,
        ticketProvider: () async => {'ticket': 'fake-ticket'},
      );

      await service.connect();

      final messageFuture = service.messageStream.first;
      final statusFuture = service.messageStatusStream.first;

      channel.addIncoming(
        jsonEncode({
          'event': 'chat_message',
          'payload': {
            'id': 99,
            'chat': 44,
            'sender': 1,
            'encrypted_text': 'hello',
            'message_type': 'text',
            'created_at': '2026-04-19T12:00:00Z',
          },
        }),
      );
      channel.addIncoming(
        jsonEncode({
          'event': 'message_status',
          'payload': {'message_id': 99, 'chat_id': 44, 'state': 'read'},
        }),
      );

      final message = await messageFuture;
      final status = await statusFuture;

      expect(message.id, '99');
      expect(message.chatId, '44');
      expect(message.isMe, isTrue);
      expect(status.messageId, '99');
      expect(status.chatId, '44');
      expect(status.deliveryState, DeliveryState.read);

      service.dispose();
    },
  );

  test('SocketService ignores heartbeat events', () async {
    final channel = FakeWebSocketChannel();
    final service = SocketService.test(
      channelFactory: (_) => channel,
      ticketProvider: () async => {'ticket': 'fake-ticket'},
    );
    final messages = <Message>[];
    final subscription = service.messageStream.listen(messages.add);

    await service.connect();
    channel.addIncoming(
      jsonEncode({
        'event': 'heartbeat',
        'payload': {'ok': true},
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(messages, isEmpty);

    await subscription.cancel();
    service.dispose();
  });

  test('SocketService emits call events', () async {
    final channel = FakeWebSocketChannel();
    final service = SocketService.test(
      channelFactory: (_) => channel,
      ticketProvider: () async => {'ticket': 'fake-ticket'},
    );

    await service.connect();

    final callEventFuture = service.callEventStream.first;

    channel.addIncoming(
      jsonEncode({
        'event': 'call_invite',
        'type': 'call_invite',
        'payload': {
          'type': 'call_invite',
          'call': {
            'id': 123,
            'call_type': 'audio',
            'status': 'ringing',
            'room_name': 'call_123',
            'caller': {'id': 1, 'name': 'Caller'},
            'receiver': {'id': 2, 'name': 'Receiver'},
            'started_at': '2026-05-21T20:15:00Z',
            'accepted_at': null,
            'ended_at': null,
            'duration_seconds': 0,
          },
        },
      }),
    );

    final callEvent = await callEventFuture;

    expect(callEvent.type, 'call_invite');
    expect(callEvent.call.id, '123');
    expect(callEvent.call.callType.value, 'audio');
    expect(callEvent.call.status, 'ringing');
    expect(callEvent.call.roomName, 'call_123');
    expect(callEvent.call.caller.name, 'Caller');
    expect(callEvent.call.receiver.name, 'Receiver');

    service.dispose();
  });
}
