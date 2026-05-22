import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/call_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/status_viewmodel.dart';
import 'calls/active_audio_call_screen.dart';
import 'calls/active_video_call_screen.dart';
import 'calls/calls_tab.dart';
import 'calls/call_screen_helpers.dart';
import 'chats_list_view.dart';
import 'linked_devices_screen.dart';
import 'login_screen.dart';
import 'select_contact_screen.dart';
import 'settings_screen.dart';
import 'status/status_privacy_settings_screen.dart';
import 'status/status_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentTabIndex = 0;
  bool _activeCallRouteOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_currentTabIndex != _tabController.index) {
        _currentTabIndex = _tabController.index;
        _closeSearch();
        return;
      }
      setState(() {});
    });
    Future.microtask(() {
      if (mounted) {
        Provider.of<ChatViewModel>(context, listen: false).fetchChats();
        Provider.of<StatusViewModel>(context, listen: false).loadStatuses();
        _syncContactsIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    await SocketService().reconnect();
    if (!mounted) return;
    unawaited(context.read<CallViewModel>().handleAppResumed());
    await Provider.of<ChatViewModel>(
      context,
      listen: false,
    ).fetchChats(isSilent: true);
    await _syncContactsIfNeeded();
  }

  Future<void> _syncContactsIfNeeded() async {
    try {
      if (!await _apiService.shouldSyncContacts()) return;
      await _apiService.syncContacts();
    } catch (e) {
      debugPrint('Contact sync skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: _getSearchHint(),
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim());
                  },
                )
              : const Text(
                  'M2M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          backgroundColor: AppColors.primaryColor,
          elevation: 0.7,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: _isSearching
              ? [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _closeSearch,
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      setState(() => _isSearching = true);
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'status_privacy') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const StatusPrivacySettingsScreen(),
                          ),
                        );
                      } else if (value == 'logout') {
                        final authProvider = Provider.of<AuthViewModel>(
                          context,
                          listen: false,
                        );
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      } else if (value == 'new_contact') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectContactScreen(),
                          ),
                        );
                      } else if (value == 'linked_devices') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LinkedDevicesScreen(),
                          ),
                        );
                      } else if (value == 'settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) {
                      if (_currentTabIndex == 1) {
                        return const [
                          PopupMenuItem(
                            value: 'status_privacy',
                            child: Text('Status privacy'),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Text('Settings'),
                          ),
                          PopupMenuItem(value: 'logout', child: Text('Logout')),
                        ];
                      }

                      return const [
                        PopupMenuItem(
                          value: 'new_contact',
                          child: Text('New contact'),
                        ),
                        PopupMenuItem(
                          value: 'linked_devices',
                          child: Text('Linked devices'),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Text('Settings'),
                        ),
                        PopupMenuItem(value: 'logout', child: Text('Logout')),
                      ];
                    },
                  ),
                ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
            tabs: [
              const Tab(text: 'CHATS'),
              Tab(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Positioned(
                      right: -12,
                      top: -4,
                      child: Consumer<StatusViewModel>(
                        builder: (context, vm, child) {
                          if (!vm.hasUnseenStatuses) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Tab(text: 'CALLS'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            children: [
              _OngoingCallBar(onTap: _openActiveCall),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ChatsListView(searchQuery: _activeSearchQuery),
                    StatusTab(searchQuery: _activeSearchQuery),
                    CallsTab(searchQuery: _activeSearchQuery),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isSearching) return null;
    if (_tabController.index == 0) {
      return FloatingActionButton(
        tooltip: 'New chat',
        backgroundColor: AppColors.floatingButtonColor,
        onPressed: _openContactPicker,
        child: const Icon(Icons.message, color: Colors.white),
      );
    }
    if (_tabController.index == 2) {
      return FloatingActionButton(
        tooltip: 'New call',
        backgroundColor: AppColors.floatingButtonColor,
        onPressed: _openContactPicker,
        child: const Icon(Icons.add_call, color: Colors.white),
      );
    }
    return null;
  }

  void _openContactPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectContactScreen()),
    );
  }

  Future<void> _openActiveCall() async {
    if (_activeCallRouteOpen) return;
    final call = context.read<CallViewModel>().currentCall;
    if (call == null) return;
    _activeCallRouteOpen = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => call.callType.name == 'video'
            ? const ActiveVideoCallScreen()
            : const ActiveAudioCallScreen(),
      ),
    );
    _activeCallRouteOpen = false;
  }

  String get _activeSearchQuery => _isSearching ? _searchQuery : '';

  String _getSearchHint() {
    switch (_tabController.index) {
      case 0:
        return 'Search chats...';
      case 1:
        return 'Search status...';
      case 2:
        return 'Search calls...';
      default:
        return 'Search...';
    }
  }

  void _closeSearch() {
    if (!_isSearching &&
        _searchQuery.isEmpty &&
        _searchController.text.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }
}

class _OngoingCallBar extends StatelessWidget {
  const _OngoingCallBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<CallViewModel>(
      builder: (context, vm, child) {
        final call = vm.currentCall;
        if (call == null || !vm.isInCall) return const SizedBox.shrink();
        final participant = otherParticipant(call);
        final reconnecting = vm.callState == CallState.reconnecting;
        return Material(
          color: AppColors.primaryColor,
          child: InkWell(
            onTap: onTap,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      call.callType.name == 'video'
                          ? Icons.videocam
                          : Icons.call,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            participant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            reconnecting ? 'Reconnecting...' : 'Ongoing call',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      reconnecting ? '' : vm.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
