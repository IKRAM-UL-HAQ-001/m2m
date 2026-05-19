import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../viewmodels/status_viewmodel.dart';

class CreateTextStatusScreen extends StatefulWidget {
  const CreateTextStatusScreen({super.key});

  @override
  State<CreateTextStatusScreen> createState() => _CreateTextStatusScreenState();
}

class _CreateTextStatusScreenState extends State<CreateTextStatusScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Color> _backgrounds = const [
    AppColors.primaryColor,
    Color(0xFF128C7E),
    Color(0xFF25D366),
    Color(0xFF455A64),
    Color(0xFFE91E63),
  ];
  int _colorIndex = 0;
  bool _isPosting = false;
  String _privacy = 'all_contacts';
  final Map<String, Map<String, dynamic>> _selectedContacts = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = _backgrounds[_colorIndex];
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.white),
            onPressed: () {
              setState(() {
                _colorIndex = (_colorIndex + 1) % _backgrounds.length;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a status',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 22,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _showPrivacyPicker,
                icon: Icon(_privacyIcon(_privacy), size: 18),
                label: Text(_privacyLabel),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                onPressed: _canPost ? _postStatus : null,
                child: _isPosting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: background),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canPost => !_isPosting && _controller.text.trim().isNotEmpty;

  String get _privacyLabel {
    final count = _selectedContacts.length;
    switch (_privacy) {
      case 'except':
        return count == 0
            ? 'My contacts except...'
            : 'Except ${_selectedContactLabel(count)}';
      case 'only':
        return count == 0
            ? 'Only share with...'
            : 'Only ${_selectedContactLabel(count)}';
      default:
        return 'My contacts';
    }
  }

  String _selectedContactLabel(int count) {
    final names = _selectedContacts.values.map(_displaySelectedName).toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]}, ${names[1]}';
    return '$count contacts';
  }

  String _displaySelectedName(Map<String, dynamic> contact) {
    final contactName = contact['contact_name']?.toString() ?? '';
    if (contactName.isNotEmpty) return contactName;
    final name = contact['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return (contact['phone'] ?? contact['phone_number'] ?? 'contact')
        .toString();
  }

  Future<void> _postStatus() async {
    setState(() => _isPosting = true);
    final color = _backgrounds[_colorIndex];
    final colorValue = '#${color.toARGB32().toRadixString(16).substring(2)}';
    try {
      await context.read<StatusViewModel>().createTextStatus(
        _controller.text.trim(),
        backgroundColor: colorValue,
        privacy: _privacy,
        userIds: _selectedContacts.keys.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  IconData _privacyIcon(String value) {
    switch (value) {
      case 'except':
        return Icons.visibility_off_outlined;
      case 'only':
        return Icons.lock_outline;
      default:
        return Icons.groups_outlined;
    }
  }

  Future<void> _showPrivacyPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const ListTile(
              title: Text(
                'Status privacy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _privacyOptionTile(
              context,
              value: 'all_contacts',
              icon: Icons.groups_outlined,
              title: 'My contacts',
              subtitle: 'Share with all saved contacts',
            ),
            _privacyOptionTile(
              context,
              value: 'except',
              icon: Icons.visibility_off_outlined,
              title: 'My contacts except...',
              subtitle: 'Hide from selected contacts',
            ),
            _privacyOptionTile(
              context,
              value: 'only',
              icon: Icons.lock_outline,
              title: 'Only share with...',
              subtitle: 'Show only to selected contacts',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'all_contacts') {
      setState(() {
        _privacy = choice;
        _selectedContacts.clear();
      });
      return;
    }
    final selected = await Navigator.push<Map<String, Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => StatusPrivacyContactSelector(
          title: choice == 'except'
              ? 'Hide status from'
              : 'Only share status with',
          initialSelected: _privacy == choice ? _selectedContacts : const {},
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _privacy = choice;
      _selectedContacts
        ..clear()
        ..addAll(selected);
    });
  }

  Widget _privacyOptionTile(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _privacy == value;
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primaryColor)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class StatusPrivacyContactSelector extends StatefulWidget {
  const StatusPrivacyContactSelector({
    super.key,
    required this.title,
    required this.initialSelected,
  });

  final String title;
  final Map<String, Map<String, dynamic>> initialSelected;

  @override
  State<StatusPrivacyContactSelector> createState() =>
      _StatusPrivacyContactSelectorState();
}

class _StatusPrivacyContactSelectorState
    extends State<StatusPrivacyContactSelector> {
  final ApiService _apiService = ApiService();
  final Map<String, Map<String, dynamic>> _selected = {};
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _apiService.fetchUsers();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final filtered = _contacts.where((contact) {
      final name = _displayName(contact).toLowerCase();
      final phone = (contact['phone'] ?? contact['phone_number'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(
              'Done (${_selected.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final id = contact['id'].toString();
                      final selected = _selected.containsKey(id);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            _displayName(contact).isEmpty
                                ? '?'
                                : _displayName(contact)[0].toUpperCase(),
                          ),
                        ),
                        title: Text(_displayName(contact)),
                        subtitle: Text(
                          (contact['phone'] ?? contact['phone_number'] ?? '')
                              .toString(),
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? AppColors.primaryColor
                              : Colors.grey,
                        ),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(id);
                            } else {
                              _selected[id] = contact;
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

  String _displayName(Map<String, dynamic> contact) {
    final contactName = contact['contact_name']?.toString() ?? '';
    if (contactName.isNotEmpty) return contactName;
    final name = contact['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return (contact['phone'] ?? contact['phone_number'] ?? 'Unknown')
        .toString();
  }
}
