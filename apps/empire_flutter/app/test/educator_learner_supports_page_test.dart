import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_learner_supports_page.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FailingSupportPlanFirestoreService extends FirestoreService {
  _FailingSupportPlanFirestoreService({
    required super.firestore,
    required super.auth,
  });

  @override
  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    if (collection == 'learnerSupportPlans') {
      throw StateError('support plan write failed');
    }
    return super.createDocument(collection, data);
  }

  @override
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (collection == 'learnerSupportPlans') {
      throw StateError('support plan write failed');
    }
    return super.updateDocument(collection, docId, data);
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

Widget _buildHarness({
  required FirestoreService firestoreService,
  required EducatorService educatorService,
  LearnerSupportPlansLoader? supportPlansLoader,
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
      home: EducatorLearnerSupportsPage(
        supportPlansLoader: supportPlansLoader,
      ),
    ),
  );
}

EducatorLearner _sampleLearner({
  String id = 'learner-1',
  String name = 'Learner One',
  int attendanceRate = 58,
}) {
  return EducatorLearner(
    id: id,
    name: name,
    email: '$id@scholesa.test',
    attendanceRate: attendanceRate,
    missionsCompleted: 3,
    pillarProgress: const <String, double>{
      'future_skills': 0.32,
      'leadership': 0.48,
      'impact': 0.41,
    },
    enrolledSessionIds: const <String>['session-1'],
  );
}

Future<void> _seedLearner(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner-1@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 58,
    'missionsCompleted': 3,
    'futureSkillsProgress': 0.32,
    'leadershipProgress': 0.48,
    'impactProgress': 0.41,
    'enrolledSessionIds': <String>['session-1'],
  });
  await firestore.collection('enrollments').doc('enrollment-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'educatorId': 'educator-1',
    'sessionId': 'session-1',
  });
}

Future<void> _seedSecondLearner(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'displayName': 'Learner Two',
    'email': 'learner-2@scholesa.test',
    'siteId': 'site-1',
    'attendanceRate': 91,
    'missionsCompleted': 8,
    'futureSkillsProgress': 0.72,
    'leadershipProgress': 0.64,
    'impactProgress': 0.59,
    'enrolledSessionIds': <String>['session-2'],
  });
  await firestore.collection('enrollments').doc('enrollment-2').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-2',
    'educatorId': 'educator-1',
    'sessionId': 'session-2',
  });
}

Future<List<Map<String, dynamic>>> _captureTelemetry(
  Future<void> Function() body,
) async {
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  await TelemetryService.runWithDispatcher(
    (Map<String, dynamic> payload) async {
      events.add(Map<String, dynamic>.from(payload));
    },
    body,
  );
  return events;
}

void main() {
  testWidgets('educator learner supports page renders support plan from live learner data',
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

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Active Support Plans'), findsOneWidget);
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('Check-in support'), findsOneWidget);
    expect(find.text('Peer buddy'), findsOneWidget);
    expect(find.text('No support plans yet'), findsNothing);
  });

  testWidgets('educator learner supports page shows a blocking error when learner load fails on first load',
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
        throw StateError('learner roster unavailable');
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

    expect(
      find.text('We could not load learner supports right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed to load learners:'), findsOneWidget);
    expect(find.text('No support plans yet'), findsNothing);
    expect(find.text('Learner One'), findsNothing);
  });

  testWidgets('educator learner supports page shows a blocking error when saved support plans fail on first load',
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
      learnersLoader: () async => EducatorLearnersSnapshot(
        learners: <EducatorLearner>[_sampleLearner()],
      ),
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        supportPlansLoader: (_, __) async {
          throw StateError('support plan query unavailable');
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('We could not load learner supports right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed to load learner supports:'), findsOneWidget);
    expect(find.text('Active Support Plans'), findsNothing);
    expect(find.text('No support plans yet'), findsNothing);
  });

  testWidgets('educator learner supports page persists edited support plans',
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

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Behavioral').last);
    await tester.pumpAndSettle();

    final Finder priorityField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is DropdownButtonFormField &&
          widget.decoration.labelText == 'Priority',
    );
    await tester.tap(priorityField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'Visual checklist, Flexible seating',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Updated support plan with visual cues.',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Support plan updated.'), findsOneWidget);
    expect(find.text('Log Support Outcome'), findsOneWidget);

    await tester.tap(find.text('Helped'));
    await tester.pumpAndSettle();

    final List<Map<String, dynamic>> plans = (await firestore
            .collection('learnerSupportPlans')
            .get())
        .docs
        .map((doc) => doc.data())
        .toList();
    final List<Map<String, dynamic>> outcomes = (await firestore
        .collection('learnerSupportOutcomes')
        .get())
      .docs
      .map((doc) => doc.data())
      .toList();

    expect(plans, hasLength(1));
    expect(plans.single['siteId'], 'site-1');
    expect(plans.single['learnerId'], 'learner-1');
    expect(plans.single['supportType'], 'Behavioral');
    expect(
      plans.single['accommodations'],
      <String>['Visual checklist', 'Flexible seating'],
    );
    expect(plans.single['priority'], 'medium');
    expect(plans.single['notes'], 'Updated support plan with visual cues.');
    expect(outcomes, hasLength(1));
    expect(outcomes.single['siteId'], 'site-1');
    expect(outcomes.single['learnerId'], 'learner-1');
    expect(outcomes.single['supportType'], 'Behavioral');
    expect(outcomes.single['priority'], 'medium');
    expect(outcomes.single['outcome'], 'helped');

    expect(find.text('Behavioral'), findsOneWidget);
    expect(find.text('Visual checklist'), findsOneWidget);
    expect(find.text('Flexible seating'), findsOneWidget);
  });

  testWidgets('educator learner supports page re-reads persisted plan before settling success',
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
    int supportPlanLoadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        supportPlansLoader: (_, __) async {
          supportPlanLoadCount += 1;
          if (supportPlanLoadCount == 1) {
            return <Map<String, dynamic>>[];
          }
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'documentId': 'plan-1',
              'learnerId': 'learner-1',
              'supportType': 'Behavioral',
              'accommodations': <String>['Visual checklist', 'Teacher conference'],
              'notes': 'Persisted canonical support plan.',
              'priority': 'medium',
              'lastUpdated': Timestamp.fromDate(DateTime(2026, 3, 21, 10)),
            },
          ];
        },
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Behavioral').last);
    await tester.pumpAndSettle();

    final Finder priorityField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is DropdownButtonFormField &&
          widget.decoration.labelText == 'Priority',
    );
    await tester.tap(priorityField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'Visual checklist, Teacher conference',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Persisted canonical support plan.',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(supportPlanLoadCount, 2);
    expect(find.text('Support plan updated.'), findsOneWidget);
    expect(find.text('Log Support Outcome'), findsOneWidget);
    expect(find.text('Teacher conference'), findsOneWidget);
  });

  testWidgets('educator learner supports page fails closed when persisted reload fails after save',
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
    int supportPlanLoadCount = 0;

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        supportPlansLoader: (_, __) async {
          supportPlanLoadCount += 1;
          if (supportPlanLoadCount == 1) {
            return <Map<String, dynamic>>[];
          }
          throw StateError('persisted support plan reload unavailable');
        },
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(supportPlanLoadCount, 2);
    expect(find.text('Support plan updated.'), findsNothing);
    expect(find.text('Log Support Outcome'), findsNothing);
    expect(find.text('Edit Support Plan'), findsOneWidget);
    expect(
      find.text(
        'Support plan was submitted, but persisted support data could not be reloaded. Retry to verify the current state.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('educator learner supports page fails closed when support plan save fails',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    final FirestoreService firestoreService = _FailingSupportPlanFirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learner One').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Unable to update support plan right now.'), findsOneWidget);
    expect(find.text('Log Support Outcome'), findsNothing);
    expect(find.text('Edit Support Plan'), findsOneWidget);
  });

  testWidgets('educator learner supports page logs support plan update telemetry',
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

    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.binding.setSurfaceSize(const Size(1280, 1800));
      await tester.pumpWidget(
        _buildHarness(
          firestoreService: firestoreService,
          educatorService: educatorService,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Learner One').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Behavioral').last);
      await tester.pumpAndSettle();

      final Finder priorityField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is DropdownButtonFormField &&
            widget.decoration.labelText == 'Priority',
      );
      await tester.tap(priorityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(0),
        'Visual checklist, Teacher conference',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Telemetry support note.',
      );

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
    });
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(
      events.any((Map<String, dynamic> event) {
        final Map<String, dynamic> metadata =
            Map<String, dynamic>.from(event['metadata'] as Map);
        return event['event'] == 'support.plan_updated' &&
            metadata['learner_id'] == 'learner-1' &&
            metadata['support_type'] == 'Behavioral' &&
            metadata['priority'] == 'medium' &&
            metadata['accommodation_count'] == 2;
      }),
      isTrue,
    );
  });

  testWidgets('educator learner supports search filters the visible inventory',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedLearner(firestore);
    await _seedSecondLearner(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Learner Two'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'learner two');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing results for'), findsOneWidget);
    expect(find.text('Learner Two'), findsOneWidget);
    expect(find.text('Learner One'), findsNothing);
    expect(find.textContaining('Found 1 matching support plans'), findsOneWidget);

    await tester.tap(find.text('Clear Search'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Showing results for'), findsNothing);
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Learner Two'), findsOneWidget);
  });

  testWidgets('educator learner supports page keeps stale plans visible after a refresh failure',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    int supportPlanLoadCount = 0;
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
      learnersLoader: () async => EducatorLearnersSnapshot(
        learners: <EducatorLearner>[_sampleLearner()],
      ),
    );

    await tester.pumpWidget(
      _buildHarness(
        firestoreService: firestoreService,
        educatorService: educatorService,
        supportPlansLoader: (_, __) async {
          supportPlanLoadCount += 1;
          if (supportPlanLoadCount == 1) {
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'documentId': 'plan-1',
                'learnerId': 'learner-1',
                'supportType': 'Behavioral',
                'accommodations': <String>['Visual checklist'],
                'notes': 'Persisted plan note',
                'priority': 'high',
                'lastUpdated': Timestamp.fromDate(DateTime(2026, 1, 5)),
              },
            ];
          }
          throw StateError('saved support plans unavailable');
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Behavioral'), findsOneWidget);
    expect(find.text('Visual checklist'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Unable to refresh learner supports right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed to load learner supports:'), findsOneWidget);
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Behavioral'), findsOneWidget);
    expect(find.text('Visual checklist'), findsOneWidget);
  });
}