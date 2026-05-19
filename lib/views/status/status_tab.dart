import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_status.dart';
import '../../utils/constants.dart';
import '../../viewmodels/status_viewmodel.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/search_results_list.dart';
import 'create_text_status_screen.dart';
import 'status_viewer_screen.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<StatusViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && !vm.hasMyStatus && vm.unseenGroups.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (widget.searchQuery.isNotEmpty) {
              final groups = [...vm.unseenGroups, ...vm.seenGroups];
              return SearchResultsList<StatusGroup>(
                query: widget.searchQuery,
                allItems: groups,
                getSearchableText: (group) => group.owner.name,
                buildTile: (group, isExact) => ContactStatusTile(
                  statusGroup: group,
                  isSeen: !group.hasUnseen,
                  highlightQuery: widget.searchQuery,
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => vm.loadStatuses(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _sectionHeader('My status'),
                  SliverToBoxAdapter(child: MyStatusTile(viewModel: vm)),
                  _sectionHeader('Recent updates'),
                  if (vm.unseenGroups.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          'No recent updates',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ContactStatusTile(
                          statusGroup: vm.unseenGroups[index],
                        ),
                        childCount: vm.unseenGroups.length,
                      ),
                    ),
                  if (vm.seenGroups.isNotEmpty) ...[
                    _sectionHeader('Viewed updates'),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ContactStatusTile(
                          statusGroup: vm.seenGroups[index],
                          isSeen: true,
                        ),
                        childCount: vm.seenGroups.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 92)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: widget.searchQuery.isEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryColor,
              child: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showAddStatusOptions(context),
            )
          : null,
    );
  }

  SliverToBoxAdapter _sectionHeader(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddStatusOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: const Icon(
                    Icons.text_fields,
                    color: AppColors.primaryColor,
                  ),
                ),
                title: const Text('Text'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateTextStatusScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: const Icon(Icons.photo, color: AppColors.primaryColor),
                ),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndCreateStatus(ImageSource.gallery, 'image');
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryColor,
                  ),
                ),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndCreateStatus(ImageSource.camera, 'image');
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: const Icon(
                    Icons.videocam,
                    color: AppColors.primaryColor,
                  ),
                ),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndCreateStatus(ImageSource.gallery, 'video');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndCreateStatus(ImageSource source, String type) async {
    final picked = type == 'video'
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final vm = context.read<StatusViewModel>();
    try {
      await vm.createMediaStatus(File(picked.path), type);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add status: $e')));
      }
    }
  }
}

class MyStatusTile extends StatelessWidget {
  const MyStatusTile({super.key, required this.viewModel});

  final StatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StatusGroup>(
      future: viewModel.myStatusGroup(),
      builder: (context, snapshot) {
        final group = snapshot.data;
        final hasStatus = viewModel.hasMyStatus && group != null;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: _StatusAvatar(
            imageUrl: group?.owner.profilePictureUrl,
            isSeen: false,
            showRing: hasStatus,
            showAdd: !hasStatus,
          ),
          title: const Text(
            'My status',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            hasStatus
                ? '${group.count} update${group.count == 1 ? '' : 's'} · ${timeAgo(group.latestStatusTime)}'
                : 'Tap to add status update',
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () async {
            if (hasStatus) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatusViewerScreen(statusGroup: group),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTextStatusScreen(),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class ContactStatusTile extends StatelessWidget {
  const ContactStatusTile({
    super.key,
    required this.statusGroup,
    this.isSeen = false,
    this.highlightQuery = '',
  });

  final StatusGroup statusGroup;
  final bool isSeen;
  final String highlightQuery;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _StatusAvatar(
        imageUrl: statusGroup.owner.profilePictureUrl,
        isSeen: isSeen,
        showRing: true,
      ),
      title: buildHighlightedText(
        statusGroup.owner.name,
        highlightQuery,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${statusGroup.count} update${statusGroup.count > 1 ? 's' : ''}'
        ' · ${timeAgo(statusGroup.latestStatusTime)}',
        style: TextStyle(color: isSeen ? Colors.grey : Colors.black87),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatusViewerScreen(statusGroup: statusGroup),
          ),
        );
      },
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  const _StatusAvatar({
    required this.imageUrl,
    required this.isSeen,
    required this.showRing,
    this.showAdd = false,
  });

  final String? imageUrl;
  final bool isSeen;
  final bool showRing;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: showRing && !isSeen
                  ? const LinearGradient(
                      colors: [AppColors.primaryColor, Colors.greenAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: showRing && isSeen ? Colors.grey[400] : Colors.grey[300],
            ),
            child: Padding(
              padding: EdgeInsets.all(showRing ? 2.5 : 0),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
                child: hasImage
                    ? null
                    : Icon(Icons.person, color: Colors.grey[600], size: 30),
              ),
            ),
          ),
          if (showAdd)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

String timeAgo(DateTime? value) {
  if (value == null) return 'Just now';
  final diff = DateTime.now().difference(value);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
