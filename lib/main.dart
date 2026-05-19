import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/status_viewmodel.dart';
import 'views/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission early so Firebase can deliver messages
  await PermissionService.requestNotification();

  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Notification initialization skipped (requires google-services.json): $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProxyProvider<AuthViewModel, ChatViewModel>(
          create: (_) => ChatViewModel(),
          update: (_, authViewModel, chatViewModel) {
            final resolvedChatViewModel = chatViewModel ?? ChatViewModel();
            resolvedChatViewModel.handleAuthState(authViewModel.isAuthenticated);
            return resolvedChatViewModel;
          },
        ),
        ChangeNotifierProvider(create: (_) => StatusViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M2M',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B10A3)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
