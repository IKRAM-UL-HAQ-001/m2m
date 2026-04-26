import '../services/api_service.dart';
import '../utils/url_helper.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime time;
  final bool isMe;
  final String chatId;
  final String? fileUrl;
  final String type;
  final bool isDelivered;
  final bool isRead;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.time,
    required this.isMe,
    required this.chatId,
    this.type = 'text',
    this.fileUrl,
    this.isDelivered = false,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeJson(json);
    final fileUrl = UrlHelper.fixUrl(
      normalizedJson['file'] ?? normalizedJson['file_url'],
    );
    final text = normalizedJson['encrypted_text'] ?? normalizedJson['content'] ?? '';
    final type = normalizedJson['message_type'] ?? 'text';
    
    String senderId = '';
    if (normalizedJson['sender'] is Map) {
      senderId = normalizedJson['sender']['id'].toString();
    } else {
      senderId = normalizedJson['sender'].toString();
    }

    // Determine isMe locally to be most reliable for real-time messages
    final bool isMe = (ApiService.currentUserId != null && senderId.isNotEmpty)
        ? (senderId == ApiService.currentUserId)
        : (normalizedJson['is_own_message'] ?? false);

    return Message(
      id: normalizedJson['id'].toString(),
      text: text,
      senderId: senderId,
      time: (normalizedJson['received_at'] != null && !isMe)
          ? DateTime.parse(normalizedJson['received_at']).toLocal()
          : (normalizedJson['created_at'] != null
                ? DateTime.parse(normalizedJson['created_at']).toLocal()
                : DateTime.now()),
      isMe: isMe,
      chatId: normalizedJson['chat'].toString(),
      type: type,
      fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
      isDelivered: normalizedJson['is_delivered'] ?? false,
      isRead: normalizedJson['is_read'] ?? false,
    );
  }

  Message copyWith({
    String? id,
    String? text,
    String? senderId,
    DateTime? time,
    bool? isMe,
    String? chatId,
    String? fileUrl,
    String? type,
    bool? isDelivered,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      time: time ?? this.time,
      isMe: isMe ?? this.isMe,
      chatId: chatId ?? this.chatId,
      fileUrl: fileUrl ?? this.fileUrl,
      type: type ?? this.type,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
    );
  }

  static Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    if (json['event'] == 'chat_message' && json['payload'] is Map) {
      return Map<String, dynamic>.from(json['payload']);
    }
    if (json['message'] is Map) {
      return Map<String, dynamic>.from(json['message']);
    }
    return Map<String, dynamic>.from(json);
  }
}

class MessageStatusUpdate {
  final String messageId;
  final String chatId;
  final bool isDelivered;
  final bool isRead;

  const MessageStatusUpdate({
    required this.messageId,
    required this.chatId,
    required this.isDelivered,
    required this.isRead,
  });

  factory MessageStatusUpdate.fromJson(Map<String, dynamic> json) {
    final normalizedJson = json['event'] == 'message_status' && json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'])
        : Map<String, dynamic>.from(json);

    return MessageStatusUpdate(
      messageId: normalizedJson['message_id'].toString(),
      chatId: normalizedJson['chat_id'].toString(),
      isDelivered: normalizedJson['is_delivered'] ?? false,
      isRead: normalizedJson['is_read'] ?? false,
    );
  }
}
