import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/call_viewmodel.dart';
import 'welcome_screen.dart';
import 'responsive_layout.dart';
import 'home_screen.dart';
import 'web_screen_layout.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _didNavigate = false;
  bool _postStartupTasksQueued = false;
  CallViewModel? _deferredCallViewModel;
  Widget? _deferredPage;
  String? _deferredDecision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  void _checkStatus() async {
    final authProvider = Provider.of<AuthViewModel>(context, listen: false);

    await authProvider.checkAuthStatus();
    if (!mounted || _didNavigate) return;

    if (authProvider.isAuthenticated) {
      final home = const ResponsiveLayout(
        mobileLayout: HomeScreen(),
        webLayout: WebScreenLayout(),
      );
      _queuePostStartupTasks(authProvider);
      _navigateWhenCallAllows(home, decision: 'home');
    } else {
      _navigateWhenCallAllows(const WelcomeScreen(), decision: 'welcome');
    }
  }

  void _queuePostStartupTasks(AuthViewModel authProvider) {
    if (_postStartupTasksQueued) return;
    _postStartupTasksQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(authProvider.runPostStartupTasks());
    });
  }

  void _navigateWhenCallAllows(Widget page, {required String decision}) {
    final callViewModel = context.read<CallViewModel>();
    if (callViewModel.hasActiveSession) {
      debugPrint('[startup] splash route decision=$decision deferred=call');
      _deferredPage = page;
      _deferredDecision = decision;
      _deferredCallViewModel ??= callViewModel
        ..addListener(_handleDeferredNavigation);
      return;
    }

    _navigateNow(page, decision: decision);
  }

  void _handleDeferredNavigation() {
    if (!mounted || _didNavigate || _deferredPage == null) return;
    final callViewModel = _deferredCallViewModel;
    if (callViewModel != null && callViewModel.hasActiveSession) return;

    final page = _deferredPage!;
    final decision = _deferredDecision ?? 'home';
    _deferredPage = null;
    _deferredDecision = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_didNavigate) {
        _navigateNow(page, decision: decision);
      }
    });
  }

  void _navigateNow(Widget page, {required String decision}) {
    if (_didNavigate) return;
    _didNavigate = true;
    debugPrint('[startup] splash route decision=$decision');
    _replaceWith(page);
  }

  void _replaceWith(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _deferredCallViewModel?.removeListener(_handleDeferredNavigation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Image.asset(
              'assets/icon.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              "M2M",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const Spacer(),
            const Text(
              "from",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Text(
              "M2M",
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
