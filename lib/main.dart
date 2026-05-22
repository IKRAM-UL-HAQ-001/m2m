import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/call_event.dart';
import 'models/chat.dart';
import 'services/api_service.dart';
import 'services/dio_client.dart';
import 'services/websocket_service.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/call_viewmodel.dart';
import 'viewmodels/status_viewmodel.dart';
import 'views/chat_detail_screen.dart';
import 'views/calls/incoming_call_screen.dart';
import 'views/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  DioClient().initialize();

  // Request notification permission early so Firebase can deliver messages
  await PermissionService.requestNotification();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint(
      "Firebase initialization skipped (requires google-services.json): $e",
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, ChatViewModel>(
          create: (_) => ChatViewModel(),
          update: (_, authViewModel, chatViewModel) {
            final resolvedChatViewModel = chatViewModel ?? ChatViewModel();
            resolvedChatViewModel.handleAuthState(
              authViewModel.isAuthenticated,
            );
            return resolvedChatViewModel;
          },
        ),
        ChangeNotifierProvider(create: (_) => StatusViewModel()),
        ChangeNotifierProvider(create: (_) => CallViewModel()),
      ],
      child: MyApp(navigatorKey: navigatorKey),
    ),
  );
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _callEventSubscription;
  StreamSubscription? _incomingCallNotificationSubscription;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  String? _presentedIncomingCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService().initialize(navKey: widget.navigatorKey);
    _callEventSubscription = SocketService().callEventStream.listen(
      _handleCallEvent,
    );
    _incomingCallNotificationSubscription = NotificationService()
        .incomingCallTapStream
        .listen(_handleIncomingCallNotification);
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    _incomingCallNotificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      context.read<CallViewModel>().handleAppResumed();
    }
  }

  void _handleCallEvent(CallEvent event) {
    final viewModel = context.read<CallViewModel>();
    viewModel.handleCallEvent(event);

    if (event.type != 'call_invite') {
      if (_presentedIncomingCallId == event.call.id.toString() &&
          _isTerminalCallEvent(event)) {
        NotificationService().dismissIncomingCall(event.call.id);
        _presentedIncomingCallId = null;
      }
      return;
    }

    if (_lifecycleState != AppLifecycleState.resumed) return;

    _presentIncomingCall(event.call.id.toString());
  }

  Future<void> _handleIncomingCallNotification(
    IncomingCallNotificationTap tap,
  ) async {
    final callId = tap.data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;

    final viewModel = context.read<CallViewModel>();
    final ready = await viewModel.setIncomingCallFromPush(tap.data);
    if (!ready || !mounted) return;

    if (tap.actionId == NotificationService.rejectCallActionId) {
      await NotificationService().dismissIncomingCall(callId);
      await viewModel.rejectCall(int.tryParse(callId));
      return;
    }

    await _presentIncomingCall(callId);

    if (tap.actionId == NotificationService.acceptCallActionId) {
      await NotificationService().dismissIncomingCall(callId);
      await viewModel.acceptCall(int.tryParse(callId));
    }
  }

  Future<void> _presentIncomingCall(String callId) async {
    if (_presentedIncomingCallId == callId) return;

    _presentedIncomingCallId = callId;
    await widget.navigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => const IncomingCallScreen(),
            fullscreenDialog: true,
          ),
        )
        .whenComplete(() {
          if (_presentedIncomingCallId == callId) {
            _presentedIncomingCallId = null;
          }
        });
  }

  bool _isTerminalCallEvent(CallEvent event) {
    const terminalEvents = {
      'call_rejected',
      'call_cancelled',
      'call_ended',
      'call_missed',
      'call_busy',
      'call_failed',
    };
    const terminalStatuses = {
      'rejected',
      'cancelled',
      'ended',
      'missed',
      'busy',
      'failed',
    };
    return event.call.isTerminal ||
        terminalEvents.contains(event.type) ||
        terminalStatuses.contains(event.call.status);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'M2M',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B10A3)),
        useMaterial3: false,
      ),
      home: const SplashScreen(),
      routes: {
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return _NotificationChatRoute(args: args);
        },
      },
    );
  }
}

class _NotificationChatRoute extends StatefulWidget {
  final Object? args;

  const _NotificationChatRoute({required this.args});

  @override
  State<_NotificationChatRoute> createState() => _NotificationChatRouteState();
}

class _NotificationChatRouteState extends State<_NotificationChatRoute> {
  late final Future<Chat?> _chatFuture = _resolveChat();

  Future<Chat?> _resolveChat() async {
    final args = widget.args;
    if (args is! Map) return null;

    final chatId = args['chat_id']?.toString();
    if (chatId == null) return null;

    final chatViewModel = context.read<ChatViewModel>();
    for (final chat in chatViewModel.chats) {
      if (chat.id == chatId) return chat;
    }

    await chatViewModel.fetchChats(isSilent: true);
    for (final chat in chatViewModel.chats) {
      if (chat.id == chatId) return chat;
    }

    final chats = await ApiService().getChats(limit: 100);
    for (final chat in chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Chat?>(
      future: _chatFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final chat = snapshot.data;
        if (chat != null) {
          return ChatDetailScreen(chat: chat);
        }

        return const SplashScreen();
      },
    );
  }
}
