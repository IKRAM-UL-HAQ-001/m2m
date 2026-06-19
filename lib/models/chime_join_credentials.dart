/// Credentials returned by the backend `/api/calls/<id>/join/` endpoint
/// when the call provider is Amazon Chime.
///
/// The Flutter side never holds AWS keys — only the opaque meeting/attendee
/// JSON blobs needed by the native Chime SDK.
class ChimeJoinCredentials {
  final int callId;
  final String provider;
  final Map<String, dynamic> meeting;
  final Map<String, dynamic> attendee;

  const ChimeJoinCredentials({
    required this.callId,
    required this.provider,
    required this.meeting,
    required this.attendee,
  });

  /// Parse the backend JSON response.
  ///
  /// Expected shape:
  /// ```json
  /// {
  ///   "call_id": 123,
  ///   "provider": "chime",
  ///   "meeting": { ... },
  ///   "attendee": { ... }
  /// }
  /// ```
  factory ChimeJoinCredentials.fromJson(Map<String, dynamic> json) {
    return ChimeJoinCredentials(
      callId: int.parse(json['call_id'].toString()),
      provider: json['provider']?.toString() ?? 'chime',
      meeting: Map<String, dynamic>.from(json['meeting'] as Map? ?? const {}),
      attendee: Map<String, dynamic>.from(json['attendee'] as Map? ?? const {}),
    );
  }

  /// Serialise to a map suitable for passing over the platform channel.
  Map<String, dynamic> toChannelMap() {
    return {
      'callId': callId,
      'meeting': meeting,
      'attendee': attendee,
    };
  }
}
