import 'chime_join_credentials.dart';

/// Unified credentials returned by the backend `/api/calls/<id>/join/`.
///
/// The [provider] field determines which media SDK to use:
/// - `"chime"` → Amazon Chime SDK (via [ChimeJoinCredentials])
/// - `"livekit"` → LiveKit (legacy, for backward compatibility during migration)
class CallJoinCredentials {
  final int callId;
  final String provider;

  // LiveKit fields (legacy)
  final String serverUrl;
  final String roomName;
  final String token;

  // Chime fields
  final ChimeJoinCredentials? chimeCredentials;

  const CallJoinCredentials({
    required this.callId,
    required this.provider,
    this.serverUrl = '',
    this.roomName = '',
    this.token = '',
    this.chimeCredentials,
  });

  bool get isChime => provider == 'chime';
  bool get isLiveKit => provider == 'livekit';

  factory CallJoinCredentials.fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString() ?? 'livekit';

    if (provider == 'chime') {
      return CallJoinCredentials(
        callId: int.parse(json['call_id'].toString()),
        provider: provider,
        chimeCredentials: ChimeJoinCredentials.fromJson(json),
      );
    }

    // Legacy LiveKit format
    return CallJoinCredentials(
      callId: int.parse(json['call_id'].toString()),
      provider: provider,
      serverUrl: json['server_url']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}
