import 'call_session.dart';

class CallEvent {
  final String type;
  final CallSession call;
  final Map<String, dynamic>? rawPayload;

  const CallEvent({required this.type, required this.call, this.rawPayload});

  factory CallEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'])
        : json;
    final callPayload = payload['call'] is Map
        ? Map<String, dynamic>.from(payload['call'])
        : payload;

    return CallEvent(
      type: (payload['type'] ?? json['type'] ?? json['event'] ?? '').toString(),
      call: CallSession.fromJson(callPayload),
      rawPayload: payload,
    );
  }
}
