import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../utils/constants.dart';
import 'web_auth_viewmodel.dart';
import 'web_chat_list.dart';
import 'web_chat_view.dart';
import 'web_chat_viewmodel.dart';
import 'web_profile_view.dart';
import 'web_status_view.dart';

/// WhatsApp-Web-style two-pane shell: conversation sidebar + active chat pane.
class WebHome extends StatefulWidget {
  const WebHome({super.key});

  @override
  State<WebHome> createState() => _WebHomeState();
}

enum _Section { chats, status, profile }

class _WebHomeState extends State<WebHome> {
  Chat? _selectedChat;
  _Section _section = _Section.chats;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WebChatViewModel>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navRail(),
          SizedBox(width: 380, child: _sectionPanel()),
          Container(width: 1, color: Colors.grey[300]),
          Expanded(
            child: _selectedChat != null
                ? WebChatView(
                    key: ValueKey(_selectedChat!.id),
                    chat: _selectedChat!,
                  )
                : _emptyState(),
          ),
        ],
      ),
    );
  }

  Widget _navRail() {
    return Container(
      width: 64,
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _railIcon(Icons.chat_bubble, _Section.chats),
          const SizedBox(height: 8),
          _railIcon(Icons.donut_large, _Section.status),
          const Spacer(),
          _railIcon(Icons.account_circle, _Section.profile),
          const SizedBox(height: 8),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => context.read<WebAuthViewModel>().logout(),
          ),
        ],
      ),
    );
  }

  Widget _railIcon(IconData icon, _Section section) {
    final selected = _section == section;
    return IconButton(
      icon: Icon(
        icon,
        color: selected ? AppColors.primaryColor : Colors.grey[600],
      ),
      onPressed: () => setState(() => _section = section),
    );
  }

  Widget _sectionPanel() {
    switch (_section) {
      case _Section.status:
        return const WebStatusView();
      case _Section.profile:
        return const WebProfileView();
      case _Section.chats:
        return _sidebar();
    }
  }

  Widget _sidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _sidebarHeader(),
          _searchBar(),
          Expanded(
            child: WebChatList(
              selectedChatId: _selectedChat?.id,
              onChatTap: (chat) => setState(() => _selectedChat = chat),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarHeader() {
    return Container(
      height: 60,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryColor,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.chat, color: Colors.grey),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'logout') {
                context.read<WebAuthViewModel>().logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => context.read<WebChatViewModel>().setSearchQuery(v),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          hintText: 'Search or start new chat',
          hintStyle: const TextStyle(fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 120,
            color: AppColors.primaryColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 20),
          const Text(
            'M2M Web',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send and receive messages without keeping your phone online.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

}
