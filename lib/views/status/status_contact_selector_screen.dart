import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/contact_user.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class StatusContactSelectorScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ContactUser> allContacts;
  final List<String> preSelected;
  final Color selectionColor;

  const StatusContactSelectorScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.allContacts,
    required this.preSelected,
    required this.selectionColor,
  });

  @override
  State<StatusContactSelectorScreen> createState() =>
      _StatusContactSelectorScreenState();
}

class _StatusContactSelectorScreenState
    extends State<StatusContactSelectorScreen> {
  late Set<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.preSelected);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.toLowerCase();
    final filtered = widget.allContacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.phone.contains(_search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selected.isNotEmpty)
            Container(
              color: widget.selectionColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: widget.selectionColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selected.length} contact'
                    '${_selected.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      color: widget.selectionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final isSelected = _selected.contains(contact.userId);

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: contact.photoUrl != null
                                  ? CachedNetworkImageProvider(
                                      ApiService.mediaUrl(contact.photoUrl!),
                                    )
                                  : null,
                              backgroundColor: AppColors.primaryColor
                                  .withValues(alpha: 0.2),
                              child: contact.photoUrl == null
                                  ? Text(
                                      contact.name.isNotEmpty
                                          ? contact.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            if (isSelected)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: widget.selectionColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          contact.phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(contact.userId);
                            } else {
                              _selected.add(contact.userId);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
