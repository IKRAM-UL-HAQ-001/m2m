import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/models/chat.dart';
import 'package:m2m/models/message.dart';

void main() {
  test('Chat.copyWith preserves values and updates selected fields', () {
    final chat = Chat(
      id: '1',
      receiverId: '2',
      name: 'Ayesha',
      phone: '+923001234567',
      about: 'Available',
      avatarUrl: '/media/avatar.jpg',
      lastMessage: 'hello',
      lastMessageType: 'text',
      lastMessageStatus: MessageStatus.sent,
      lastMessageFileUrl: '/media/file.jpg',
      time: DateTime(2026, 5, 24),
      unreadCount: 3,
      isOnline: true,
    );

    final updated = chat.copyWith(
      lastMessage: 'updated',
      unreadCount: 0,
      lastMessageFileUrl: null,
    );

    expect(updated.id, chat.id);
    expect(updated.receiverId, chat.receiverId);
    expect(updated.name, chat.name);
    expect(updated.lastMessage, 'updated');
    expect(updated.unreadCount, 0);
    expect(updated.lastMessageFileUrl, isNull);
    expect(updated.isOnline, isTrue);
  });
}
