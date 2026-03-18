import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:scholesa_app/ui/auth/login_page.dart';

class _FakeAuthService extends Fake implements AuthService {}

class _FakeRecentLoginStore extends RecentLoginStore {
  _FakeRecentLoginStore(this._accounts);

  final List<RecentLoginAccount> _accounts;

  @override
  List<RecentLoginAccount> get recentAccounts =>
      List<RecentLoginAccount>.unmodifiable(_accounts);
}

void main() {
  testWidgets('login page shows remembered accounts and prefills email',
      (WidgetTester tester) async {
    final _FakeRecentLoginStore recentLoginStore = _FakeRecentLoginStore(
      <RecentLoginAccount>[
        RecentLoginAccount(
          userId: 'parent-1',
          email: 'family@example.com',
          displayName: 'Family Account',
          provider: RecentLoginProvider.email,
          lastUsedAt: DateTime(2026, 3, 17, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<AuthService>.value(value: _FakeAuthService()),
          ChangeNotifierProvider<AppState>(create: (_) => AppState()),
          ChangeNotifierProvider<RecentLoginStore>.value(
            value: recentLoginStore,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: <Locale>[
            Locale('en'),
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
          ],
          home: LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent accounts on this device'), findsOneWidget);
    expect(find.text('Family Account'), findsOneWidget);
    expect(find.text('family@example.com'), findsOneWidget);

    await tester.tap(find.text('Family Account'));
    await tester.pump();

    final TextFormField emailField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(emailField.controller?.text, 'family@example.com');
  });
}