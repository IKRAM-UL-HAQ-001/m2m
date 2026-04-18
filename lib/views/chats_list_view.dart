import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'chat_detail_screen.dart';

import '../models/chat.dart';

class ChatsListView extends StatelessWidget {
  final Function(Chat)? onChatTap;
  const ChatsListView({super.key, this.onChatTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, chatViewModel, child) {
        if (chatViewModel.isLoading && chatViewModel.chats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => chatViewModel.fetchChats(),
          child: ListView.builder(
            itemCount: chatViewModel.chats.length,
            itemBuilder: (context, index) {
            final chat = chatViewModel.chats[index];
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    backgroundImage: chat.avatarUrl.isNotEmpty 
                        ? NetworkImage(chat.avatarUrl) 
                        : null,
                    child: chat.avatarUrl.isEmpty 
                        ? Icon(Icons.person, color: Colors.grey[600]) 
                        : null,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        "${chat.time.hour}:${chat.time.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 13.0),
                      ),
                    ],
                  ),
                  subtitle: Container(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Row(
                      children: [
                        if (chat.lastMessageType == 'image') ...[
                          const Icon(Icons.image, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          const Text("Photo", style: TextStyle(color: Colors.grey, fontSize: 15.0)),
                        ] else if (chat.lastMessageType == 'audio') ...[
                          const Icon(Icons.mic, size: 16, color: Color(0xFF25D366)),
                          const SizedBox(width: 5),
                          const Text("Voice Message", style: TextStyle(color: Colors.grey, fontSize: 15.0)),
                        ] else if (chat.lastMessageType == 'video') ...[
                          const Icon(Icons.videocam, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          const Text("Video", style: TextStyle(color: Colors.grey, fontSize: 15.0)),
                        ] else if (chat.lastMessageType != 'text') ...[
                          const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              chat.lastMessage.isNotEmpty ? chat.lastMessage : "File", 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 15.0)
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 15.0),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: chat.unreadCount > 0 
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          chat.unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
                  onTap: () async {
                    if (onChatTap != null) {
                      onChatTap!(chat);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(chat: chat),
                        ),
                      );
                      if (context.mounted) {
                        context.read<ChatViewModel>().fetchChats();
                      }
                    }
                  },
                ),
                const Divider(height: 10.0),
              ],
            );
          },
        ),
      );
    },
  );
}
}
