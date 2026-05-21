import 'call_session.dart';

class CallLog {
  final String id;
  final CallSession session;
  final bool isMissed;
  final DateTime createdAt;

  const CallLog({
    required this.id,
    required this.session,
    required this.isMissed,
    required this.createdAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: (json['id'] ?? '').toString(),
      session: CallSession.fromJson(
        Map<String, dynamic>.from(json['session'] ?? const {}),
      ),
      isMissed: json['is_missed'] == true || json['isMissed'] == true,
      createdAt:
          DateTime.tryParse(
            (json['created_at'] ?? json['createdAt'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session': session.toJson(),
      'is_missed': isMissed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CallLog copyWith({
    String? id,
    CallSession? session,
    bool? isMissed,
    DateTime? createdAt,
  }) {
    return CallLog(
      id: id ?? this.id,
      session: session ?? this.session,
      isMissed: isMissed ?? this.isMissed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CallLog &&
            other.id == id &&
            other.session == session &&
            other.isMissed == isMissed &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, session, isMissed, createdAt);
}
