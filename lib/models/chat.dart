import '../utils/url_helper.dart';

class Chat {
  final String id;
  final String receiverId;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final String lastMessageType;
  final String? lastMessageFileUrl;
  final DateTime time;
  final int unreadCount;

  Chat({
    required this.id,
    required this.receiverId,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageType,
    this.lastMessageFileUrl,
    required this.time,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    var otherUser = json['other_user'] ?? {};
    var lastMsg = json['last_message'] ?? {};
    return Chat(
      id: json['id'].toString(),
      receiverId: otherUser['id'].toString(),
      name: otherUser['name'] ?? otherUser['phone_number'] ?? 'Unknown',
      avatarUrl: UrlHelper.fixUrl(otherUser['profile_picture']),
      lastMessage: lastMsg['content'] ?? '',
      lastMessageType: lastMsg['message_type'] ?? 'text',
      lastMessageFileUrl: lastMsg['file_url'],
      time: json['last_activity'] != null ? DateTime.parse(json['last_activity']).toLocal() : DateTime.now(),
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}
