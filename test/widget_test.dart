import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:m2m/main.dart';
import 'package:m2m/viewmodels/auth_viewmodel.dart';
import 'package:m2m/viewmodels/chat_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app shows splash branding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
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
        ],
        child: MyApp(navigatorKey: GlobalKey<NavigatorState>()),
      ),
    );

    expect(find.text('M2M'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
