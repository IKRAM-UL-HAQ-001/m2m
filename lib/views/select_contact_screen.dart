import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../utils/constants.dart';
import '../utils/url_helper.dart';
import '../models/chat.dart';
import 'chat_detail_screen.dart';
import 'contact_sync_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _apiService.fetchUsers();
    debugPrint('Fetched ${users.length} users from API');
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select contact",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              "${_users.length} contacts",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            )
          : ListView.builder(
              itemCount:
                  _users.length +
                  3, // +3 for New group, New contact, New community
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: const Text(
                      "New group",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                } else if (index == 1) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryColor,
                      child: Icon(Icons.person_add, color: Colors.white),
                    ),
                    title: const Text(
                      "New contact",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.qr_code, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactSyncScreen(),
                        ),
                      );
                    },
                  );
                } else if (index == 2) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryColor,
                      child: Icon(Icons.groups, color: Colors.white),
                    ),
                    title: const Text(
                      "New community",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }

                final user = _users[index - 3];
                final profilePic = UrlHelper.fixUrl(user['profile_picture']);

                return ListTile(
                  onTap: () async {
                    final chat = Chat(
                      id: "new_${user['id']}",
                      receiverId: user['id'].toString(),
                      name:
                          (user['name'] != null &&
                              user['name'].toString().isNotEmpty)
                          ? user['name']
                          : user['phone_number'],
                      avatarUrl: profilePic,
                      lastMessage: "Start a conversation",
                      lastMessageType: 'text',
                      lastMessageFileUrl: null,
                      time: DateTime.now(),
                    );
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(chat: chat),
                      ),
                    );
                    if (context.mounted) {
                      context.read<ChatViewModel>().fetchChats();
                    }
                  },
                  leading: CircleAvatar(
                    backgroundImage: profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: profilePic.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    (user['name'] != null && user['name'].toString().isNotEmpty)
                        ? user['name']
                        : user['phone_number'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    (user['phone_number'] == "HIDDEN" || user['name'] == null || user['name'].toString().isEmpty)
                        ? "Hey there! I am using m2m."
                        : user['phone_number'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              },
            ),
    );
  }
}
