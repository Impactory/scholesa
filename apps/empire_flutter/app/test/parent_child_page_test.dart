import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_child_page.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/services/export_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubParentService extends ChangeNotifier implements ParentService {
  _StubParentService({
    required this.parentId,
    required this.learnerSummaries,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ??
            FirestoreService(
              firestore: FakeFirebaseFirestore(),
              auth: _FakeFirebaseAuth(),
            );

  @override
  final FirestoreService firestoreService;

  @override
  final String parentId;

  @override
  final List<LearnerSummary> learnerSummaries;

  @override
  final bool isLoading = false;

  @override
  final String? error = null;

  @override
  final BillingSummary? billingSummary = null;

  @override
  Future<void> loadParentData() async {}
}

AppState _buildParentState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'parent-1',
    'email': 'parent@scholesa.test',
    'displayName': 'Parent One',
    'role': 'parent',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <dynamic>[],
  });
  return state;
}

LearnerSummary _sampleLearner() {
  final DateTime now = DateTime(2026, 3, 18, 9);
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
    ideationPassport: const IdeationPassport(reflectionsSubmitted: 2),
    recentActivities: <RecentActivity>[
      RecentActivity(
        id: 'activity-1',
        title: 'Build a Robot',
        description: 'Prototype iteration complete',
        type: 'mission',
        emoji: '🤖',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
    ],
    upcomingEvents: <UpcomingEvent>[
      UpcomingEvent(
        id: 'event-1',
        title: 'Robotics Studio',
        description: 'Prototype review',
        dateTime: now.add(const Duration(days: 1)),
        type: 'session',
        location: 'Lab 1',
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Widget child,
  required ParentService parentService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        ChangeNotifierProvider<ParentService>.value(value: parentService),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory,
        ),
        locale: const Locale('en'),
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
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets('parent child page renders linked learner details',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    expect(find.text('Child Detail'), findsOneWidget);
    expect(find.text('Ava Learner'), findsOneWidget);
    expect(find.text('Build a Robot'), findsOneWidget);
    expect(find.text('Robotics Studio'), findsOneWidget);
    expect(find.text('View Consent'), findsOneWidget);
  });

  testWidgets('parent child page exports ideation passport with a real file save',
      (WidgetTester tester) async {
    String? savedFileName;
    String? savedFileContent;
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      savedFileName = fileName;
      savedFileContent = content;
      return '/tmp/$fileName';
    };

    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    await tester.tap(find.text('Export Passport'));
    await tester.pumpAndSettle();

    expect(find.text('Ideation Passport downloaded.'), findsOneWidget);
    expect(savedFileName, 'ideation-passport-learner-1.txt');
    expect(savedFileContent, contains('Ideation Passport'));
    expect(savedFileContent, contains('Ava Learner'));
  });

  testWidgets('parent child page fails closed when passport export is unavailable',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw UnsupportedError('File export is not supported on this platform.');
    };

    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    await tester.tap(find.text('Export Passport'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to download Ideation Passport right now.'),
        findsOneWidget);
  });

  testWidgets('parent child page shows explicit not linked state',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-missing'),
    );

    expect(
      find.text('This learner is not linked to your account right now.'),
      findsOneWidget,
    );
    expect(find.text('Open Family Dashboard'), findsOneWidget);
  });
}
