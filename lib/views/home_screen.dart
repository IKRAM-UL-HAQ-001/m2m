import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'chats_list_view.dart';
import 'login_screen.dart';
import 'select_contact_screen.dart';
import 'linked_devices_screen.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    Future.microtask(() {
      if (mounted) {
        Provider.of<ChatViewModel>(context, listen: false).fetchChats();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M2M', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final authProvider = Provider.of<AuthViewModel>(context, listen: false);
                await authProvider.logout();
                if (mounted) {
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else if (value == 'linked_devices') {
                // Navigate to LinkedDevicesScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LinkedDevicesScreen()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'linked_devices', child: Text('Linked devices')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "CHATS"),
            Tab(text: "STATUS"),
            Tab(text: "CALLS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ChatsListView(),
          const Center(child: Text("Status Section")),
          const Center(child: Text("Calls Section")),
        ],
      ),
      floatingActionButton: _tabController.index == 1 
        ? null 
        : FloatingActionButton(
            backgroundColor: AppColors.floatingButtonColor,
            child: Icon(_tabController.index == 2 ? Icons.call : Icons.message, color: Colors.white),
            onPressed: () {
              if (_tabController.index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SelectContactScreen()),
                );
              }
            },
          ),
    );
  }
}
