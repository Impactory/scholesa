import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/habits/habit_service.dart';
import 'package:scholesa_app/modules/learner/learner_portfolio_page.dart';
import 'package:scholesa_app/modules/learner/learner_today_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/site/site_incidents_page.dart';
import 'package:scholesa_app/modules/site/site_ops_page.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildAppState({
  required UserRole role,
  required Locale locale,
}) {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'test-user-1',
    'email': 'test-user-1@scholesa.test',
    'displayName': 'Test User',
    'role': role.name,
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': locale.languageCode == 'zh'
        ? 'zh-${locale.countryCode}'
        : 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Widget _buildHarness({
  required Locale locale,
  required Widget child,
  required List<SingleChildWidget> providers,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: child,
    ),
  );
}

void main() {
  group('Learner and site tri-locale surfaces', () {
    testWidgets('learner today renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );
      final MissionService missionService = MissionService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );
      final HabitService habitService = HabitService(
        firestoreService: firestoreService,
        learnerId: 'test-user-1',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerTodayPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<MissionService>.value(value: missionService),
            ChangeNotifierProvider<HabitService>.value(value: habitService),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('今天'), findsOneWidget);
      expect(find.text('🌟 继续加油！'), findsOneWidget);
      expect(find.text('今天的习惯'), findsOneWidget);
    });

    testWidgets('learner portfolio renders zh-TW copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'TW');
      final AppState appState = _buildAppState(
        role: UserRole.learner,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const LearnerPortfolioPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<dynamic>.value(value: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的作品集'), findsOneWidget);
      expect(find.text('展示你的成就'), findsOneWidget);
      expect(find.text('徽章'), findsOneWidget);
    });

    testWidgets('site sessions renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteSessionsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('课程日程'), findsOneWidget);
      expect(find.text('管理站点课程和教室'), findsOneWidget);
      expect(find.text('新建课程'), findsOneWidget);
    });

    testWidgets('site ops renders zh-TW copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'TW');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteOpsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日營運'), findsOneWidget);
      expect(find.text('快捷操作'), findsOneWidget);
      expect(find.text('最近活動'), findsOneWidget);
    });

    testWidgets('site incidents renders zh-CN copy',
        (WidgetTester tester) async {
      final Locale locale = const Locale('zh', 'CN');
      final FirestoreService firestoreService = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
      );
      final AppState appState = _buildAppState(
        role: UserRole.site,
        locale: locale,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          locale: locale,
          child: const SiteIncidentsPage(),
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            Provider<FirestoreService>.value(value: firestoreService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('安全与事件'), findsOneWidget);
      expect(find.text('报告事件'), findsOneWidget);
      expect(find.text('暂无事件 已提交'), findsOneWidget);
    });
  });
}