import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/call_participant.dart';
import '../../models/call_session.dart';
import '../../services/api_service.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'call_screen_helpers.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<CallViewModel>().loadCallHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final query = widget.searchQuery.toLowerCase();
        final calls = vm.callHistory.where((call) {
          final participant = _historyParticipant(call);
          return query.isEmpty ||
              participant.name.toLowerCase().contains(query) ||
              call.status.toLowerCase().contains(query);
        }).toList();

        if (vm.isLoadingHistory && calls.isEmpty) {
          return const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (calls.isEmpty) {
          return _EmptyCallsState(searching: widget.searchQuery.isNotEmpty);
        }

        return RefreshIndicator(
          onRefresh: vm.loadCallHistory,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: calls.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              return _CallHistoryTile(call: calls[index]);
            },
          ),
        );
      },
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  const _CallHistoryTile({required this.call});

  final CallSession call;

  @override
  Widget build(BuildContext context) {
    final participant = _historyParticipant(call);
    final isOutgoing = ApiService.currentUserId == call.caller.id;
    final duration = formatHistoryDuration(call.durationSeconds);
    final time = call.createdAt ?? call.startedAt ?? DateTime.now();
    final statusColor = switch (call.status) {
      'missed' || 'rejected' || 'failed' => Colors.red,
      'ended' => Colors.green,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE7F6),
        backgroundImage: participant.avatarUrl != null
            ? NetworkImage(ApiService.mediaUrl(participant.avatarUrl))
            : null,
        child: participant.avatarUrl == null
            ? const Icon(Icons.person, color: Color(0xFF6B00D7))
            : null,
      ),
      title: Text(
        participant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Icon(
            isOutgoing ? Icons.call_made : Icons.call_received,
            size: 15,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              [
                callStatusText(call.status),
                if (duration.isNotEmpty) duration,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            call.callType == CallType.video ? Icons.videocam : Icons.call,
            color: const Color(0xFF6B00D7),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d').format(time),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyCallsState extends StatelessWidget {
  const _EmptyCallsState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.call_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 18),
            Text(
              searching ? 'No calls found' : 'No recent calls',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

CallParticipant _historyParticipant(CallSession call) {
  return ApiService.currentUserId == call.caller.id
      ? call.receiver
      : call.caller;
}
