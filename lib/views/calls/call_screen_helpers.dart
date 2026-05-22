import 'package:flutter/material.dart';

import '../../models/call_participant.dart';
import '../../models/call_session.dart';
import '../../services/api_service.dart';

CallParticipant otherParticipant(CallSession call) {
  final currentUserId = ApiService.currentUserId;
  if (currentUserId != null && call.caller.id == currentUserId) {
    return call.receiver;
  }
  return call.caller;
}

Widget callAvatar(CallParticipant participant, {double radius = 44}) {
  final avatarUrl = participant.avatarUrl;
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.white24,
    backgroundImage: avatarUrl != null
        ? NetworkImage(ApiService.mediaUrl(avatarUrl))
        : null,
    child: avatarUrl == null
        ? Icon(Icons.person, size: radius, color: Colors.white70)
        : null,
  );
}

String callStatusText(String status) {
  return switch (status) {
    'ringing' => 'Ringing',
    'accepted' => 'Connecting',
    'active' => 'Connected',
    'rejected' => 'Declined',
    'cancelled' => 'Cancelled',
    'missed' => 'Missed',
    'busy' => 'Busy',
    'failed' => 'Failed',
    'ended' => 'Ended',
    _ => 'Calling',
  };
}

String formatCallDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

String formatHistoryDuration(int seconds) {
  if (seconds <= 0) return '';
  final duration = Duration(seconds: seconds);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  return '${duration.inSeconds}s';
}

class CallCircleButton extends StatelessWidget {
  const CallCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.white24,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
        ),
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}
