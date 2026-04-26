import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ParentChildLoadSnapshot {
  const _ParentChildLoadSnapshot({
    this.learnerSummaries = const <LearnerSummary>[],
    this.error,
  });

  final List<LearnerSummary> learnerSummaries;
  final String? error;
}

class _SequencedParentService extends ChangeNotifier implements ParentService {
  _SequencedParentService({
    required this.parentId,
    required List<_ParentChildLoadSnapshot> snapshots,
    FirestoreService? firestoreService,
  })  : _snapshots = snapshots,
        firestoreService = firestoreService ??
            FirestoreService(
              firestore: FakeFirebaseFirestore(),
              auth: _FakeFirebaseAuth(),
            );

  final List<_ParentChildLoadSnapshot> _snapshots;

  @override
  final FirestoreService firestoreService;

  @override
  final String parentId;

  List<LearnerSummary> _learnerSummaries = <LearnerSummary>[];
  bool _isLoading = false;
  String? _error;
  int _loadCalls = 0;

  _ParentChildLoadSnapshot _snapshotFor(int index) {
    if (_snapshots.isEmpty) {
      return const _ParentChildLoadSnapshot();
    }
    final int resolvedIndex =
        index < _snapshots.length ? index : _snapshots.length - 1;
    return _snapshots[resolvedIndex];
  }

  @override
  List<LearnerSummary> get learnerSummaries =>
      List<LearnerSummary>.unmodifiable(_learnerSummaries);

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  final BillingSummary? billingSummary = null;

  @override
  Future<void> loadParentData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final _ParentChildLoadSnapshot snapshot = _snapshotFor(_loadCalls++);
    if (snapshot.error == null) {
      _learnerSummaries = List<LearnerSummary>.from(snapshot.learnerSummaries);
    } else {
      _error = snapshot.error;
    }

    _isLoading = false;
    notifyListeners();
  }
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
    ideationPassport: const IdeationPassport(
      reflectionsSubmitted: 2,
      claims: <PassportClaim>[
        PassportClaim(
          capabilityId: 'cap-1',
          title: 'Evidence-backed reasoning',
          pillar: 'Impact',
          latestLevel: 3,
          evidenceCount: 2,
          verifiedArtifactCount: 1,
          aiDisclosureStatus: 'learner-ai-not-used',
        ),
      ],
    ),
    growthTimeline: <GrowthTimelineEntry>[
      GrowthTimelineEntry(
        capabilityId: 'cap-1',
        title: 'Evidence-backed reasoning',
        pillar: 'Impact',
        level: 3,
        linkedEvidenceRecordIds: const <String>['ev-1'],
        linkedPortfolioItemIds: const <String>['portfolio-1'],
        proofOfLearningStatus: 'verified',
        occurredAt: now,
        reviewingEducatorName: 'Coach Rivera',
        rubricRawScore: 3,
        rubricMaxScore: 4,
      ),
    ],
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

  testWidgets(
      'parent child page exports ideation passport with a real file save',
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

    await tester.tap(find.text('Passport Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Passport').last);
    await tester.pumpAndSettle();

    expect(find.text('Ideation Passport downloaded.'), findsOneWidget);
    expect(savedFileName, 'ideation-passport-learner-1.txt');
    expect(savedFileContent, contains('Ideation Passport'));
    expect(savedFileContent, contains('Ava Learner'));
    expect(savedFileContent, contains('Reviewed/Verified Artifacts'));
  });

  testWidgets(
      'parent child page copies passport when file export is unsupported',
      (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

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

    await tester.tap(find.text('Passport Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Passport').last);
    await tester.pumpAndSettle();

    expect(find.text('Ideation Passport copied for sharing.'), findsOneWidget);
    expect(copiedText, contains('Ideation Passport'));
    expect(copiedText, contains('Learner: Ava Learner'));
    expect(copiedText, contains('Reviewed/Verified Artifacts'));
  });

  testWidgets(
      'parent child page fails closed when passport export hits a non-export error',
      (WidgetTester tester) async {
    ExportService.instance.debugSaveTextFile = ({
      required String fileName,
      required String content,
      required String mimeType,
    }) async {
      throw StateError('storage unavailable');
    };

    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    await tester.tap(find.text('Passport Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Passport').last);
    await tester.pumpAndSettle();

    expect(find.text('Unable to download Ideation Passport right now.'),
        findsOneWidget);
  });

  testWidgets('parent child page copies family summary for sharing',
      (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? args = methodCall.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    await tester.tap(find.text('Passport Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Family Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Family summary copied for sharing.'), findsOneWidget);
    expect(copiedText, contains('Scholesa family summary for Ava Learner'));
    expect(copiedText,
        contains('AI disclosure: Learner declared no AI support used'));
    expect(copiedText, contains('Current evidence-backed claims:'));
    expect(copiedText, contains('Recent growth provenance:'));
    expect(copiedText, contains('Evidence-backed reasoning • Proficient'));
    expect(copiedText, contains('1 evidence records linked'));
    expect(copiedText, contains('1 portfolio artifacts linked'));
    expect(copiedText, contains('Pending verification prompts:'));
  });

  testWidgets('parent child page shows explicit not linked state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _FakeFirebaseAuth(),
    );

    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_sampleLearner()],
        firestoreService: firestoreService,
      ),
      child: const ParentChildPage(learnerId: 'learner-missing'),
    );

    expect(
      find.text('This learner is not linked to your account right now.'),
      findsOneWidget,
    );
    expect(find.text('Request Linking Review'), findsOneWidget);
    expect(find.text('Open Family Dashboard'), findsOneWidget);

    await tester.tap(find.text('Request Linking Review'));
    await tester.pumpAndSettle();

    expect(
        find.text('Linked learner review request submitted.'), findsOneWidget);
    final requests = await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    expect(requests.docs.single.data()['requestType'],
        'parent_linked_learner_review');
    expect(requests.docs.single.data()['source'],
        'parent_child_request_linked_learner_review');
  });

  testWidgets(
      'parent child page shows an explicit unavailable state when learner details fail to load',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _SequencedParentService(
        parentId: 'parent-1',
        snapshots: const <_ParentChildLoadSnapshot>[
          _ParentChildLoadSnapshot(error: 'learner detail unavailable'),
        ],
      ),
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    expect(
        find.text('Unable to load learner details right now'), findsOneWidget);
    expect(
      find.text(
          'We could not load this learner right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('This learner is not linked to your account right now.'),
        findsNothing);
  });

  testWidgets(
      'parent child page keeps stale learner details visible when refresh fails',
      (WidgetTester tester) async {
    final _SequencedParentService parentService = _SequencedParentService(
      parentId: 'parent-1',
      snapshots: <_ParentChildLoadSnapshot>[
        _ParentChildLoadSnapshot(
          learnerSummaries: <LearnerSummary>[_sampleLearner()],
        ),
        const _ParentChildLoadSnapshot(error: 'refresh unavailable'),
      ],
    );

    await _pumpPage(
      tester,
      parentService: parentService,
      child: const ParentChildPage(learnerId: 'learner-1'),
    );

    expect(find.text('Ava Learner'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ava Learner'), findsOneWidget);
    expect(
      find.text(
        'Unable to refresh learner details right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
  });
}
