import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/dio_client.dart';
import 'utils/constants.dart';
import 'web/web_auth_viewmodel.dart';
import 'web/web_chat_viewmodel.dart';
import 'web/web_home.dart';
import 'web/web_login_screen.dart';
import 'web/web_status_viewmodel.dart';

/// Dedicated web entry point. Build with:
///   flutter build web -t lib/main_web.dart
///
/// It deliberately avoids the mobile [main.dart] graph (Firebase, CallKit, the
/// drift/sqlite local DB, dart:io media handling) which cannot compile for web.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DioClient().initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebAuthViewModel()),
        ChangeNotifierProvider(create: (_) => WebChatViewModel()),
        ChangeNotifierProvider(create: (_) => WebStatusViewModel()),
      ],
      child: const WebApp(),
    ),
  );
}

class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M2M Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        useMaterial3: false,
      ),
      home: const _WebGate(),
    );
  }
}

class _WebGate extends StatefulWidget {
  const _WebGate();

  @override
  State<_WebGate> createState() => _WebGateState();
}

class _WebGateState extends State<_WebGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WebAuthViewModel>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<WebAuthViewModel>();
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const WebHome() : const WebLoginScreen();
  }
}
