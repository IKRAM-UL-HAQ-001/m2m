class ContactUser {
  final String userId;
  final String name;
  final String phone;
  final String? photoUrl;

  const ContactUser({
    required this.userId,
    required this.name,
    required this.phone,
    this.photoUrl,
  });

  factory ContactUser.fromJson(Map<String, dynamic> json) {
    final name = (json['contact_name'] ?? json['name'] ?? json['phone'] ?? '')
        .toString();
    final phone = (json['phone'] ?? json['phone_number'] ?? '').toString();
    final photoUrl = (json['profile_photo'] ?? json['profile_picture'])
        ?.toString();

    return ContactUser(
      userId: (json['id'] ?? json['user_id']).toString(),
      name: name.isNotEmpty ? name : phone,
      phone: phone,
      photoUrl: photoUrl != null && photoUrl.isNotEmpty ? photoUrl : null,
    );
  }
}
