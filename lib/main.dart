import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/call_event.dart';
import 'models/chat.dart';
import 'models/call_session.dart';
import 'services/api_service.dart';
import 'services/dio_client.dart';
import 'services/websocket_service.dart';
import 'utils/constants.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/call_viewmodel.dart';
import 'viewmodels/status_viewmodel.dart';
import 'views/chat_detail_screen.dart';
import 'views/calls/active_audio_call_screen.dart';
import 'views/calls/active_video_call_screen.dart';
import 'views/calls/call_screen_helpers.dart';
import 'views/calls/incoming_call_screen.dart';
import 'views/calls/outgoing_call_screen.dart';
import 'views/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint('[startup] main started');
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );
  DioClient().initialize();

  debugPrint('[startup] runApp called');
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
  String? _activeCallRouteCallId;
  late final _AppRouteObserver _routeObserver;
  String? _currentRouteName;

  @override
  void initState() {
    super.initState();
    _routeObserver = _AppRouteObserver(_handleRouteChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[startup] first frame rendered');
      unawaited(_initializeAfterFirstFrame());
    });
    _callEventSubscription = SocketService().callEventStream.listen(
      _handleCallEvent,
    );
    _incomingCallNotificationSubscription = NotificationService()
        .incomingCallTapStream
        .listen(_handleIncomingCallNotification);
  }

  Future<void> _initializeAfterFirstFrame() async {
    try {
      debugPrint('[startup] Firebase init started');
      await Firebase.initializeApp();
      debugPrint('[startup] Firebase init completed');
    } catch (e) {
      debugPrint(
        '[startup] Firebase initialization skipped '
        '(requires google-services.json): $e',
      );
    }
    if (!mounted) return;

    debugPrint('[startup] notification init started');
    await NotificationService().initialize(navKey: widget.navigatorKey);
    debugPrint('[startup] notification init completed');
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
    final callViewModel = context.read<CallViewModel>();
    debugPrint(
      'App lifecycle state=${state.name} '
      '${callViewModel.lifecycleDiagnostics} '
      'socket=${SocketService().connectionState.name}',
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(callViewModel.handleAppResumed());
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
    if (!viewModel.isIncoming || viewModel.currentCall?.id != event.call.id) {
      return;
    }

    _presentIncomingCall(event.call.id.toString());
  }

  Future<void> _handleIncomingCallNotification(
    IncomingCallNotificationTap tap,
  ) async {
    final callId = tap.data['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;

    final viewModel = context.read<CallViewModel>();
    final isAcceptAction =
        tap.actionId == NotificationService.acceptCallActionId;
    final ready = isAcceptAction
        ? viewModel.setIncomingCallFromPushPayload(tap.data)
        : await viewModel.setIncomingCallFromPush(tap.data);
    if (!ready || !mounted) return;

    if (tap.actionId == NotificationService.rejectCallActionId) {
      await NotificationService().dismissIncomingCall(callId);
      await viewModel.rejectCall(int.tryParse(callId));
      return;
    }

    if (isAcceptAction) {
      unawaited(NotificationService().dismissIncomingCall(callId));
      viewModel.acceptCallFast(int.tryParse(callId));
      final replaceIncomingRoute = _presentedIncomingCallId == callId;
      _presentedIncomingCallId = null;
      unawaited(_openActiveCallScreen(replace: replaceIncomingRoute));
      return;
    }

    await _presentIncomingCall(callId);
  }

  Future<void> _presentIncomingCall(String callId) async {
    if (_presentedIncomingCallId == callId) return;

    _presentedIncomingCallId = callId;
    await widget.navigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: IncomingCallScreen.routeName),
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

  Future<void> _openActiveCallScreen({required bool replace}) async {
    final viewModel = context.read<CallViewModel>();
    final call = viewModel.currentCall;
    if (call == null) return;
    if (_activeCallRouteCallId == call.id) return;
    if (_isActiveCallRoute(_currentRouteName)) return;

    final navState = widget.navigatorKey.currentState;
    if (navState == null) return;

    _activeCallRouteCallId = call.id;
    viewModel.markActiveCallScreenPushed();
    final route = MaterialPageRoute(
      settings: RouteSettings(name: _activeRouteNameFor(call)),
      builder: (_) => _activeScreenFor(call),
    );
    if (replace && navState.canPop()) {
      await navState.pushReplacement(route);
    } else {
      await navState.push(route);
    }
    if (_activeCallRouteCallId == call.id) {
      _activeCallRouteCallId = null;
    }
  }

  Widget _activeScreenFor(CallSession call) {
    return call.callType == CallType.video
        ? const ActiveVideoCallScreen()
        : const ActiveAudioCallScreen();
  }

  String _activeRouteNameFor(CallSession call) {
    return call.callType == CallType.video
        ? ActiveVideoCallScreen.routeName
        : ActiveAudioCallScreen.routeName;
  }

  bool _isActiveCallRoute(String? routeName) {
    return routeName == ActiveAudioCallScreen.routeName ||
        routeName == ActiveVideoCallScreen.routeName;
  }

  void _handleRouteChanged(String? routeName) {
    if (!mounted || _currentRouteName == routeName) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentRouteName != routeName) {
        setState(() => _currentRouteName = routeName);
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
    final callViewModel = _maybeCallViewModel(context);
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'M2M',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B10A3)),
        useMaterial3: false,
      ),
      navigatorObservers: [_routeObserver],
      builder: (context, child) {
        return _GlobalCallBannerShell(
          viewModel: callViewModel,
          currentRouteName: _currentRouteName,
          onTap: () => unawaited(_openActiveCallScreen(replace: false)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
      routes: {
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return _NotificationChatRoute(args: args);
        },
      },
    );
  }

  CallViewModel? _maybeCallViewModel(BuildContext context) {
    try {
      return Provider.of<CallViewModel>(context);
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _GlobalCallBannerShell extends StatelessWidget {
  const _GlobalCallBannerShell({
    required this.viewModel,
    required this.currentRouteName,
    required this.onTap,
    required this.child,
  });

  static const double _bannerHeight = 52;
  static const Set<String> _suppressedRoutes = {
    IncomingCallScreen.routeName,
    OutgoingCallScreen.routeName,
    ActiveAudioCallScreen.routeName,
    ActiveVideoCallScreen.routeName,
  };

  final CallViewModel? viewModel;
  final String? currentRouteName;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewModel = this.viewModel;
    if (viewModel == null) return child;

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final call = viewModel.currentCall;
        final showBanner =
            call != null &&
            viewModel.isInCall &&
            !_suppressedRoutes.contains(currentRouteName);
        final topPadding = MediaQuery.paddingOf(context).top;

        return Stack(
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                top: showBanner ? _bannerHeight + topPadding : 0,
              ),
              child: child,
            ),
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _GlobalCallBanner(
                  call: call,
                  viewModel: viewModel,
                  onTap: onTap,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlobalCallBanner extends StatelessWidget {
  const _GlobalCallBanner({
    required this.call,
    required this.viewModel,
    required this.onTap,
  });

  final CallSession call;
  final CallViewModel viewModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final participant = otherParticipant(call);
    final status = switch (viewModel.callState) {
      CallState.connecting => 'Connecting...',
      CallState.reconnecting => 'Reconnecting...',
      _ => 'Ongoing call',
    };
    final showDuration = viewModel.callState == CallState.active;

    return Material(
      color: AppColors.primaryColor,
      elevation: 3,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _GlobalCallBannerShell._bannerHeight,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    call.callType == CallType.video
                        ? Icons.videocam
                        : Icons.call,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showDuration)
                    Text(
                      viewModel.formattedDuration,
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
      ),
    );
  }
}

class _AppRouteObserver extends NavigatorObserver {
  _AppRouteObserver(this.onRouteChanged);

  final ValueChanged<String?> onRouteChanged;

  void _notify(Route<dynamic>? route) {
    onRouteChanged(route?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notify(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notify(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _notify(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notify(newRoute);
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
