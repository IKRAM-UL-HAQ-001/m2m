import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/call_session.dart';
import '../../utils/constants.dart';
import 'call_actions.dart';
import 'call_screen_helpers.dart';

/// Read-only details for a single call-history entry: who, what type, when,
/// how long, and the per-stage timestamps already stored on the session.
/// Tapping a call row in the Calls tab opens this; the audio/video buttons
/// re-dial the same contact.
class CallDetailScreen extends StatelessWidget {
  const CallDetailScreen({super.key, required this.call});

  final CallSession call;

  Future<void> _call(BuildContext context, String callType) async {
    final participant = otherParticipant(call);
    final receiverId = int.tryParse(participant.id);
    if (receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call for this contact')),
      );
      return;
    }
    await startCallAndNavigate(
      context,
      receiverId: receiverId,
      callType: callType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final participant = otherParticipant(call);
    final indicator = callTypeIndicator(call);
    final time = call.createdAt ?? call.startedAt;
    final duration = formatHistoryDuration(call.durationSeconds);

    return CallScreenScaffold(
      title: 'Call info',
      showAppBar: true,
      child: ListView(
        children: [
          const SizedBox(height: 24),
          Center(child: callAvatar(participant, radius: 48)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              participant.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          if (participant.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                participant.phone,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(indicator.icon, size: 18, color: indicator.color),
                const SizedBox(width: 6),
                Text(
                  indicator.label,
                  style: TextStyle(
                    color: indicator.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Re-dial actions.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CallCircleButton(
                icon: Icons.call,
                label: 'Audio',
                onPressed: () => _call(context, 'audio'),
              ),
              const SizedBox(width: 32),
              CallCircleButton(
                icon: Icons.videocam,
                label: 'Video',
                onPressed: () => _call(context, 'video'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),

          _DetailRow(
            icon: call.callType == CallType.video ? Icons.videocam : Icons.call,
            label: 'Call type',
            value: call.callType == CallType.video
                ? 'Video call'
                : 'Audio call',
          ),
          if (time != null)
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('EEEE, d MMM y').format(time),
            ),
          if (time != null)
            _DetailRow(
              icon: Icons.access_time,
              label: 'Time',
              value: DateFormat('h:mm a').format(time),
            ),
          _DetailRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: duration.isEmpty ? '' : duration,
          ),
          if (call.startedAt != null)
            _DetailRow(
              icon: Icons.outbound,
              label: 'Started',
              value: DateFormat('d MMM, h:mm:ss a').format(call.startedAt!),
            ),
          if (call.acceptedAt != null)
            _DetailRow(
              icon: Icons.call_received,
              label: 'Answered',
              value: DateFormat('d MMM, h:mm:ss a').format(call.acceptedAt!),
            ),
          if (call.endedAt != null)
            _DetailRow(
              icon: Icons.call_end,
              label: 'Ended',
              value: DateFormat('d MMM, h:mm:ss a').format(call.endedAt!),
            ),
          if (call.endedBy != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Ended by',
              value: call.endedBy!.id == participant.id
                  ? participant.name
                  : 'You',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryColor),
      title: Text(
        label,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
