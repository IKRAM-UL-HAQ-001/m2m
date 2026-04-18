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
    final fileUrl = UrlHelper.fixUrl(json['file']);
    final text = json['encrypted_text'] ?? json['content'] ?? '';
    final type = json['message_type'] ?? 'text';
    
    String senderId = '';
    if (json['sender'] is Map) {
      senderId = json['sender']['id'].toString();
    } else {
      senderId = json['sender'].toString();
    }

    // Determine isMe locally to be most reliable for real-time messages
    final bool isMe = (ApiService.currentUserId != null && senderId.isNotEmpty)
        ? (senderId == ApiService.currentUserId)
        : (json['is_own_message'] ?? false);

    return Message(
      id: json['id'].toString(),
      text: text,
      senderId: senderId,
      time: (json['received_at'] != null && !isMe) 
          ? DateTime.parse(json['received_at']).toLocal() 
          : (json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now()),
      isMe: isMe,
      chatId: json['chat'].toString(),
      type: type,
      fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
      isDelivered: json['is_delivered'] ?? false,
      isRead: json['is_read'] ?? false,
    );
  }
}
