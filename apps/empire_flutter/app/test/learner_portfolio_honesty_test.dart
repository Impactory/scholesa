import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/modules/educator/educator_mission_review_page.dart';
import 'package:scholesa_app/modules/missions/mission_service.dart';
import 'package:scholesa_app/modules/missions/missions_page.dart';
import 'package:scholesa_app/modules/learner/learner_portfolio_page.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AppState _buildLearnerState({
  String activeSiteId = 'site-1',
  List<String> siteIds = const <String>['site-1'],
}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'learner-1',
    'email': 'learner-1@scholesa.test',
    'displayName': 'Test User',
    'role': 'learner',
    'activeSiteId': activeSiteId,
    'siteIds': siteIds,
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

AppState _buildEducatorState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  FirestoreService? firestoreService,
  SharedPreferences? sharedPreferences,
  LearnerPortfolioPage? child,
}) {
  final List<SingleChildWidget> providers = <SingleChildWidget>[
    ChangeNotifierProvider<AppState>.value(value: appState),
    Provider<LearningRuntimeProvider?>.value(value: null),
  ];
  if (firestoreService != null) {
    providers.add(Provider<FirestoreService>.value(value: firestoreService));
  }

  return MultiProvider(
    providers: providers,
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
      home: child ?? LearnerPortfolioPage(sharedPreferences: sharedPreferences),
    ),
  );
}

Widget _buildLearnerMissionHarness({
  required FirestoreService firestoreService,
  required MissionService missionService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildLearnerState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
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
      home: const MissionsPage(),
    ),
  );
}

Widget _buildEducatorReviewHarness({
  required FirestoreService firestoreService,
  required MissionService missionService,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<MissionService>.value(value: missionService),
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
      home: const EducatorMissionReviewPage(),
    ),
  );
}

Future<void> _seedCompletedMissionReadyForReview(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('users').doc('learner-1').set(
    <String, dynamic>{
      'displayName': 'Test User',
      'role': 'learner',
      'siteIds': <String>['site-1'],
    },
  );
  await firestore.collection('missionAssignments').doc('assignment-1').set(
    <String, dynamic>{
      'missionId': 'mission-1',
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'status': 'in_progress',
      'progress': 1.0,
    },
  );
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'title': 'Mission ready for review',
      'description': 'Capture proof of learning before review.',
      'pillarCode': 'future_skills',
      'difficulty': 'beginner',
      'xpReward': 120,
    },
  );
  await firestore
      .collection('missions')
      .doc('mission-1')
      .collection('steps')
      .doc('step-1')
      .set(
    <String, dynamic>{
      'title': 'Prototype',
      'order': 1,
      'isCompleted': true,
      'completedAt': '2026-03-18T10:00:00.000Z',
    },
  );
}

Future<void> _seedReviewRubricAndEvidence(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('missions').doc('mission-1').set(
    <String, dynamic>{
      'rubricId': 'rubric-1',
      'rubricTitle': 'Prototype Rubric',
    },
    SetOptions(merge: true),
  );
  await firestore.collection('rubrics').doc('rubric-1').set(
    <String, dynamic>{
      'title': 'Prototype Rubric',
      'criteria': <Map<String, dynamic>>[
        <String, dynamic>{
          'criterionId': 'evidence',
          'label': 'Evidence',
          'capabilityId': 'cap-prototype-evidence',
          'capabilityTitle': 'Prototype evidence',
          'pillarCode': 'future_skills',
          'maxScore': 4,
        },
        <String, dynamic>{
          'criterionId': 'reflection',
          'label': 'Reflection',
          'capabilityId': 'cap-prototype-evidence',
          'capabilityTitle': 'Prototype evidence',
          'pillarCode': 'future_skills',
          'maxScore': 4,
        },
      ],
    },
  );
  await firestore.collection('evidenceRecords').doc('evidence-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'capabilityId': 'cap-prototype-evidence',
      'capabilityLabel': 'Prototype evidence',
      'capabilityPillarCode': 'future_skills',
      'observationNote':
          'Learner connected prototype choices to observed tradeoffs.',
      'artifactUrls': const <String>['https://example.com/prototype.png'],
      'nextVerificationPrompt':
          'Explain why this prototype path best matched the evidence.',
      'portfolioCandidate': true,
      'growthStatus': 'captured',
      'observedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8, 45)),
    },
  );
}

Future<void> _submitMissionForReview(
  WidgetTester tester, {
  required FirestoreService firestoreService,
  required MissionService missionService,
}) async {
  await tester.pumpWidget(
    _buildLearnerMissionHarness(
      firestoreService: firestoreService,
      missionService: missionService,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();

  await tester.tap(find.text('In Progress'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('No AI support used for this mission'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('No AI support used for this mission'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Explain-it-back summary'),
    'I explained how the control loop reacts to sensor input.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Oral check reflection'),
    'I described the trade-off between speed and stability.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Mini-rebuild plan'),
    'I would rebuild the sensor branch first and retest the response.',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Artifact links (one per line)'),
    'https://example.com/prototype.png',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Version checkpoint summary'),
    'Completed the working prototype before review.',
  );

  await tester.scrollUntilVisible(
    find.text('Save Checkpoint'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Save Checkpoint'));
  await tester.pump();
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Submit for Review'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Submit for Review'));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _approveMissionWithRubric(
  WidgetTester tester, {
  required FirestoreService firestoreService,
  required MissionService missionService,
}) async {
  await tester.pumpWidget(
    _buildEducatorReviewHarness(
      firestoreService: firestoreService,
      missionService: missionService,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Mission ready for review').first);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Reflection'),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('4/4').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('3/4').at(1));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField).last,
    'Great iteration. Tighten the evidence trail and explain the tradeoffs in your next revision.',
  );
  await tester.scrollUntilVisible(
    find.text('Approve'),
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Approve'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'learner portfolio uses site unavailable in the fallback headline when site identity is missing',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState:
            _buildLearnerState(activeSiteId: '', siteIds: const <String>[]),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Future Innovator • Site unavailable'), findsOneWidget);
    expect(find.text('site-1'), findsNothing);
  });

  testWidgets(
      'learner portfolio badges tab renders live credentials instead of a fake empty state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('credentials').doc('credential-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'title': 'Impact Builder',
        'issuedAt': Timestamp.fromDate(DateTime(2026, 3, 18)),
        'pillarCodes': const <String>['impact'],
        'skillIds': const <String>['prototype'],
      },
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('Issued 3/18/2026'), findsOneWidget);
    expect(find.text('No badges earned yet'), findsNothing);
  });

  testWidgets(
      'learner portfolio edit reports storage unavailable instead of pretending the profile was saved',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Portfolio Headline'),
      'Stored headline that should not persist',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Profile storage unavailable right now.'), findsOneWidget);
    expect(find.text('Portfolio profile updated.'), findsNothing);
    expect(find.text('Stored headline that should not persist'), findsNothing);
  });

  testWidgets(
      'learner portfolio AI coach shows an unavailable message and stays expanded on reopen',
      (WidgetTester tester) async {
    final FirestoreService firestoreService = FirestoreService(
      firestore: FakeFirebaseFirestore(),
      auth: _MockFirebaseAuth(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Showcase your saved work and credentials'), findsOneWidget);
    expect(find.text('Showcase your achievements'), findsNothing);
    expect(
      find.text(
        'Get experimental AI insights on your saved work and goals. These notes do not replace your evidence record.',
      ),
      findsOneWidget,
    );
    expect(find.text('AI guidance unavailable right now.'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(
      find.text(
        'Your saved badges, skills, and projects are still available while AI reflection reconnects.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI guidance unavailable right now.'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets(
      'learner portfolio keeps stale evidence visible after refresh failure',
      (WidgetTester tester) async {
    int loadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: FirestoreService(
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
        ),
        child: LearnerPortfolioPage(
          portfolioStateLoader: (String learnerId, String siteId) async {
            loadCount += 1;
            if (loadCount == 1) {
              return LearnerPortfolioSnapshot(
                profile: LearnerProfileModel(
                  id: 'profile-1',
                  learnerId: learnerId,
                  siteId: siteId,
                  onboardingCompleted: true,
                  portfolioHeadline: 'Impact builder in progress',
                  portfolioGoal: 'Ship one verified artifact each week',
                  portfolioHighlight: 'Latest highlight: Water prototype',
                  strengths: const <String>['Collaboration'],
                  interests: const <String>['Robotics'],
                  goals: const <String>['Prototype testing'],
                ),
                items: <PortfolioItemModel>[
                  PortfolioItemModel(
                    id: 'portfolio-1',
                    learnerId: learnerId,
                    siteId: siteId,
                    title: 'Water prototype',
                    description: 'Built and documented a first prototype.',
                    pillarCodes: const <String>['impact'],
                    capabilityTitles: const <String>['Systems Thinking'],
                    evidenceRecordIds: const <String>['evidence-1'],
                    createdAt: Timestamp.fromDate(DateTime(2026, 3, 18)),
                    updatedAt: Timestamp.fromDate(DateTime(2026, 3, 19)),
                  ),
                ],
                credentials: <CredentialModel>[
                  CredentialModel(
                    id: 'credential-1',
                    siteId: siteId,
                    learnerId: learnerId,
                    title: 'Impact Builder',
                    issuedAt: Timestamp.fromDate(DateTime(2026, 3, 18)),
                    pillarCodes: const <String>['impact'],
                    skillIds: const <String>['prototype'],
                  ),
                ],
              );
            }
            throw StateError('portfolio refresh unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('Water prototype'), findsNothing);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh portfolio right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Impact Builder'), findsOneWidget);
    expect(find.text('No badges earned yet'), findsNothing);
  });

  testWidgets(
      'learner portfolio renders reviewed artifacts created by the live educator mission review flow',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    await _seedCompletedMissionReadyForReview(firestore);
    await _seedReviewRubricAndEvidence(firestore);

    final MissionService learnerMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'learner-1',
    );
    final MissionService educatorMissionService = MissionService(
      firestoreService: firestoreService,
      learnerId: 'educator-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _submitMissionForReview(
      tester,
      firestoreService: firestoreService,
      missionService: learnerMissionService,
    );
    await _approveMissionWithRubric(
      tester,
      firestoreService: firestoreService,
      missionService: educatorMissionService,
    );

    final DocumentSnapshot<Map<String, dynamic>> portfolioDoc =
        await firestore.collection('portfolioItems').doc('evidence-1').get();
    expect(portfolioDoc.exists, isTrue);
    expect(portfolioDoc.data()?['proofCheckpointCount'], 1);
    expect(
      portfolioDoc.data()?['artifactUrls'],
      contains('https://example.com/prototype.png'),
    );
    expect(
      portfolioDoc.data()?['description'],
      contains('Completed the working prototype before review.'),
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Mission ready for review • Prototype evidence'),
        findsOneWidget);
    expect(find.text('Future Skills'), findsWidgets);
    expect(find.text('Evidence linked • Reviewed'), findsOneWidget);
    expect(find.text('Prototype evidence'), findsOneWidget);
    expect(
      find.text(
          'Capability update: Prototype evidence • Level 4 • Reviewed score 7/8'),
      findsOneWidget,
    );
    expect(find.text('Proof of learning: Verified'), findsOneWidget);
    expect(
      find.text(
        'Proof checks: Explain-it-back, Oral check, Mini-rebuild, 1 checkpoint',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Explain-it-back note: I explained how the control loop reacts to sensor input.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Oral check note: I described the trade-off between speed and stability.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Mini-rebuild note: I would rebuild the sensor branch first and retest the response.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Checkpoint summary: Completed the working prototype before review.',
      ),
      findsOneWidget,
    );
    expect(find.text('Artifacts linked: 1 artifact'), findsOneWidget);
    expect(
      find.text('AI disclosure: Learner said no AI support was used'),
      findsOneWidget,
    );
    expect(find.text('No projects added yet'), findsNothing);
  });

  testWidgets(
      'learner portfolio keeps pending submissions out of reviewed portfolio counts and labels them awaiting educator review',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    await firestore.collection('learnerProfiles').doc('profile-1').set(
      <String, dynamic>{
        'learnerId': 'learner-1',
        'siteId': 'site-1',
        'portfolioHeadline': 'Evidence builder',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 8)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9)),
      },
    );
    await firestore.collection('portfolioItems').doc('reviewed-project').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'title': 'Reviewed robot prototype',
        'description': 'Reviewed evidence-backed prototype artifact.',
        'pillarCodes': const <String>['future_skills'],
        'evidenceRecordIds': const <String>['evidence-1'],
        'capabilityTitles': const <String>['Prototype evidence'],
        'checkpointSummary':
            'Checkpoint summary carried into the reviewed portfolio item.',
        'reflectionNote': 'Reviewed reflection captured by educator.',
        'verificationStatus': 'reviewed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 10)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 11)),
      },
    );
    await firestore.collection('portfolioItems').doc('pending-project').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'learner-1',
        'title': 'Draft field notes',
        'description': 'Saved after class and still awaiting educator review.',
        'pillarCodes': const <String>['impact'],
        'verificationStatus': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 18, 12)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 13)),
      },
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildLearnerState(),
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Projects: 1'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Reviewed robot prototype'), findsOneWidget);
    expect(find.text('Evidence linked • Reviewed'), findsOneWidget);
    expect(
      find.text(
        'Checkpoint summary: Checkpoint summary carried into the reviewed portfolio item.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Reflection: Reviewed reflection captured by educator.'),
      findsOneWidget,
    );
    expect(find.text('Draft field notes'), findsOneWidget);
    expect(find.text('Awaiting educator review'), findsWidgets);
    expect(
      find.text(
        'These saved submissions are not part of your reviewed portfolio yet.',
      ),
      findsOneWidget,
    );
  });
}
