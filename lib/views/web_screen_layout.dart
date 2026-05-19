import 'package:flutter/material.dart';
import '../models/chat.dart';

import '../utils/constants.dart';
import 'chats_list_view.dart';
import 'web_chat_view.dart';

class WebScreenLayout extends StatefulWidget {
  const WebScreenLayout({super.key});

  @override
  State<WebScreenLayout> createState() => _WebScreenLayoutState();
}

class _WebScreenLayoutState extends State<WebScreenLayout> {
  Chat? _selectedChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                // Top Header
                Container(
                  height: 60,
                  color: Colors.grey[100],
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryColor,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                
                // Search Bar
                Container(
                  height: 50,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[200],
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      hintText: "Search or start new chat",
                      hintStyle: const TextStyle(fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                
                // Chat List
                Expanded(
                  child: ChatsListView(
                    onChatTap: (chat) {
                      setState(() {
                        _selectedChat = chat;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Chat View / Empty State
          Expanded(
            child: _selectedChat != null
              ? WebChatView(chat: _selectedChat!)
              : Container(
                  color: Colors.grey[50], // Better background for empty state
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/web_empty_state.png',
                        height: 300,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.devices, size: 200, color: AppColors.primaryColor.withValues(alpha: 0.1));
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'm2m Web',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Send and receive messages without keeping your phone online.\nUse m2m on up to 4 linked devices and 1 phone at the same time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 5),
                            Text(
                              'End-to-end encrypted',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
