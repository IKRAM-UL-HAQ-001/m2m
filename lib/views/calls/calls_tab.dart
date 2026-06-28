import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/call_participant.dart';
import '../../models/call_session.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/call_viewmodel.dart';
import 'call_actions.dart';
import 'call_detail_screen.dart';
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
            color: AppColors.scaffoldBackgroundColor,
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

  // Tapping a row opens the call details (WhatsApp behaviour). The trailing
  // call/video button is what re-dials the contact.
  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CallDetailScreen(call: call)),
    );
  }

  Future<void> _dial(BuildContext context) async {
    final participant = _historyParticipant(call);
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
      callType: call.callType.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final participant = _historyParticipant(call);
    final indicator = callTypeIndicator(call);
    final duration = formatHistoryDuration(call.durationSeconds);
    final time = call.createdAt ?? call.startedAt ?? DateTime.now();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () => _openDetails(context),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.grey[300],
        backgroundImage: participant.avatarUrl != null
            ? CachedNetworkImageProvider(
                ApiService.mediaUrl(participant.avatarUrl),
                maxWidth: 150,
                maxHeight: 150,
              )
            : null,
        child: participant.avatarUrl == null
            ? Icon(Icons.person, color: Colors.grey[600])
            : null,
      ),
      title: Text(
        participant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: indicator.color == Colors.red ? Colors.red : null,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(indicator.icon, size: 15, color: indicator.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              [
                indicator.label,
                if (duration.isNotEmpty) duration,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCallTimestamp(time),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          IconButton(
            tooltip: call.callType == CallType.video
                ? 'Video call'
                : 'Audio call',
            icon: Icon(
              call.callType == CallType.video ? Icons.videocam : Icons.call,
              color: AppColors.primaryColor,
            ),
            onPressed: () => _dial(context),
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
      color: AppColors.scaffoldBackgroundColor,
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
