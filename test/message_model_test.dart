import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/models/message.dart';
import 'package:m2m/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.currentUserId = '1';
  });

  test('Message.fromJson parses REST payloads', () {
    final message = Message.fromJson({
      'id': 10,
      'client_uuid': 'uuid-10',
      'chat': 55,
      'sender': 1,
      'encrypted_text': 'hello',
      'message_type': 'text',
      'created_at': '2026-04-19T12:00:00Z',
      'status': {'state': 'delivered'},
    });

    expect(message.id, '10');
    expect(message.chatId, '55');
    expect(message.text, 'hello');
    expect(message.clientUuid, 'uuid-10');
    expect(message.isMe, isTrue);
    expect(message.deliveryState, DeliveryState.delivered);
  });

  test('Message.fromJson parses enveloped payloads', () {
    final message = Message.fromJson({
      'event': 'chat_message',
      'payload': {
        'id': 12,
        'client_uuid': 'uuid-12',
        'chat': 88,
        'sender': 1,
        'encrypted_text': '[File]',
        'message_type': 'audio',
        'file': '/media/chat_files/voice.ogg',
        'created_at': '2026-04-19T12:02:00Z',
        'status': {'state': 'read'},
      },
    });

    expect(message.id, '12');
    expect(message.type, 'audio');
    expect(message.isMe, isTrue);
    expect(message.deliveryState, DeliveryState.read);
    expect(message.fileUrl, contains('chat_files/voice.ogg'));
  });
}
