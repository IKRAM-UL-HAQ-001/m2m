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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'services/callkit_service.dart';
import 'services/permission_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint('[startup] main started');
  WidgetsFlutterBinding.ensureInitialized();

  // Register the top-level handler synchronously, but do not block Flutter's
  // first frame on Firebase or secure-storage I/O. The visible splash screen
  // owns startup work while background isolates initialize Firebase themselves.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
  String? _lastRecoveredCallkitCallId;
  bool _callPermissionSetupStarted = false;
  CallViewModel? _permissionDeferredCallViewModel;
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
    // Android: the native CallKit-style incoming screen drives accept/decline.
    // Set the listener up as early as possible so an accept that cold-launched
    // the app is delivered. (No-op on iOS.)
    CallkitService.listen(
      onAccept: _handleCallkitAccept,
      onDecline: _handleCallkitDecline,
      onEnded: (callId) => unawaited(CallkitService.end(callId)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recoverAcceptedCallkitCall());
    });
  }

  Future<void> _handleCallkitAccept(Map<String, dynamic> extra) async {
    final callId = extra['call_id']?.toString();
    if (callId == null || callId.isEmpty || !mounted) return;
    final viewModel = context.read<CallViewModel>();
    // Native Android accept is latency-sensitive: the caller must move from
    // ringing to accepted immediately. Rebuild from the push/CallKit payload
    // first so backend accept can start without waiting for a detail fetch
    // during cold app start. If the payload is somehow incomplete, fall back to
    // the slower server restore.
    final ready =
        viewModel.setIncomingCallFromPushPayload(extra) ||
        await viewModel.setIncomingCallFromPush(extra);
    if (!ready || !mounted) {
      // Couldn't restore (already ended, etc.)  make sure the native UI clears.
      unawaited(CallkitService.end(callId));
      return;
    }
    viewModel.acceptCallFast(int.tryParse(callId));
    viewModel.markActiveCallScreenPushed();
    unawaited(_openActiveCallScreen(replace: false));
    // We've taken over with our own in-call screen + foreground service, so
    // clear CallKit's call state/notification  it was only the ringing handler.
    unawaited(CallkitService.end(callId));
  }

  Future<void> _recoverAcceptedCallkitCall() async {
    if (!mounted || !CallkitService.isSupported) return;
    final extra = await CallkitService.acceptedActiveCallExtra();
    if (extra == null || !mounted) return;
    final callId = extra['call_id']?.toString();
    if (callId == null || callId.isEmpty) return;

    final viewModel = context.read<CallViewModel>();
    final alreadyHandlingSameCall =
        viewModel.currentCall?.id == callId &&
        (viewModel.isInCall || viewModel.isConnecting);
    if (alreadyHandlingSameCall || _lastRecoveredCallkitCallId == callId) {
      return;
    }

    _lastRecoveredCallkitCallId = callId;
    debugPrint('Recovering accepted CallKit call callId=$callId');
    await _handleCallkitAccept(extra);
  }

  Future<void> _handleCallkitDecline(String? callId) async {
    unawaited(CallkitService.end(callId));
    if (callId == null || callId.isEmpty) return;
    final viewModel = context.read<CallViewModel>();
    await viewModel.rejectCall(int.tryParse(callId));
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

    _requestCallPermissionsWhenIdle();
  }

  void _requestCallPermissionsWhenIdle() {
    if (!mounted || _callPermissionSetupStarted) return;
    final callViewModel = context.read<CallViewModel>();
    if (callViewModel.hasActiveSession) {
      _permissionDeferredCallViewModel ??= callViewModel
        ..addListener(_requestCallPermissionsWhenIdle);
      return;
    }

    _permissionDeferredCallViewModel?.removeListener(
      _requestCallPermissionsWhenIdle,
    );
    _permissionDeferredCallViewModel = null;
    _callPermissionSetupStarted = true;
    unawaited(PermissionService.requestCallPermissions());
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    _incomingCallNotificationSubscription?.cancel();
    _permissionDeferredCallViewModel?.removeListener(
      _requestCallPermissionsWhenIdle,
    );
    CallkitService.disposeListener();
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
      unawaited(_recoverAcceptedCallkitCall());
      unawaited(
        callViewModel.handleAppResumed().whenComplete(
          _presentIncomingIfPending,
        ),
      );
      // Also check immediately: when the OS fires the incoming-call full-screen
      // intent while the app is merely backgrounded (screen locked/off), it
      // brings this activity to the foreground WITHOUT a notification tap, so no
      // tap callback runs to route us. If the live WebSocket already delivered
      // the invite, currentCall is incoming right now and we can present at once;
      // handleAppResumed's completion re-checks for the push-only/dropped-socket
      // case where the call still has to be fetched from the backend.
      _presentIncomingIfPending();
    }
  }

  void _presentIncomingIfPending() {
    if (!mounted) return;
    // Android shows the native CallKit screen, not the in-app Flutter one.
    if (CallkitService.isSupported) return;
    final viewModel = context.read<CallViewModel>();
    final call = viewModel.currentCall;
    if (call == null || !viewModel.isIncoming) return;
    if (_presentedIncomingCallId == call.id) return;
    if (_isActiveCallRoute(_currentRouteName)) return;
    unawaited(_presentIncomingCall(call.id));
  }

  void _handleCallEvent(CallEvent event) {
    final viewModel = context.read<CallViewModel>();
    viewModel.handleCallEvent(event);

    if (event.type != 'call_invite') {
      if (_isTerminalCallEvent(event)) {
        // Caller cancelled / call ended  tear down whichever incoming UI is up.
        unawaited(CallkitService.end(event.call.id.toString()));
        if (_presentedIncomingCallId == event.call.id.toString()) {
          NotificationService().dismissIncomingCall(event.call.id);
          _presentedIncomingCallId = null;
        }
      }
      return;
    }

    // FOREGROUND → present the in-app Flutter screen directly. This is the
    // reliable, OEM-independent path that "just worked" before: no native
    // CallKit activity (which MIUI/others can block), instant accept, and it
    // brings back the front-camera self-preview. CallKit is reserved for the
    // background/terminated case where we genuinely need to surface over the
    // lock screen / other apps.
    if (_lifecycleState == AppLifecycleState.resumed) {
      if (!viewModel.isIncoming || viewModel.currentCall?.id != event.call.id) {
        return;
      }
      _presentIncomingCall(event.call.id.toString());
      return;
    }

    // Backgrounded but still alive: surface via CallKit (Android). Terminated
    // calls arrive through the FCM background handler, which also uses CallKit.
    if (CallkitService.isSupported) {
      unawaited(
        CallkitService.showIncoming(_callkitDataFromSession(event.call)),
      );
    }
  }

  Map<String, dynamic> _callkitDataFromSession(CallSession call) {
    return <String, dynamic>{
      'call_id': call.id,
      'caller_name': call.caller.name,
      'call_type': call.callType.value,
      'caller_id': call.caller.id,
      'caller_profile_picture': call.caller.avatarUrl ?? '',
      'room_name': call.roomName,
    };
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
