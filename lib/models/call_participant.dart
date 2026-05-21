class CallParticipant {
  final String id;
  final String name;
  final String phone;
  final String? avatarUrl;

  const CallParticipant({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    final phone = (json['phone'] ?? json['phone_number'] ?? '').toString();
    final name = (json['name'] ?? json['contact_name'] ?? phone).toString();
    final avatarUrl =
        (json['avatar_url'] ??
                json['avatarUrl'] ??
                json['profile_picture'] ??
                json['profile_photo'])
            ?.toString();

    return CallParticipant(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      name: name.isNotEmpty ? name : phone,
      phone: phone,
      avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'phone': phone, 'avatar_url': avatarUrl};
  }

  CallParticipant copyWith({
    String? id,
    String? name,
    String? phone,
    String? avatarUrl,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CallParticipant &&
            other.id == id &&
            other.name == name &&
            other.phone == phone &&
            other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(id, name, phone, avatarUrl);
}
