import '../services/api_service.dart';
import '../utils/url_helper.dart';

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  static MessageStatus fromString(dynamic status) {
    final state = status is Map<String, dynamic> ? status['state'] : status;
    switch (state?.toString()) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      case 'sending':
      case 'pending':
        return MessageStatus.sending;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }
}

class DeliveryState {
  static const pending = MessageStatus.sending;
  static const sending = MessageStatus.sending;
  static const sent = MessageStatus.sent;
  static const delivered = MessageStatus.delivered;
  static const read = MessageStatus.read;
  static const failed = MessageStatus.failed;
}

class Message {
  final String id;
  final String clientUuid;
  final String text;
  final String senderId;
  final DateTime time;
  final bool isMe;
  final String chatId;
  final String? fileUrl;
  final String type;
  final MessageStatus deliveryState;
  final String? replyToId;
  final String? replyToText;
  final String? replyToType;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final bool isDeletedForEveryone;
  final bool isDeletedForMe;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final double? duration;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final Map<String, List<String>> reactions;
  final bool isForwarded;

  Message({
    required this.id,
    required this.clientUuid,
    required this.text,
    required this.senderId,
    required this.time,
    required this.isMe,
    required this.chatId,
    this.type = 'text',
    this.fileUrl,
    this.deliveryState = MessageStatus.sent,
    this.replyToId,
    this.replyToText,
    this.replyToType,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.isDeletedForEveryone = false,
    this.isDeletedForMe = false,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.duration,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.reactions = const {},
    this.isForwarded = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeJson(json);
    final fileUrl = UrlHelper.fixUrl(
      normalizedJson['file_url'] ?? normalizedJson['file'],
    );
    final thumbnailUrl = UrlHelper.fixUrl(
      normalizedJson['thumbnail_url'] ?? normalizedJson['thumbnail'],
    );
    final text =
        normalizedJson['encrypted_text'] ?? normalizedJson['content'] ?? '';
    final type = normalizedJson['message_type'] ?? 'text';

    String senderId = '';
    if (normalizedJson['sender'] is Map) {
      senderId = normalizedJson['sender']['id'].toString();
    } else {
      senderId = normalizedJson['sender'].toString();
    }

    final bool isMe = (ApiService.currentUserId != null && senderId.isNotEmpty)
        ? senderId == ApiService.currentUserId
        : (normalizedJson['is_own_message'] ?? false);

    // Parse reply_to if present
    String? replyToId;
    String? replyToText;
    String? replyToType;
    final replyTo = normalizedJson['reply_to'];
    if (replyTo is Map) {
      replyToId = replyTo['id']?.toString();
      replyToText =
          replyTo['encrypted_text']?.toString() ??
          replyTo['content']?.toString();
      replyToType = replyTo['message_type']?.toString();
    } else if (replyTo != null) {
      replyToId = replyTo.toString();
    }

    return Message(
      id: normalizedJson['id'].toString(),
      clientUuid: (normalizedJson['client_uuid'] ?? normalizedJson['id'])
          .toString(),
      text: text,
      senderId: senderId,
      time: normalizedJson['created_at'] != null
          ? DateTime.parse(normalizedJson['created_at']).toLocal()
          : DateTime.now(),
      isMe: isMe,
      chatId: normalizedJson['chat'].toString(),
      type: type,
      fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
      deliveryState: _parseState(normalizedJson['status']),
      replyToId: replyToId,
      replyToText: replyToText,
      replyToType: replyToType,
      deliveredAt: _parseDate(normalizedJson['delivered_at']),
      readAt: _parseDate(normalizedJson['read_at']),
      editedAt: _parseDate(normalizedJson['edited_at']),
      isDeletedForEveryone: normalizedJson['is_deleted_for_everyone'] == true,
      isDeletedForMe: normalizedJson['is_deleted_for_me'] == true,
      fileName: normalizedJson['file_name']?.toString(),
      fileSize: _parseInt(normalizedJson['file_size']),
      fileType: normalizedJson['file_type']?.toString(),
      duration: _parseDouble(normalizedJson['duration']),
      thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
      width: _parseInt(normalizedJson['width']),
      height: _parseInt(normalizedJson['height']),
      reactions: _parseReactions(normalizedJson['reactions']),
      isForwarded:
          normalizedJson['is_forwarded'] == true ||
          normalizedJson['isForwarded'] == true ||
          normalizedJson['forwarded_from'] != null,
    );
  }

  static MessageStatus _parseState(dynamic status) {
    return MessageStatus.fromString(status);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Map<String, List<String>> _parseReactions(dynamic value) {
    final grouped = <String, List<String>>{};
    if (value is! List) return grouped;
    for (final item in value) {
      if (item is! Map) continue;
      final emoji = item['emoji']?.toString();
      final user = item['user']?.toString();
      if (emoji == null || emoji.isEmpty || user == null) continue;
      grouped.putIfAbsent(emoji, () => []).add(user);
    }
    return grouped;
  }

  Message copyWith({
    String? id,
    String? clientUuid,
    String? text,
    String? senderId,
    DateTime? time,
    bool? isMe,
    String? chatId,
    String? fileUrl,
    String? type,
    MessageStatus? deliveryState,
    String? replyToId,
    String? replyToText,
    String? replyToType,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? editedAt,
    bool? isDeletedForEveryone,
    bool? isDeletedForMe,
    String? fileName,
    int? fileSize,
    String? fileType,
    double? duration,
    String? thumbnailUrl,
    int? width,
    int? height,
    Map<String, List<String>>? reactions,
    bool? isForwarded,
  }) {
    return Message(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      time: time ?? this.time,
      isMe: isMe ?? this.isMe,
      chatId: chatId ?? this.chatId,
      fileUrl: fileUrl ?? this.fileUrl,
      type: type ?? this.type,
      deliveryState: deliveryState ?? this.deliveryState,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToType: replyToType ?? this.replyToType,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      editedAt: editedAt ?? this.editedAt,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      reactions: reactions ?? this.reactions,
      isForwarded: isForwarded ?? this.isForwarded,
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
  final List<String> messageIds;
  final String chatId;
  final MessageStatus deliveryState;
  final DateTime? readAt;

  const MessageStatusUpdate({
    required this.messageId,
    this.messageIds = const [],
    required this.chatId,
    required this.deliveryState,
    this.readAt,
  });

  factory MessageStatusUpdate.fromJson(Map<String, dynamic> json) {
    final normalizedJson =
        (json['payload'] is Map &&
            (json['event'] == 'message_status' ||
                json['event'] == 'status_update' ||
                json['type'] == 'message_status' ||
                json['type'] == 'status_update'))
        ? Map<String, dynamic>.from(json['payload'])
        : Map<String, dynamic>.from(json);

    final ids = normalizedJson['message_ids'] is List
        ? List<String>.from(
            (normalizedJson['message_ids'] as List).map((id) => id.toString()),
          )
        : normalizedJson['messageIds'] is List
        ? List<String>.from(
            (normalizedJson['messageIds'] as List).map((id) => id.toString()),
          )
        : <String>[];
    final fallbackId =
        normalizedJson['message_id']?.toString() ??
        normalizedJson['messageId']?.toString() ??
        (ids.isNotEmpty ? ids.first : '');
    return MessageStatusUpdate(
      messageId: fallbackId,
      messageIds: ids.isEmpty && fallbackId.isNotEmpty ? [fallbackId] : ids,
      chatId:
          normalizedJson['chat_id']?.toString() ??
          normalizedJson['chatId']?.toString() ??
          '',
      deliveryState: Message._parseState(
        normalizedJson['state'] ?? normalizedJson['status'],
      ),
      readAt: DateTime.tryParse(
        (normalizedJson['read_at'] ?? normalizedJson['readAt'] ?? '')
            .toString(),
      )?.toLocal(),
    );
  }
}
