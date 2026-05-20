import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/contact_user.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'status_contact_selector_screen.dart';

class StatusPrivacySettingsScreen extends StatefulWidget {
  const StatusPrivacySettingsScreen({super.key});

  @override
  State<StatusPrivacySettingsScreen> createState() =>
      _StatusPrivacySettingsScreenState();
}

class _StatusPrivacySettingsScreenState
    extends State<StatusPrivacySettingsScreen> {
  final ApiService _apiService = ApiService();

  String _myStatusPrivacy = 'all_contacts';
  List<ContactUser> _exceptContacts = [];
  List<ContactUser> _onlyContacts = [];
  List<ContactUser> _allContacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final privacy = await _apiService.getStatusPrivacy();
      final contacts = await _apiService.getAppContacts();
      final exceptIds = List<String>.from(
        (privacy['except_user_ids'] ?? const []).map((id) => id.toString()),
      );
      final onlyIds = List<String>.from(
        (privacy['only_user_ids'] ?? const []).map((id) => id.toString()),
      );

      if (!mounted) return;
      setState(() {
        _myStatusPrivacy = privacy['privacy']?.toString() ?? 'all_contacts';
        _allContacts = contacts;
        _exceptContacts = contacts
            .where((contact) => exceptIds.contains(contact.userId))
            .toList();
        _onlyContacts = contacts
            .where((contact) => onlyIds.contains(contact.userId))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load status privacy';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text(
          'Status privacy',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'MY STATUS',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Text(
            'Choose who can see your status updates.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          color: Colors.white,
          child: RadioGroup<String>(
            groupValue: _myStatusPrivacy,
            onChanged: _handlePrivacyChanged,
            child: Column(
              children: [
                const RadioListTile<String>(
                  value: 'all_contacts',
                  activeColor: AppColors.primaryColor,
                  title: Text(
                    'All contacts',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Share with all your contacts'),
                ),
                const Divider(height: 1, indent: 56),
                RadioListTile<String>(
                  value: 'except',
                  activeColor: AppColors.primaryColor,
                  title: const Text(
                    'All contacts except...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _myStatusPrivacy == 'except' && _exceptContacts.isNotEmpty
                        ? '${_exceptContacts.length} contact'
                              '${_exceptContacts.length == 1 ? '' : 's'} excluded'
                        : 'Hide status from specific contacts',
                  ),
                ),
                if (_myStatusPrivacy == 'except' && _exceptContacts.isNotEmpty)
                  _ContactChipRow(
                    contacts: _exceptContacts,
                    color: Colors.red.shade100,
                    chipColor: Colors.red.shade200,
                    onEditTap: _selectExceptContacts,
                    label: 'Hidden from:',
                  ),
                const Divider(height: 1, indent: 56),
                RadioListTile<String>(
                  value: 'only',
                  activeColor: AppColors.primaryColor,
                  title: const Text(
                    'Only share with...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _myStatusPrivacy == 'only' && _onlyContacts.isNotEmpty
                        ? '${_onlyContacts.length} contact'
                              '${_onlyContacts.length == 1 ? '' : 's'} selected'
                        : 'Share only with specific contacts',
                  ),
                ),
                if (_myStatusPrivacy == 'only' && _onlyContacts.isNotEmpty)
                  _ContactChipRow(
                    contacts: _onlyContacts,
                    color: Colors.green.shade100,
                    chipColor: Colors.green.shade200,
                    onEditTap: _selectOnlyContacts,
                    label: 'Visible to:',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _handlePrivacyChanged(String? value) async {
    if (value == null || value == _myStatusPrivacy) return;
    if (value == 'all_contacts') {
      setState(() => _myStatusPrivacy = value);
      await _savePrivacy();
      return;
    }

    setState(() => _myStatusPrivacy = value);
    if (value == 'except') {
      await _selectExceptContacts();
    } else {
      await _selectOnlyContacts();
    }
  }

  Future<void> _selectExceptContacts() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StatusContactSelectorScreen(
          title: 'Hide status from...',
          subtitle: 'Select contacts who will not see your status',
          allContacts: _allContacts,
          preSelected: _exceptContacts
              .map((contact) => contact.userId)
              .toList(),
          selectionColor: Colors.red,
        ),
      ),
    );

    if (selected == null) return;
    setState(() {
      _exceptContacts = _allContacts
          .where((contact) => selected.contains(contact.userId))
          .toList();
      if (_exceptContacts.isEmpty) {
        _myStatusPrivacy = 'all_contacts';
      }
    });
    await _savePrivacy();
  }

  Future<void> _selectOnlyContacts() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StatusContactSelectorScreen(
          title: 'Share status with...',
          subtitle: 'Only these contacts will see your status',
          allContacts: _allContacts,
          preSelected: _onlyContacts.map((contact) => contact.userId).toList(),
          selectionColor: AppColors.primaryColor,
        ),
      ),
    );

    if (selected == null) return;
    setState(() {
      _onlyContacts = _allContacts
          .where((contact) => selected.contains(contact.userId))
          .toList();
      if (_onlyContacts.isEmpty) {
        _myStatusPrivacy = 'all_contacts';
      }
    });
    await _savePrivacy();
  }

  Future<void> _savePrivacy() async {
    try {
      await _apiService.updateStatusPrivacy(
        privacy: _myStatusPrivacy,
        exceptUserIds: _exceptContacts
            .map((contact) => contact.userId)
            .toList(),
        onlyUserIds: _onlyContacts.map((contact) => contact.userId).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save status privacy')),
      );
    }
  }
}

class _ContactChipRow extends StatelessWidget {
  final List<ContactUser> contacts;
  final Color color;
  final Color chipColor;
  final VoidCallback onEditTap;
  final String label;

  const _ContactChipRow({
    required this.contacts,
    required this.color,
    required this.chipColor,
    required this.onEditTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final chips = contacts.take(10).map((contact) {
      return Chip(
        backgroundColor: chipColor,
        avatar: CircleAvatar(
          radius: 12,
          backgroundImage: contact.photoUrl != null
              ? CachedNetworkImageProvider(
                  ApiService.mediaUrl(contact.photoUrl!),
                )
              : null,
          child: contact.photoUrl == null
              ? Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 10),
                )
              : null,
        ),
        label: Text(contact.name, style: const TextStyle(fontSize: 12)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();

    if (contacts.length > 10) {
      chips.add(
        Chip(
          label: Text(
            '+${contacts.length - 10} more',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      color: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEditTap,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}
