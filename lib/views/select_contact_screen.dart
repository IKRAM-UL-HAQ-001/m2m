import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/url_helper.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'chat_detail_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _onAppContacts = [];
  List<Map<String, dynamic>> _offAppContacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.syncContacts();
      if (!mounted) return;
      setState(() {
        _onAppContacts = result.onAppContacts;
        _offAppContacts = result.offAppContacts;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not sync contacts';
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteContact(Map<String, dynamic> contact) async {
    final phone = contact['phone']?.toString() ?? '';
    final contactName = contact['contact_name']?.toString() ?? '';
    const body = "Hey! I'm using M2M Messenger. Join me here: [app link]";

    try {
      await _apiService.inviteContact(phone, contactName);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
    }
  }

  String _displayName(Map<String, dynamic> contact) {
    final contactName = contact['contact_name']?.toString() ?? '';
    if (contactName.isNotEmpty) return contactName;
    final profileName = contact['name']?.toString() ?? '';
    if (profileName.isNotEmpty) return profileName;
    return contact['phone']?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final totalContacts = _onAppContacts.length + _offAppContacts.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select contact',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              '$totalContacts contacts',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
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
                onPressed: _loadUsers,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primaryColor,
              child: Icon(Icons.person_add, color: Colors.white),
            ),
            title: const Text(
              'New contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Refresh your phone contacts'),
            trailing: const Icon(Icons.refresh, color: Colors.grey),
            onTap: _loadUsers,
          ),
          _sectionHeader('Contacts on M2M', _onAppContacts.length),
          if (_onAppContacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No saved contacts are on M2M yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._onAppContacts.map(_buildOnAppContact),
          _sectionHeader('Invite to M2M', _offAppContacts.length),
          if (_offAppContacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No contacts to invite.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._offAppContacts.map(_buildInviteContact),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '$title - $count',
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildOnAppContact(Map<String, dynamic> user) {
    final profilePic = UrlHelper.fixUrl(user['profile_photo']);
    return ListTile(
      onTap: () async {
        final chat = Chat(
          id: "new_${user['id']}",
          receiverId: user['id'].toString(),
          name: _displayName(user),
          phone: (user['phone'] ?? user['phone_number'] ?? '').toString(),
          about: (user['about'] ?? 'Available').toString(),
          avatarUrl: profilePic,
          lastMessage: 'Start a conversation',
          lastMessageType: 'text',
          lastMessageStatus: MessageStatus.sent,
          lastMessageFileUrl: null,
          time: DateTime.now(),
          isOnline: user['is_online'] == true,
        );
        final chatViewModel = context.read<ChatViewModel>();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatDetailScreen(chat: chat)),
        );
        if (mounted) {
          chatViewModel.fetchChats();
        }
      },
      leading: CircleAvatar(
        backgroundImage: profilePic.isNotEmpty
            ? CachedNetworkImageProvider(ApiService.mediaUrl(profilePic))
            : null,
        backgroundColor: Colors.grey[300],
        child: profilePic.isEmpty
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        _displayName(user),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        user['phone']?.toString() ?? '',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chat, color: AppColors.primaryColor),
    );
  }

  Widget _buildInviteContact(Map<String, dynamic> contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white),
      ),
      title: Text(
        _displayName(contact),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        contact['phone']?.toString() ?? '',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: TextButton(
        onPressed: () => _inviteContact(contact),
        child: const Text('Invite'),
      ),
    );
  }
}
