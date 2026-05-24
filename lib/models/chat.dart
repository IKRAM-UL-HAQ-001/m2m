import 'message.dart';
import '../utils/url_helper.dart';

class Chat {
  final String id;
  final String receiverId;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl;
  final String lastMessage;
  final String lastMessageType;
  final MessageStatus lastMessageStatus;
  final String? lastMessageFileUrl;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;

  Chat({
    required this.id,
    required this.receiverId,
    required this.name,
    required this.phone,
    required this.about,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageType,
    this.lastMessageStatus = MessageStatus.sent,
    this.lastMessageFileUrl,
    required this.time,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    var otherUser = json['other_user'] ?? {};
    var lastMsg = json['last_message'] ?? {};
    return Chat(
      id: json['id'].toString(),
      receiverId: otherUser['id'].toString(),
      name:
          otherUser['contact_name'] ??
          otherUser['name'] ??
          otherUser['phone'] ??
          otherUser['phone_number'] ??
          'Unknown',
      phone: (otherUser['phone'] ?? otherUser['phone_number'] ?? '').toString(),
      about: (otherUser['about'] ?? 'Available').toString(),
      avatarUrl: UrlHelper.fixUrl(
        otherUser['profile_photo'] ?? otherUser['profile_picture'],
      ),
      lastMessage: lastMsg['content'] ?? '',
      lastMessageType: lastMsg['message_type'] ?? 'text',
      lastMessageStatus: MessageStatus.fromString(
        json['last_message_status'] ?? lastMsg['status'],
      ),
      lastMessageFileUrl: lastMsg['file_url'],
      time: json['last_activity'] != null
          ? DateTime.parse(json['last_activity']).toLocal()
          : DateTime.now(),
      unreadCount: json['unread_count'] ?? 0,
      isOnline: (json['presence']?['is_online'] ?? false) == true,
    );
  }

  Chat copyWith({
    String? id,
    String? receiverId,
    String? name,
    String? phone,
    String? about,
    String? avatarUrl,
    String? lastMessage,
    String? lastMessageType,
    MessageStatus? lastMessageStatus,
    Object? lastMessageFileUrl = _sentinel,
    DateTime? time,
    int? unreadCount,
    bool? isOnline,
  }) {
    return Chat(
      id: id ?? this.id,
      receiverId: receiverId ?? this.receiverId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageFileUrl: identical(lastMessageFileUrl, _sentinel)
          ? this.lastMessageFileUrl
          : lastMessageFileUrl as String?,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

const Object _sentinel = Object();
