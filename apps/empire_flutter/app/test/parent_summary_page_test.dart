import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
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

class _UnavailableParentService extends _StubParentService {
  _UnavailableParentService({
    required super.parentId,
    required super.learnerSummaries,
  });

  @override
  FirestoreService get firestoreService {
    throw StateError('Support requests are unavailable right now.');
  }
}

class _ParentLoadSnapshot {
  const _ParentLoadSnapshot({
    this.learnerSummaries = const <LearnerSummary>[],
    this.error,
  });

  final List<LearnerSummary> learnerSummaries;
  final String? error;
}

class _SequencedParentService extends ChangeNotifier implements ParentService {
  _SequencedParentService({
    required this.parentId,
    required List<_ParentLoadSnapshot> snapshots,
    FirestoreService? firestoreService,
  })  : _snapshots = snapshots,
        firestoreService = firestoreService ??
            FirestoreService(
              firestore: FakeFirebaseFirestore(),
              auth: _FakeFirebaseAuth(),
            );

  final List<_ParentLoadSnapshot> _snapshots;

  @override
  final FirestoreService firestoreService;

  @override
  final String parentId;

  List<LearnerSummary> _learnerSummaries = <LearnerSummary>[];
  bool _isLoading = false;
  String? _error;
  int _loadCalls = 0;

  _ParentLoadSnapshot _snapshotFor(int index) {
    if (_snapshots.isEmpty) {
      return const _ParentLoadSnapshot();
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

    final _ParentLoadSnapshot snapshot = _snapshotFor(_loadCalls++);
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

LearnerSummary _richLearnerSummary() {
  final DateTime now = DateTime(2026, 3, 24, 10, 30);
  return LearnerSummary(
    learnerId: 'learner-1',
    learnerName: 'Avery Stone',
    currentLevel: 3,
    totalXp: 120,
    missionsCompleted: 4,
    currentStreak: 6,
    attendanceRate: 0.92,
    recentActivities: const <RecentActivity>[],
    upcomingEvents: const <UpcomingEvent>[],
    pillarProgress: const <String, double>{
      'futureSkills': 0.70,
      'leadership': 0.65,
      'impact': 0.60,
    },
    capabilitySnapshot: const CapabilitySnapshot(
      overall: 0.80,
      band: 'developing',
    ),
    evidenceSummary: const EvidenceSummary(
      recordCount: 5,
      reviewedCount: 3,
      verificationPromptCount: 1,
    ),
    growthSummary: GrowthSummary(
      capabilityCount: 2,
      updatedCapabilityCount: 2,
      averageLevel: 3.0,
      latestLevel: 3,
      latestGrowthAt: now,
    ),
    portfolioSnapshot: PortfolioSnapshot(
      artifactCount: 2,
      verifiedArtifactCount: 1,
      latestArtifactAt: now,
    ),
    portfolioItemsPreview: <PortfolioPreviewItem>[
      PortfolioPreviewItem(
        id: 'portfolio-1',
        title: 'Prototype Evidence',
        description: 'Reviewed prototype reflection.',
        pillar: 'Impact',
        type: 'project',
        completedAt: now.subtract(const Duration(days: 1)),
        verificationStatus: 'reviewed',
        evidenceLinked: true,
        verificationPrompt:
            'Review: Ask the learner to justify the prototype path without prompts.',
        progressionDescriptors: const <String>[
          'Learner explains why the prototype choice fits the observed evidence.',
          'Learner identifies a tradeoff and defends the decision with examples.',
        ],
        checkpointMappings: const <VerificationCheckpointMapping>[
          VerificationCheckpointMapping(
            phase: 'review',
            guidance:
                'Ask the learner to justify the prototype path without prompts.',
          ),
        ],
        proofOfLearningStatus: 'verified',
        aiDisclosureStatus: 'learner-ai-not-used',
        aiAssistanceDetails:
            'Learner noted that the prototype notes were drafted without AI support.',
        reviewingEducatorName: 'Coach Rivera',
        rubricLevel: 3,
      ),
    ],
    ideationPassport: IdeationPassport(
      reflectionsSubmitted: 2,
      claims: <PassportClaim>[
        PassportClaim(
          capabilityId: 'cap-1',
          title: 'Evidence-backed reasoning',
          pillar: 'Impact',
          latestLevel: 3,
          evidenceCount: 3,
          verifiedArtifactCount: 1,
          progressionDescriptors: const <String>[
            'Learner explains why the prototype choice fits the observed evidence.',
          ],
          checkpointMappings: const <VerificationCheckpointMapping>[
            VerificationCheckpointMapping(
              phase: 'review',
              guidance:
                  'Ask the learner to justify the prototype path without prompts.',
            ),
          ],
          proofOfLearningStatus: 'verified',
          aiDisclosureStatus: 'learner-ai-not-used',
          aiHasLearnerDisclosure: true,
          aiAssistanceDetails:
              'Learner noted that the prototype notes were drafted without AI support.',
          latestEvidenceAt: now,
          verificationStatus: 'reviewed',
          reviewingEducatorName: 'Coach Rivera',
          reviewedAt: now,
          rubricRawScore: 3,
          rubricMaxScore: 4,
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
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
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
        home: const ParentSummaryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ExportService.instance.debugSaveTextFile = null;
  });

  testWidgets(
      'parent summary empty state persists linked learner review requests',
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
        learnerSummaries: const <LearnerSummary>[],
        firestoreService: firestoreService,
      ),
    );

    expect(find.text('No learners linked'), findsOneWidget);
    expect(find.text('Request Linking Review'), findsOneWidget);
    await tester.tap(find.text('Request Linking Review'));
    await tester.pumpAndSettle();

    expect(
        find.text('Linked learner review request submitted.'), findsOneWidget);
    final requests = await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    expect(requests.docs.single.data()['requestType'],
        'parent_linked_learner_review');
    expect(requests.docs.single.data()['source'],
        'parent_summary_request_linked_learner_review');
  });

  testWidgets(
      'parent summary empty state fails closed when support requests are unavailable',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _UnavailableParentService(
        parentId: 'parent-1',
        learnerSummaries: const <LearnerSummary>[],
      ),
    );

    await tester.tap(find.text('Request Linking Review'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to submit linked learner review right now.'),
        findsOneWidget);
  });

  testWidgets(
      'parent summary shows an explicit unavailable state instead of a fake empty family',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _SequencedParentService(
        parentId: 'parent-1',
        snapshots: const <_ParentLoadSnapshot>[
          _ParentLoadSnapshot(error: 'parent dashboard unavailable'),
        ],
      ),
    );

    expect(
      find.text('Family dashboard is temporarily unavailable'),
      findsOneWidget,
    );
    expect(
      find.text(
        'We could not load your linked learners right now. Retry to check the current state.',
      ),
      findsOneWidget,
    );
    expect(find.text('No learners linked'), findsNothing);
  });

  testWidgets(
      'parent summary keeps stale learner data visible when a refresh fails',
      (WidgetTester tester) async {
    final _SequencedParentService parentService = _SequencedParentService(
      parentId: 'parent-1',
      snapshots: <_ParentLoadSnapshot>[
        _ParentLoadSnapshot(
          learnerSummaries: <LearnerSummary>[
            LearnerSummary(
              learnerId: 'learner-1',
              learnerName: 'Avery Stone',
              currentLevel: 3,
              totalXp: 120,
              missionsCompleted: 4,
              currentStreak: 6,
              attendanceRate: 92,
              recentActivities: const <RecentActivity>[],
              upcomingEvents: const <UpcomingEvent>[],
              pillarProgress: const <String, double>{
                'future_skills': 0.70,
                'leadership': 0.65,
                'impact': 0.60,
              },
            ),
          ],
        ),
        const _ParentLoadSnapshot(error: 'refresh failed'),
      ],
    );

    await _pumpPage(
      tester,
      parentService: parentService,
    );

    expect(find.text('Avery Stone'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Avery Stone'), findsOneWidget);
    expect(
      find.text(
        'Unable to refresh family dashboard right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('No learners linked'), findsNothing);
  });

  testWidgets(
      'parent summary surfaces evidence-backed capability descriptors and verification guidance',
      (WidgetTester tester) async {
    await _pumpPage(
      tester,
      parentService: _StubParentService(
        parentId: 'parent-1',
        learnerSummaries: <LearnerSummary>[_richLearnerSummary()],
      ),
    );

    expect(find.text('Capability Snapshot'), findsOneWidget);
    expect(find.text('Evidence-backed capability focus'), findsOneWidget);
    expect(find.textContaining('Evidence-backed reasoning'), findsWidgets);
    expect(find.text('Progression Descriptors'), findsOneWidget);
    expect(
      find.textContaining(
        'Learner explains why the prototype choice fits the observed evidence.',
      ),
      findsWidgets,
    );
    expect(find.text('Verification Criteria'), findsOneWidget);
    expect(
      find.textContaining(
        'Review: Ask the learner to justify the prototype path without prompts.',
      ),
      findsWidgets,
    );
    expect(find.text('Proof of Learning'), findsOneWidget);
    expect(find.textContaining('Coach Rivera'), findsWidgets);
  });

  testWidgets('parent summary exports a family-safe dashboard summary',
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
        learnerSummaries: <LearnerSummary>[_richLearnerSummary()],
      ),
    );

    await tester.tap(find.byTooltip('Summary Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Summary').last);
    await tester.pumpAndSettle();

    expect(find.text('Family summary exported.'), findsOneWidget);
    expect(savedFileName, 'family-summary-learner-1.txt');
    expect(savedFileContent, contains('Family Dashboard Summary'));
    expect(savedFileContent, contains('What can this learner do now?'));
    expect(savedFileContent, contains('Recent growth timeline'));
    expect(savedFileContent, contains('AI Disclosure'));
    expect(savedFileContent, contains('Learner declared no AI support used'));
  });

  testWidgets('parent summary copies a family-safe share summary',
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
        learnerSummaries: <LearnerSummary>[_richLearnerSummary()],
      ),
    );

    await tester.tap(find.byTooltip('Summary Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Family Summary').last);
    await tester.pumpAndSettle();

    expect(find.text('Family summary copied for sharing.'), findsOneWidget);
    expect(copiedText, contains('Scholesa family summary for Avery Stone'));
    expect(copiedText,
        contains('AI disclosure: Learner declared no AI support used'));
    expect(copiedText, contains('Current evidence-backed focus:'));
    expect(copiedText, contains('Recent growth provenance:'));
    expect(copiedText, contains('Evidence-backed reasoning • Proficient'));
    expect(copiedText, contains('1 evidence records linked'));
    expect(copiedText, contains('1 portfolio artifacts linked'));
    expect(copiedText, contains('Next verification prompt:'));
  });
}
