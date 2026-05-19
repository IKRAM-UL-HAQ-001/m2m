class SharedMedia {
  final String id;
  final String fileUrl;
  final String? thumbnailUrl;
  final String fileName;
  final int? fileSize;
  final String fileType;
  final String messageType;
  final double? duration;
  final bool isVoiceMessage;
  final DateTime sentAt;

  const SharedMedia({
    required this.id,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.fileName,
    this.fileSize,
    required this.fileType,
    required this.messageType,
    this.duration,
    required this.isVoiceMessage,
    required this.sentAt,
  });

  factory SharedMedia.fromJson(Map<String, dynamic> json) {
    final fileUrl = (json['file_url'] ?? '').toString();
    final fileName = (json['file_name'] ?? '').toString();
    return SharedMedia(
      id: json['id'].toString(),
      fileUrl: fileUrl,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      fileName: fileName.isNotEmpty ? fileName : fileUrl.split('/').last,
      fileSize: int.tryParse((json['file_size'] ?? '').toString()),
      fileType: (json['file_type'] ?? '').toString(),
      messageType: (json['message_type'] ?? '').toString(),
      duration: double.tryParse((json['duration'] ?? '').toString()),
      isVoiceMessage: json['is_voice_message'] == true,
      sentAt:
          DateTime.tryParse((json['sent_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
    );
  }

  String get extension {
    final source = fileName.contains('.') ? fileName : fileUrl;
    final parts = source.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : fileType;
  }
}
