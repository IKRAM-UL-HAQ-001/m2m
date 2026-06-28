import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/call_participant.dart';
import '../../models/call_session.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

/// Whether the current user placed [call] (outgoing) vs received it (incoming).
bool isOutgoingCall(CallSession call) {
  return ApiService.currentUserId != null &&
      call.caller.id == ApiService.currentUserId;
}

/// WhatsApp-style directional indicator for a call-history row: a colored
/// arrow + a short label that distinguishes missed / incoming / outgoing /
/// ongoing. Reds for unanswered, green for a completed call, primary for live.
class CallTypeIndicator {
  const CallTypeIndicator({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

CallTypeIndicator callTypeIndicator(CallSession call) {
  final outgoing = isOutgoingCall(call);
  const green = Color(0xFF4CAF50);

  // A live/active call still in the history feed.
  if (call.isActive &&
      call.status != 'initiated' &&
      call.status != 'ringing') {
    return const CallTypeIndicator(
      icon: Icons.call,
      color: AppColors.primaryColor,
      label: 'Ongoing',
    );
  }

  switch (call.status) {
    case 'missed':
      // An unanswered call the current user received.
      return const CallTypeIndicator(
        icon: Icons.call_missed,
        color: Colors.red,
        label: 'Missed',
      );
    case 'rejected':
      return CallTypeIndicator(
        icon: outgoing ? Icons.call_made : Icons.call_received,
        color: Colors.red,
        label: 'Declined',
      );
    case 'cancelled':
      // Caller hung up before it was answered → "missed" on the callee side,
      // an unanswered outgoing attempt on the caller side.
      return CallTypeIndicator(
        icon: outgoing ? Icons.call_made : Icons.call_missed,
        color: Colors.red,
        label: outgoing ? 'Outgoing' : 'Missed',
      );
    case 'busy':
    case 'failed':
      return CallTypeIndicator(
        icon: outgoing ? Icons.call_made : Icons.call_received,
        color: Colors.red,
        label: call.status == 'busy' ? 'Busy' : 'Failed',
      );
    default:
      // ended / accepted / active answered calls.
      return CallTypeIndicator(
        icon: outgoing ? Icons.call_made : Icons.call_received,
        color: green,
        label: outgoing ? 'Outgoing' : 'Incoming',
      );
  }
}

/// WhatsApp-style relative timestamp for a call row: "Today, 4:30 PM",
/// "Yesterday, 9:05 AM", or "12 Jun, 4:30 PM".
String formatCallTimestamp(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(time.year, time.month, time.day);
  final timeStr = DateFormat('h:mm a').format(time);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return 'Today, $timeStr';
  if (diffDays == 1) return 'Yesterday, $timeStr';
  return '${DateFormat('d MMM').format(time)}, $timeStr';
}

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
    backgroundColor: Colors.grey[300],
    backgroundImage: avatarUrl != null
        ? CachedNetworkImageProvider(
            ApiService.mediaUrl(avatarUrl),
            maxWidth: 250,
            maxHeight: 250,
          )
        : null,
    child: avatarUrl == null
        ? Icon(Icons.person, size: radius, color: Colors.grey[600])
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
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.label,
    this.size = 58,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = backgroundColor ?? Colors.grey.shade100;
    final foreground = iconColor ?? AppColors.primaryColor;
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: onPressed == null
            ? background.withValues(alpha: 0.45)
            : background,
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          tooltip: tooltip ?? label,
          icon: Icon(icon, color: onPressed == null ? Colors.grey : foreground),
          onPressed: onPressed,
        ),
      ),
    );
    if (label == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 8),
        Text(
          label!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
        ),
      ],
    );
  }
}

class CallScreenScaffold extends StatelessWidget {
  const CallScreenScaffold({
    super.key,
    required this.child,
    this.title,
    this.showAppBar = false,
  });

  final Widget child;
  final String? title;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackgroundColor,
        appBar: showAppBar
            ? AppBar(
                title: Text(title ?? ''),
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0.7,
              )
            : null,
        body: SafeArea(child: child),
      ),
    );
  }
}

class CallStatusText extends StatelessWidget {
  const CallStatusText({
    super.key,
    required this.text,
    this.isError = false,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final bool isError;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isError ? Colors.red : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
