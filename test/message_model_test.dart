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
      'chat': 55,
      'sender': 1,
      'encrypted_text': 'hello',
      'message_type': 'text',
      'created_at': '2026-04-19T12:00:00Z',
      'is_delivered': true,
      'is_read': false,
    });

    expect(message.id, '10');
    expect(message.chatId, '55');
    expect(message.text, 'hello');
    expect(message.isMe, isTrue);
    expect(message.isDelivered, isTrue);
    expect(message.isRead, isFalse);
  });

  test('Message.fromJson parses raw socket wrappers', () {
    final message = Message.fromJson({
      'message': {
        'id': 11,
        'chat': 77,
        'sender': 2,
        'encrypted_text': 'socket raw',
        'message_type': 'text',
        'created_at': '2026-04-19T12:01:00Z',
      },
    });

    expect(message.id, '11');
    expect(message.chatId, '77');
    expect(message.text, 'socket raw');
    expect(message.isMe, isFalse);
  });

  test('Message.fromJson parses enveloped chat_message payloads', () {
    final message = Message.fromJson({
      'event': 'chat_message',
      'payload': {
        'id': 12,
        'chat': 88,
        'sender': 1,
        'encrypted_text': '[File]',
        'message_type': 'audio',
        'file': '/media/chat_files/voice.m4a',
        'created_at': '2026-04-19T12:02:00Z',
      },
    });

    expect(message.id, '12');
    expect(message.type, 'audio');
    expect(message.isMe, isTrue);
    expect(message.fileUrl, contains('chat_files/voice.m4a'));
  });
}
