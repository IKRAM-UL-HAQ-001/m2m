class CallJoinCredentials {
  final int callId;
  final String serverUrl;
  final String roomName;
  final String token;

  const CallJoinCredentials({
    required this.callId,
    required this.serverUrl,
    required this.roomName,
    required this.token,
  });

  factory CallJoinCredentials.fromJson(Map<String, dynamic> json) {
    return CallJoinCredentials(
      callId: int.parse(json['call_id'].toString()),
      serverUrl: json['server_url']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}
