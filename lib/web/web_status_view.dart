import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_status.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'web_status_viewer.dart';
import 'web_status_viewmodel.dart';

/// Status/updates panel for the web sidebar.
class WebStatusView extends StatefulWidget {
  const WebStatusView({super.key});

  @override
  State<WebStatusView> createState() => _WebStatusViewState();
}

class _WebStatusViewState extends State<WebStatusView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WebStatusViewModel>().loadStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WebStatusViewModel>();
    return Column(
      children: [
        _header(),
        Expanded(
          child: vm.isLoading && vm.myStatuses.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => vm.loadStatuses(),
                  child: ListView(
                    children: [
                      _myStatusTile(vm),
                      if (vm.unseenGroups.isNotEmpty)
                        _sectionLabel('Recent updates'),
                      ...vm.unseenGroups.map((g) => _groupTile(g)),
                      if (vm.seenGroups.isNotEmpty)
                        _sectionLabel('Viewed updates'),
                      ...vm.seenGroups.map((g) => _groupTile(g)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      height: 60,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Text(
            'Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
            onSelected: (value) {
              if (value == 'text') _createTextStatus();
              if (value == 'photo') _createMediaStatus('image');
              if (value == 'video') _createMediaStatus('video');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'text', child: Text('Text status')),
              PopupMenuItem(value: 'photo', child: Text('Photo status')),
              PopupMenuItem(value: 'video', child: Text('Video status')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _myStatusTile(WebStatusViewModel vm) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.white),
          ),
          if (!vm.hasMyStatus)
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: AppColors.primaryColor,
                child: Icon(Icons.add, size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
      title: const Text(
        'My status',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        vm.hasMyStatus
            ? 'Tap to view your updates'
            : 'Tap the + to add status update',
      ),
      onTap: vm.hasMyStatus
          ? () async {
              final group = await vm.myStatusGroup();
              if (mounted) WebStatusViewer.open(context, group);
            }
          : _createTextStatus,
    );
  }

  Widget _groupTile(StatusGroup group) {
    final owner = group.owner;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: group.hasUnseen ? AppColors.primaryColor : Colors.grey,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[300],
          backgroundImage: (owner.profilePictureUrl?.isNotEmpty ?? false)
              ? CachedNetworkImageProvider(
                  ApiService.mediaUrl(owner.profilePictureUrl),
                )
              : null,
          child: (owner.profilePictureUrl?.isEmpty ?? true)
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
      ),
      title: Text(
        owner.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        group.latestStatusTime != null
            ? DateFormat('hh:mm a').format(group.latestStatusTime!.toLocal())
            : '',
      ),
      onTap: () => WebStatusViewer.open(context, group),
    );
  }

  Future<void> _createMediaStatus(String type) async {
    final vm = context.read<WebStatusViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = type == 'video'
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    try {
      await vm.createMediaStatus(picked, type);
      messenger.showSnackBar(const SnackBar(content: Text('Status posted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _createTextStatus() async {
    const colors = [
      '#6B00D7',
      '#009688',
      '#E91E63',
      '#FF9800',
      '#3F51B5',
      '#4CAF50',
    ];
    final controller = TextEditingController();
    var selectedColor = colors.first;

    final posted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Text status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                width: double.maxFinite,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hex(selectedColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a status',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: colors
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setLocal(() => selectedColor = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: _hex(c),
                          child: selectedColor == c
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );

    final text = controller.text.trim();
    controller.dispose();
    if (posted != true || text.isEmpty) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<WebStatusViewModel>().createTextStatus(
        text,
        backgroundColor: selectedColor,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Status posted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Color _hex(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF6B00D7);
  }
}
