import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/url_helper.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'calls/call_actions.dart';
import 'chat_detail_screen.dart';

/// How the contact picker behaves when a contact is tapped.
enum ContactPickerMode {
  /// Open the chat with the contact (default — opened from the Chats tab).
  chat,

  /// Start an audio/video call with the contact (opened from the Calls tab).
  call,
}

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key, this.mode = ContactPickerMode.chat});

  /// Whether tapping a contact opens a chat or starts a call.
  final ContactPickerMode mode;

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  static const String _cacheKey = 'cached_contacts_v1';

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _onAppContacts = [];
  List<Map<String, dynamic>> _offAppContacts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Local-first: paint the last-synced contacts instantly (no spinner), then
    // re-sync with the backend in the background and update silently. A
    // full-screen spinner only shows on the very first sync (empty cache).
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hadCache = await _loadFromCache();
    if (!mounted) return;
    await _loadUsers(showFullScreen: !hadCache);
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final onApp = (decoded['onApp'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final offApp = (decoded['offApp'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (onApp.isEmpty && offApp.isEmpty) return false;
      if (!mounted) return false;
      setState(() {
        _onAppContacts = onApp;
        _offAppContacts = offApp;
        _isLoading = false;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({'onApp': _onAppContacts, 'offApp': _offAppContacts}),
      );
    } catch (_) {
      // Caching is best-effort; a failure just means we re-sync next time.
    }
  }

  Future<void> _loadUsers({bool showFullScreen = false}) async {
    setState(() {
      _isLoading =
          showFullScreen && _onAppContacts.isEmpty && _offAppContacts.isEmpty;
      _isRefreshing = !(_isLoading);
      _errorMessage = null;
    });

    try {
      final result = await _apiService.syncContacts();
      if (!mounted) return;
      setState(() {
        _onAppContacts = result.onAppContacts;
        _offAppContacts = result.offAppContacts;
        _isLoading = false;
        _isRefreshing = false;
      });
      unawaited(_cacheContacts());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep showing cached contacts; only surface the error on a cold load.
        _errorMessage =
            (_onAppContacts.isEmpty && _offAppContacts.isEmpty) ? e.message : null;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = (_onAppContacts.isEmpty && _offAppContacts.isEmpty)
            ? 'Could not sync contacts'
            : null;
        _isLoading = false;
        _isRefreshing = false;
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
            onPressed: _isLoading || _isRefreshing ? null : () => _loadUsers(),
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
      return RefreshIndicator(
        onRefresh: () => _loadUsers(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
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
                    onPressed: () => _loadUsers(showFullScreen: true),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadUsers(),
      child: ListView(
        children: [
          if (_isRefreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primaryColor,
            ),
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
            onTap: _isRefreshing ? null : () => _loadUsers(),
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

  Future<void> _openChat(Map<String, dynamic> user) async {
    final profilePic = UrlHelper.fixUrl(user['profile_photo']);
    final chatViewModel = context.read<ChatViewModel>();
    final receiverId = user['id'].toString();
    // Reuse the existing conversation (real id + cached/server history) if
    // we already have one with this person. Falling back to a `new_`
    // placeholder only for genuinely-new conversations; otherwise the
    // detail screen would short-circuit and show no messages.
    final chat =
        chatViewModel.chatForReceiver(receiverId) ??
        Chat(
          id: "new_$receiverId",
          receiverId: receiverId,
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatDetailScreen(chat: chat)),
    );
    if (mounted) {
      chatViewModel.fetchChats();
    }
  }

  // Calls-tab flow: ask audio vs video (WhatsApp style), then dial. Capture the
  // receiver id before the async gap; navigation is handled by the helper.
  Future<void> _startCall(Map<String, dynamic> user) async {
    final receiverId = int.tryParse(user['id'].toString());
    if (receiverId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call for this contact')),
      );
      return;
    }
    final callType = await showCallTypeSheet(context, name: _displayName(user));
    if (callType == null || !mounted) return;
    await startCallAndNavigate(
      context,
      receiverId: receiverId,
      callType: callType,
    );
  }

  Widget _buildOnAppContact(Map<String, dynamic> user) {
    final profilePic = UrlHelper.fixUrl(user['profile_photo']);
    final isCallMode = widget.mode == ContactPickerMode.call;
    return ListTile(
      onTap: () => isCallMode ? _startCall(user) : _openChat(user),
      leading: CircleAvatar(
        backgroundImage: profilePic.isNotEmpty
            ? CachedNetworkImageProvider(
                ApiService.mediaUrl(profilePic),
                maxWidth: 96,
                maxHeight: 96,
              )
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
      trailing: Icon(
        isCallMode ? Icons.call : Icons.chat,
        color: AppColors.primaryColor,
      ),
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
