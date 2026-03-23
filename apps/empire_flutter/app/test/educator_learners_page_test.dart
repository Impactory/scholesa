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
import 'package:scholesa_app/modules/educator/educator_sessions_page.dart';
import 'package:scholesa_app/modules/educator/educator_learners_page.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/runtime/runtime.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService() : super(functions: null);

  @override
  Future<List<Map<String, dynamic>>> listCohortLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    return const <Map<String, dynamic>>[];
  }
}

class _FailingLaneOverrideFirestoreService extends FirestoreService {
  _FailingLaneOverrideFirestoreService({
    required super.firestore,
    required super.auth,
  });

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    if (collection == 'learnerDifferentiationPlans') {
      throw StateError('lane override write failed');
    }
    return super.setDocument(
      collection,
      docId,
      data,
      merge: merge,
    );
  }
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
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required FirestoreService firestoreService,
  required EducatorService educatorService,
  BosLearnerLoopInsightsLoader? learnerLoopInsightsLoader,
  SharedPreferences? sharedPreferences,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
      ChangeNotifierProvider<EducatorService>.value(value: educatorService),
    ],
    child: MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
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
      home: EducatorLearnersPage(
        learnerLoopInsightsLoader: learnerLoopInsightsLoader,
        sharedPreferences: sharedPreferences,
      ),
    ),
  );
}

Future<void> _seedLearner(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 68,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

Future<void> _seedCapabilityMastery(
  FakeFirebaseFirestore firestore, {
  required String learnerId,
  required String capabilityId,
  required String pillarCode,
  required int latestLevel,
}) async {
  await firestore
      .collection('capabilityMastery')
      .doc('$learnerId-$capabilityId')
      .set(<String, dynamic>{
    'learnerId': learnerId,
    'siteId': 'site-1',
    'capabilityId': capabilityId,
    'pillarCode': pillarCode,
    'latestLevel': latestLevel,
    'highestLevel': latestLevel,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 23)),
  });
}

Future<void> _seedLearnerTwo(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'displayName': 'Learner Two',
    'email': 'learner-2@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 82,
    'missionsCompleted': 5,
    'futureSkillsProgress': 0.54,
    'leadershipProgress': 0.57,
    'impactProgress': 0.61,
    'enrolledSessionIds': <String>['session-2'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-2')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-2',
    'educatorId': 'educator-1',
    'sessionId': 'session-2',
  });
}

Future<void> _seedSessions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('sessions').doc('session-1').set(<String, dynamic>{
    'title': 'Robotics Studio',
    'siteId': 'site-1',
    'educatorId': 'educator-1',
    'startTime': Timestamp.fromDate(DateTime(2026, 3, 20, 9)),
  });
  await firestore.collection('sessions').doc('session-2').set(<String, dynamic>{
    'title': 'Design Lab',
    'siteId': 'site-1',
    'educatorId': 'educator-1',
    'startTime': Timestamp.fromDate(DateTime(2026, 3, 20, 11)),
  });
}

Future<void> _seedRosterImportSessionData(
    FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  final DateTime startTime = DateTime(now.year, now.month, now.day, 9, 0);
  final DateTime endTime = startTime.add(const Duration(hours: 1));

  await firestore.collection('sessions').doc('session-roster-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'educatorId': 'educator-1',
      'educatorIds': <String>['educator-1'],
      'title': 'Launch Lab',
      'pillar': 'future_skills',
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'location': 'Studio A',
      'status': 'upcoming',
      'enrolledCount': 0,
    },
  );
}

Future<void> _seedLearnerWithoutDisplayName(
    FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 68,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

Finder _laneChip(String label) => find.widgetWithText(ChoiceChip, label);

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('educator learners page persists learner follow-up requests',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Learner One'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Learner follow-up'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.enterText(
      find.byType(TextField).last,
      'Family follow-up needed for attendance dip and lane check-in.',
    );
    await tester.tap(find.text('Request follow-up'));
    await tester.pumpAndSettle();

    expect(find.text('Learner follow-up request submitted.'), findsWidgets);
    final supportRequests = await firestore.collection('supportRequests').get();
    expect(supportRequests.docs.length, 1);
    expect(
        supportRequests.docs.first.data()['requestType'], 'learner_follow_up');
  });

  testWidgets(
      'educator learners page submits learner follow-up requests for learners created through provisioning',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedRosterImportSessionData(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    final EducatorService educatorSessionsService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
          ChangeNotifierProvider<EducatorService>.value(
            value: educatorSessionsService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: EducatorSessionsPage(sharedPreferences: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch Lab').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Import Roster CSV'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Import Roster CSV'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'name,email\nWorkflow Learner,workflow.followup@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Roster import complete: 0 enrolled, 1 queued for provisioning',
      ),
      findsOneWidget,
    );

    final _MockFirebaseAuth provisioningAuth = _MockFirebaseAuth();
    when(() => provisioningAuth.currentUser).thenReturn(null);
    final ProvisioningService provisioningService = ProvisioningService(
      apiClient: ApiClient(auth: provisioningAuth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: provisioningAuth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
          ChangeNotifierProvider<ProvisioningService>.value(
            value: provisioningService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: const ProvisioningPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Workflow Learner',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'workflow.followup@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Learner created successfully'), findsOneWidget);

    final EducatorService educatorLearnersService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorLearnersService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workflow Learner').first);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Learner follow-up'),
      find.byType(Scrollable).last,
      const Offset(0, -120),
    );
    await tester.enterText(
      find.byType(TextField).last,
      'Family follow-up needed after provisioning-based roster handoff.',
    );
    await tester.tap(find.text('Request follow-up'));
    await tester.pumpAndSettle();

    expect(find.text('Learner follow-up request submitted.'), findsWidgets);

    final QuerySnapshot<Map<String, dynamic>> supportRequests =
        await firestore.collection('supportRequests').get();
    expect(supportRequests.docs, hasLength(1));
    final Map<String, dynamic> request = supportRequests.docs.single.data();
    expect(request['requestType'], 'learner_follow_up');
    expect(
      request['source'],
      'educator_learner_detail_request_follow_up',
    );
    expect(
      request['subject'],
      'Learner follow-up request: Workflow Learner',
    );
    expect(
      request['message'],
      'Family follow-up needed after provisioning-based roster handoff.',
    );
    expect(request['role'], 'educator');
    expect(request['siteId'], 'site-1');
    expect((request['metadata'] as Map<String, dynamic>)['learnerName'],
        'Workflow Learner');
    expect((request['metadata'] as Map<String, dynamic>)['learnerEmail'],
        'workflow.followup@example.com');
    expect((request['metadata'] as Map<String, dynamic>)['selectedLane'],
        'scaffolded');
    expect((request['metadata'] as Map<String, dynamic>)['teacherOverride'],
        isFalse);
  });

  testWidgets('educator learners page shows learner unavailable label',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearnerWithoutDisplayName(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Learner unavailable'), findsWidgets);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets('educator learners page discloses synthetic AI help preview',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        learnerLoopInsightsLoader: ({
          required String siteId,
          required String learnerId,
          required int lookbackDays,
        }) async =>
            <String, dynamic>{
          'synthetic': true,
          'state': <String, dynamic>{
            'cognition': 0.73,
            'engagement': 0.64,
            'integrity': 0.9,
          },
          'trend': <String, dynamic>{
            'improvementScore': 0.06,
            'cognitionDelta': 0.02,
            'engagementDelta': 0.01,
            'integrityDelta': 0.01,
          },
          'mvl': <String, dynamic>{
            'active': 1,
            'passed': 0,
            'failed': 0,
          },
          'activeGoals': <String>['Prototype feedback loop'],
          'stateAvailability': <String, dynamic>{
            'hasCurrentState': true,
            'hasTrendBaseline': true,
          },
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Synthetic preview only. Do not treat this as classroom evidence or learner growth.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'educator learners page saves lane taps immediately and reloads overrides',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Learner One'));
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(_laneChip('Scaffolded lane')).selected,
        isTrue);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save lane override'))
            .enabled,
        isFalse);

    await tester.ensureVisible(_laneChip('Stretch lane'));
    await tester.pumpAndSettle();
    await tester.tap(_laneChip('Stretch lane'));
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> savedPlan = await firestore
        .collection('learnerDifferentiationPlans')
        .doc('learner-1_site-1')
        .get();
    expect(savedPlan.exists, isTrue);
    expect(savedPlan.data()?['selectedLane'], 'stretch');
    expect(find.text('Differentiation lane saved'), findsOneWidget);
    expect(
        tester.widget<ChoiceChip>(_laneChip('Stretch lane')).selected, isTrue);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save lane override'))
            .enabled,
        isFalse);

    await tester.tapAt(const Offset(16, 16));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One'));
    await tester.pumpAndSettle();

    expect(
        tester.widget<ChoiceChip>(_laneChip('Stretch lane')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(_laneChip('Scaffolded lane')).selected,
        isFalse);
  });

  testWidgets(
      'educator learners page reverts lane selection when immediate save fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService =
        _FailingLaneOverrideFirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Learner One'));
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(_laneChip('Scaffolded lane')).selected,
        isTrue);

    await tester.ensureVisible(_laneChip('Stretch lane'));
    await tester.pumpAndSettle();
    await tester.tap(_laneChip('Stretch lane'));
    await tester.pumpAndSettle();

    final DocumentSnapshot<Map<String, dynamic>> savedPlan = await firestore
        .collection('learnerDifferentiationPlans')
        .doc('learner-1_site-1')
        .get();
    expect(savedPlan.exists, isFalse);
    expect(
        find.text('Unable to save lane override right now.'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(_laneChip('Scaffolded lane')).selected,
        isTrue);
    expect(
        tester.widget<ChoiceChip>(_laneChip('Stretch lane')).selected, isFalse);
  });

  testWidgets(
      'educator learners page restores search and session filters on reopen',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    await _seedLearnerTwo(firestore);
    await _seedSessions(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );
    await educatorService.loadSessions();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Two');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design Lab'));
    await tester.pumpAndSettle();

    expect(find.text('Learner Two'), findsOneWidget);
    expect(find.text('Learner One'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final EducatorService reopenedService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );
    await reopenedService.loadSessions();

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: reopenedService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Learner Two'), findsOneWidget);
    expect(find.text('Learner One'), findsNothing);
    expect(find.widgetWithText(TextField, 'Two'), findsOneWidget);
  });

  testWidgets(
      'educator learners page shows roster load failure instead of blank roster',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
      learnersLoader: () async {
        throw StateError('load failed from test');
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load learners'), findsOneWidget);
    expect(
      find.text(
          'We could not load learners right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
          'Failed to load learners: Bad state: load failed from test'),
      findsOneWidget,
    );
    expect(find.text('No learners enrolled'), findsNothing);
  });

  testWidgets(
      'educator learners page keeps stale roster visible after refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int loadCount = 0;
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
      learnersLoader: () async {
        loadCount += 1;
        if (loadCount == 1) {
          return EducatorLearnersSnapshot(
            learners: <EducatorLearner>[
              EducatorLearner(
                id: 'learner-1',
                name: 'Learner One',
                email: 'learner-1@scholesa.test',
                attendanceRate: 68,
                missionsCompleted: 3,
                pillarProgress: <String, double>{
                  'future_skills': 0.32,
                  'leadership': 0.48,
                  'impact': 0.41,
                },
                enrolledSessionIds: <String>['session-1'],
              ),
            ],
          );
        }
        throw StateError('refresh failed from test');
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await _scrollUntilVisible(
      tester,
      find.text(
        'Unable to refresh learners right now. Showing the last successful data. Failed to load learners: Bad state: refresh failed from test',
      ),
    );
    expect(
      find.text(
        'Unable to refresh learners right now. Showing the last successful data. Failed to load learners: Bad state: refresh failed from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('No learners enrolled'), findsNothing);
  });

  testWidgets(
      'educator learners page shows learners provisioned from queued roster imports',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedRosterImportSessionData(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    final EducatorService educatorSessionsService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
          ChangeNotifierProvider<EducatorService>.value(
            value: educatorSessionsService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: EducatorSessionsPage(sharedPreferences: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch Lab').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Import Roster CSV'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Import Roster CSV'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'name,email\nWorkflow Learner,workflow@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Roster import complete: 0 enrolled, 1 queued for provisioning',
      ),
      findsOneWidget,
    );

    final _MockFirebaseAuth provisioningAuth = _MockFirebaseAuth();
    when(() => provisioningAuth.currentUser).thenReturn(null);
    final ProvisioningService provisioningService = ProvisioningService(
      apiClient: ApiClient(auth: provisioningAuth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: provisioningAuth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
          ChangeNotifierProvider<ProvisioningService>.value(
            value: provisioningService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: const ProvisioningPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Workflow Learner');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'workflow@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Learner created successfully'), findsOneWidget);

    final EducatorService educatorLearnersService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorLearnersService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Workflow Learner'), findsOneWidget);
    expect(find.text('No learners enrolled'), findsNothing);
  });

  testWidgets(
      'educator learners page shows cross-site learners after they are linked through provisioning',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedRosterImportSessionData(firestore);
    await firestore.collection('users').doc('learner-other-site-1').set(
      <String, dynamic>{
        'displayName': 'Cross Site Learner',
        'email': 'cross-site@example.com',
        'role': 'learner',
        'activeSiteId': 'site-2',
        'siteIds': <String>['site-2'],
      },
    );
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    final EducatorService educatorSessionsService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: _buildEducatorState()),
          ChangeNotifierProvider<EducatorService>.value(
            value: educatorSessionsService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: EducatorSessionsPage(sharedPreferences: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch Lab').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Import Roster CSV'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Import Roster CSV'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'name,email\nCross Site Learner,cross-site@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Roster import complete: 0 enrolled, 1 queued for provisioning',
      ),
      findsOneWidget,
    );

    final QuerySnapshot<Map<String, dynamic>> usersBeforeProvisioning =
        await firestore
            .collection('users')
            .where('email', isEqualTo: 'cross-site@example.com')
            .get();
    expect(usersBeforeProvisioning.docs, hasLength(1));
    expect(usersBeforeProvisioning.docs.single.id, 'learner-other-site-1');

    final _MockFirebaseAuth provisioningAuth = _MockFirebaseAuth();
    when(() => provisioningAuth.currentUser).thenReturn(null);
    final ProvisioningService provisioningService = ProvisioningService(
      apiClient: ApiClient(auth: provisioningAuth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: provisioningAuth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
          ChangeNotifierProvider<ProvisioningService>.value(
            value: provisioningService,
          ),
        ],
        child: MaterialApp(
          theme: ScholesaTheme.light,
          locale: const Locale('en'),
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
          home: const ProvisioningPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Cross Site Learner',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'cross-site@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Learner created successfully'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> usersAfterProvisioning =
        await firestore
            .collection('users')
            .where('email', isEqualTo: 'cross-site@example.com')
            .get();
    expect(usersAfterProvisioning.docs, hasLength(1));
    expect(usersAfterProvisioning.docs.single.id, 'learner-other-site-1');
    expect(
      usersAfterProvisioning.docs.single.data()['siteIds'],
      containsAll(<String>['site-1', 'site-2']),
    );

    final EducatorService educatorLearnersService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorLearnersService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Cross Site Learner'), findsOneWidget);
    expect(find.text('No learners enrolled'), findsNothing);
  });
}
