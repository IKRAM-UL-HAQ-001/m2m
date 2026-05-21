import 'call_participant.dart';

enum CallType {
  audio,
  video;

  static CallType fromString(dynamic value) {
    return value?.toString() == 'video' ? CallType.video : CallType.audio;
  }

  String get value => name;
}

class CallSession {
  final String id;
  final String uuid;
  final CallParticipant caller;
  final CallParticipant receiver;
  final CallType callType;
  final String status;
  final String roomName;
  final DateTime? startedAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const CallSession({
    required this.id,
    required this.uuid,
    required this.caller,
    required this.receiver,
    required this.callType,
    required this.status,
    required this.roomName,
    this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: (json['id'] ?? '').toString(),
      uuid: (json['uuid'] ?? '').toString(),
      caller: CallParticipant.fromJson(
        Map<String, dynamic>.from(json['caller'] ?? const {}),
      ),
      receiver: CallParticipant.fromJson(
        Map<String, dynamic>.from(json['receiver'] ?? const {}),
      ),
      callType: CallType.fromString(json['call_type'] ?? json['callType']),
      status: (json['status'] ?? '').toString(),
      roomName: (json['room_name'] ?? json['roomName'] ?? '').toString(),
      startedAt: _parseDate(json['started_at'] ?? json['startedAt']),
      acceptedAt: _parseDate(json['accepted_at'] ?? json['acceptedAt']),
      endedAt: _parseDate(json['ended_at'] ?? json['endedAt']),
      durationSeconds: _parseInt(
        json['duration_seconds'] ?? json['durationSeconds'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'caller': caller.toJson(),
      'receiver': receiver.toJson(),
      'call_type': callType.value,
      'status': status,
      'room_name': roomName,
      'started_at': startedAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  CallSession copyWith({
    String? id,
    String? uuid,
    CallParticipant? caller,
    CallParticipant? receiver,
    CallType? callType,
    String? status,
    String? roomName,
    DateTime? startedAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallSession(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      caller: caller ?? this.caller,
      receiver: receiver ?? this.receiver,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      startedAt: startedAt ?? this.startedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CallSession &&
            other.id == id &&
            other.uuid == uuid &&
            other.caller == caller &&
            other.receiver == receiver &&
            other.callType == callType &&
            other.status == status &&
            other.roomName == roomName &&
            other.startedAt == startedAt &&
            other.acceptedAt == acceptedAt &&
            other.endedAt == endedAt &&
            other.durationSeconds == durationSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      uuid,
      caller,
      receiver,
      callType,
      status,
      roomName,
      startedAt,
      acceptedAt,
      endedAt,
      durationSeconds,
    );
  }
}
