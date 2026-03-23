import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_portfolio_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

FirestoreService _buildFirestoreService() {
  return FirestoreService(
    firestore: FakeFirebaseFirestore(),
    auth: _FakeFirebaseAuth(),
  );
}

class _StubParentService extends ChangeNotifier implements ParentService {
  _StubParentService({
    required this.parentId,
    required this.learnerSummaries,
    this.error,
    FirestoreService? firestoreService,
  }) : firestoreService = firestoreService ?? _buildFirestoreService();

  @override
  final FirestoreService firestoreService;

  @override
  final String parentId;

  @override
  final List<LearnerSummary> learnerSummaries;

  @override
  final String? error;

  @override
  final bool isLoading = false;

  @override
  final BillingSummary? billingSummary = null;

  int loadCallCount = 0;

  @override
  Future<void> loadParentData() async {
    loadCallCount += 1;
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
    'entitlements': const <dynamic>[],
  });
  return state;
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required ParentService parentService,
  SharedPreferences? sharedPreferences,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        ChangeNotifierProvider<ParentService>.value(value: parentService),
        Provider<LearningRuntimeProvider?>.value(value: null),
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
        home: ParentPortfolioPage(sharedPreferences: sharedPreferences),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LearnerSummary _buildLearnerSummaryWithPortfolioItems() {
  return LearnerSummary(
    learnerId: 'learner-1',
    learnerName: 'Asha Example',
    currentLevel: 4,
    totalXp: 180,
    missionsCompleted: 6,
    currentStreak: 3,
    attendanceRate: 0.95,
    portfolioSnapshot: const PortfolioSnapshot(
      artifactCount: 2,
      publishedArtifactCount: 2,
      badgeCount: 1,
      projectCount: 1,
      evidenceLinkedArtifactCount: 2,
      verifiedArtifactCount: 1,
    ),
    portfolioItemsPreview: <PortfolioPreviewItem>[
      PortfolioPreviewItem(
        id: 'project-1',
        title: 'Solar Oven Prototype',
        description: 'Built and tested a heat-retention prototype.',
        pillar: 'Impact',
        type: 'project',
        completedAt: DateTime(2026, 3, 20),
      ),
      PortfolioPreviewItem(
        id: 'badge-1',
        title: 'Community Helper Badge',
        description: 'Recognized for helping peers during build time.',
        pillar: 'Leadership',
        type: 'badge',
        completedAt: DateTime(2026, 3, 19),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'parent portfolio page shows explicit load error instead of fake empty portfolio copy',
      (WidgetTester tester) async {
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: const <LearnerSummary>[],
      error: 'Failed to load data: portfolio unavailable',
    );

    await _pumpPage(
      tester,
      parentService: service,
    );

    expect(find.text('Unable to load portfolio right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No items yet'), findsNothing);
    final int loadCallCountAfterMount = service.loadCallCount;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.loadCallCount, loadCallCountAfterMount + 1);
  });

  testWidgets(
      'parent portfolio AI coach shows unavailable message and selections persist on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: <LearnerSummary>[
        _buildLearnerSummaryWithPortfolioItems(),
      ],
    );

    await _pumpPage(
      tester,
      parentService: service,
      sharedPreferences: prefs,
    );

    expect(find.text('Reviewed/Verified Portfolio'), findsOneWidget);
    expect(find.text('Reviewed/Verified'), findsOneWidget);
    expect(find.text('Solar Oven Prototype'), findsOneWidget);
    expect(find.text('Community Helper Badge'), findsOneWidget);
    expect(find.text('AI guidance unavailable right now.'), findsNothing);

    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();

    expect(find.text('Community Helper Badge'), findsOneWidget);
    expect(find.text('Solar Oven Prototype'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(
      find.text(
        'Your learner snapshots and saved portfolio evidence are still available while AI guidance reconnects.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpPage(
      tester,
      parentService: service,
      sharedPreferences: prefs,
    );

    expect(find.text('Community Helper Badge'), findsOneWidget);
    expect(find.text('Solar Oven Prototype'), findsNothing);
    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });
}
