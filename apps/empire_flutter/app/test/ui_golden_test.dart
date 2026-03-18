import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/auth/auth_service.dart';
import 'package:scholesa_app/auth/recent_login_store.dart';
import 'package:scholesa_app/dashboards/role_dashboard.dart';
import 'package:scholesa_app/modules/messages/message_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/auth/login_page.dart';
import 'package:scholesa_app/ui/landing/landing_page.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

Future<void> _pumpSized(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  Duration settle = const Duration(milliseconds: 2000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: _testTheme,
      home: child,
    ),
  );

  await tester.pumpAndSettle(settle);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Goldens', () {
    testWidgets('Landing page - mobile', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: const LandingPage(),
      );

      await expectLater(
        find.byType(LandingPage),
        matchesGoldenFile('goldens/landing_mobile.png'),
      );
    });

    testWidgets('Landing page - desktop', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: const LandingPage(),
      );

      await expectLater(
        find.byType(LandingPage),
        matchesGoldenFile('goldens/landing_desktop.png'),
      );
    });

    testWidgets('Login page - mobile', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: _buildLoginPageHarness(),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_mobile.png'),
      );
    });

    testWidgets('Login page - desktop', (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: _buildLoginPageHarness(),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_desktop.png'),
      );
    });

    testWidgets('Login page - shared device recent accounts',
        (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: _buildLoginPageHarness(
          recentLoginStore: _GoldenRecentLoginStore(
            <RecentLoginAccount>[
              RecentLoginAccount(
                userId: 'parent-1',
                email: 'family@example.com',
                displayName: 'Family Account',
                provider: RecentLoginProvider.email,
                lastUsedAt: DateTime(2026, 3, 17, 9),
              ),
              RecentLoginAccount(
                userId: 'parent-2',
                email: 'guardian@example.com',
                displayName: 'Guardian Account',
                provider: RecentLoginProvider.google,
                lastUsedAt: DateTime(2026, 3, 17, 10),
              ),
            ],
            activeUserId: 'parent-2',
          ),
        ),
      );

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_recent_accounts_mobile.png'),
      );
    });

    testWidgets('Login page - validation error state',
        (WidgetTester tester) async {
      await _pumpSized(
        tester,
        size: const Size(390, 844),
        child: _buildLoginPageHarness(),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_error_validation_mobile.png'),
      );
    });

    testWidgets('Login page - loading state', (WidgetTester tester) async {
      final _PendingAuthService pendingAuthService = _PendingAuthService();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: _testTheme,
          home: _buildLoginPageHarness(authService: pendingAuthService),
        ),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@scholesa.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_loading_mobile.png'),
      );
    });

    testWidgets('Role dashboard - learner', (WidgetTester tester) async {
      final AppState appState = _buildStateForRole(UserRole.learner);

      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<MessageService>.value(
              value: _buildMessageService(appState.userId ?? ''),
            ),
          ],
          child: const RoleDashboard(),
        ),
      );

      await expectLater(
        find.byType(RoleDashboard),
        matchesGoldenFile('goldens/dashboard_learner_desktop.png'),
      );
    });

    testWidgets('Role dashboard - educator', (WidgetTester tester) async {
      final AppState appState = _buildStateForRole(UserRole.educator);

      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<MessageService>.value(
              value: _buildMessageService(appState.userId ?? ''),
            ),
          ],
          child: const RoleDashboard(),
        ),
      );

      await expectLater(
        find.byType(RoleDashboard),
        matchesGoldenFile('goldens/dashboard_educator_desktop.png'),
      );
    });

    testWidgets('Role dashboard - HQ', (WidgetTester tester) async {
      final AppState appState = _buildStateForRole(UserRole.hq);

      await _pumpSized(
        tester,
        size: const Size(1280, 800),
        child: MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<MessageService>.value(
              value: _buildMessageService(appState.userId ?? ''),
            ),
          ],
          child: const RoleDashboard(),
        ),
      );

      await expectLater(
        find.byType(RoleDashboard),
        matchesGoldenFile('goldens/dashboard_hq_desktop.png'),
      );
    });
  });
}

AppState _buildStateForRole(UserRole role) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'golden-${role.name}',
    'email': '${role.name}@scholesa.com',
    'displayName': '${role.displayName} User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1', 'site-2'],
    'entitlements': <dynamic>[],
  });
  return appState;
}

Widget _buildLoginPageHarness({
  AuthService? authService,
  RecentLoginStore? recentLoginStore,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<AuthService>.value(
        value: authService ?? _PendingAuthService(),
      ),
      ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ChangeNotifierProvider<RecentLoginStore>.value(
        value: recentLoginStore ?? RecentLoginStore(),
      ),
    ],
    child: const LoginPage(),
  );
}

MessageService _buildMessageService(String userId) {
  return MessageService(
    firestoreService: _MockFirestoreService(),
    userId: userId,
  );
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirestoreService extends Mock implements FirestoreService {}

class _GoldenRecentLoginStore extends RecentLoginStore {
  _GoldenRecentLoginStore(
    this._accounts, {
    this.activeUserId,
  });

  final List<RecentLoginAccount> _accounts;

  @override
  final String? activeUserId;

  @override
  List<RecentLoginAccount> get recentAccounts =>
      List<RecentLoginAccount>.unmodifiable(_accounts);
}

class _PendingAuthService extends AuthService {
  _PendingAuthService()
      : super(
          auth: _MockFirebaseAuth(),
          firestoreService: _MockFirestoreService(),
          appState: AppState(),
        );

  final Completer<void> _pending = Completer<void>();

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _pending.future;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _pending.future;
  }

  @override
  Future<void> signInWithMicrosoft() async {
    await _pending.future;
  }
}
