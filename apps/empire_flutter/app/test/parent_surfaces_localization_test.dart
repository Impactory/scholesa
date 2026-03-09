import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _FakeParentService extends ChangeNotifier implements ParentService {
  _FakeParentService({
    required this.parentId,
    required List<LearnerSummary> learnerSummaries,
  }) : _learnerSummaries = learnerSummaries;

  final List<LearnerSummary> _learnerSummaries;

  @override
  final String parentId;

  @override
  final BillingSummary? billingSummary = null;

  @override
  final bool isLoading = false;

  @override
  final String? error = null;

  @override
  List<LearnerSummary> get learnerSummaries => _learnerSummaries;

  @override
  Future<void> loadParentData() async {
    notifyListeners();
  }
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-test-1',
    'email': 'parent@scholesa.test',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': <dynamic>[],
  });
  return state;
}

LearnerSummary _sampleLearner() {
  final DateTime now = DateTime(2026, 3, 8, 9);
  return LearnerSummary(
    learnerId: 'learner-1',
    learnerName: 'Ava Learner',
    currentLevel: 4,
    totalXp: 1200,
    missionsCompleted: 5,
    currentStreak: 7,
    attendanceRate: 0.9,
    pillarProgress: const <String, double>{
      'futureSkills': 0.8,
      'leadership': 0.6,
      'impact': 0.4,
    },
    capabilitySnapshot: const CapabilitySnapshot(band: 'developing'),
    portfolioSnapshot: const PortfolioSnapshot(
      artifactCount: 3,
      publishedArtifactCount: 2,
      badgeCount: 1,
      projectCount: 2,
    ),
    ideationPassport: const IdeationPassport(
      reflectionsSubmitted: 2,
      voiceInteractions: 4,
    ),
    recentActivities: <RecentActivity>[
      RecentActivity(
        id: 'activity-1',
        title: 'Build a Robot',
        description: 'Prototype iteration complete',
        type: 'mission',
        emoji: '🤖',
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
    ],
    upcomingEvents: <UpcomingEvent>[
      UpcomingEvent(
        id: 'event-1',
        title: 'Robotics Studio',
        description: 'Prototype review',
        dateTime: now.add(const Duration(hours: 5)),
        type: 'future_skills',
        location: 'Lab 1',
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Locale locale,
  required Widget home,
}) async {
  final _FakeParentService service = _FakeParentService(
    parentId: 'parent-test-1',
    learnerSummaries: <LearnerSummary>[_sampleLearner()],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        ChangeNotifierProvider<ParentService>.value(value: service),
        Provider<LearningRuntimeProvider?>.value(value: null),
      ],
      child: MaterialApp(
        theme: _testTheme,
        locale: locale,
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Parent surface tri-locale coverage', () {
    testWidgets('parent summary renders zh-CN strings',
        (WidgetTester tester) async {
      await _pumpPage(
        tester,
        locale: const Locale('zh', 'CN'),
        home: const ParentSummaryPage(),
      );

      expect(find.text('家庭仪表板'), findsOneWidget);
      expect(find.text('学习支柱'), findsOneWidget);
      expect(find.text('家庭学习循环'), findsOneWidget);
    });

    testWidgets('parent schedule renders zh-TW strings',
        (WidgetTester tester) async {
      await _pumpPage(
        tester,
        locale: const Locale('zh', 'TW'),
        home: const ParentSchedulePage(),
      );

      expect(find.text('日程'), findsOneWidget);
      expect(find.text('所有學習者'), findsOneWidget);
      expect(find.text('家庭日程循環'), findsOneWidget);
    });

    testWidgets('parent portfolio renders zh-CN strings',
        (WidgetTester tester) async {
      await _pumpPage(
        tester,
        locale: const Locale('zh', 'CN'),
        home: const ParentPortfolioPage(),
      );

      expect(find.text('作品集'), findsOneWidget);
      expect(find.text('项目'), findsOneWidget);
      expect(find.text('能力快照'), findsOneWidget);
    });
  });
}