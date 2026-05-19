class UserStatus {
  final String id;
  final String statusType;
  final String textContent;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String backgroundColor;
  final int fontSize;
  final double? duration;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;
  final int viewCount;

  const UserStatus({
    required this.id,
    required this.statusType,
    required this.textContent,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.backgroundColor,
    required this.fontSize,
    this.duration,
    required this.createdAt,
    required this.expiresAt,
    required this.isViewed,
    required this.viewCount,
  });

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    return UserStatus(
      id: json['id'].toString(),
      statusType: (json['status_type'] ?? 'text').toString(),
      textContent: (json['text_content'] ?? '').toString(),
      mediaUrl: json['media_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      backgroundColor: (json['background_color'] ?? '#128C7E').toString(),
      fontSize: int.tryParse((json['font_size'] ?? 28).toString()) ?? 28,
      duration: double.tryParse((json['duration'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()) ??
          DateTime.now(),
      isViewed: json['is_viewed'] == true,
      viewCount: int.tryParse((json['view_count'] ?? 0).toString()) ?? 0,
    );
  }
}

class StatusOwner {
  final String id;
  final String name;
  final String? profilePictureUrl;

  const StatusOwner({
    required this.id,
    required this.name,
    this.profilePictureUrl,
  });

  factory StatusOwner.fromJson(Map<String, dynamic> json) {
    return StatusOwner(
      id: json['id'].toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      profilePictureUrl:
          (json['profile_picture_url'] ?? json['profile_photo'])?.toString(),
    );
  }
}

class StatusGroup {
  final StatusOwner owner;
  final List<UserStatus> statuses;
  final int unviewedCount;
  final DateTime? latestStatusTime;
  final bool isMine;

  const StatusGroup({
    required this.owner,
    required this.statuses,
    required this.unviewedCount,
    required this.latestStatusTime,
    this.isMine = false,
  });

  int get count => statuses.length;
  bool get hasUnseen => unviewedCount > 0;
  UserStatus? get latestStatus => statuses.isEmpty ? null : statuses.first;

  factory StatusGroup.fromJson(Map<String, dynamic> json) {
    final statuses = List<dynamic>.from(json['statuses'] ?? const [])
        .map((item) => UserStatus.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return StatusGroup(
      owner: StatusOwner.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
      statuses: statuses,
      unviewedCount: int.tryParse((json['unviewed_count'] ?? 0).toString()) ?? 0,
      latestStatusTime:
          DateTime.tryParse((json['latest_status_time'] ?? '').toString()),
    );
  }

  StatusGroup copyWith({
    List<UserStatus>? statuses,
    int? unviewedCount,
    DateTime? latestStatusTime,
  }) {
    return StatusGroup(
      owner: owner,
      statuses: statuses ?? this.statuses,
      unviewedCount: unviewedCount ?? this.unviewedCount,
      latestStatusTime: latestStatusTime ?? this.latestStatusTime,
      isMine: isMine,
    );
  }
}

class StatusViewer {
  final String id;
  final String name;
  final String? pictureUrl;
  final DateTime viewedAt;

  const StatusViewer({
    required this.id,
    required this.name,
    this.pictureUrl,
    required this.viewedAt,
  });

  factory StatusViewer.fromJson(Map<String, dynamic> json) {
    return StatusViewer(
      id: json['viewer_id'].toString(),
      name: (json['viewer_name'] ?? 'Unknown').toString(),
      pictureUrl: json['viewer_picture_url']?.toString(),
      viewedAt: DateTime.tryParse((json['viewed_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
