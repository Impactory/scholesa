import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/educator/educator_models.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_sessions_page.dart';
import 'package:scholesa_app/modules/hq_admin/hq_curriculum_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeEducatorService extends EducatorService {
  _FakeEducatorService({
    required super.firestoreService,
    this.failSessionLoad = true,
    List<EducatorSession> sessions = const <EducatorSession>[],
    List<EducatorLearner> learners = const <EducatorLearner>[],
  })  : _seedSessions = List<EducatorSession>.from(sessions),
        _seedLearners = List<EducatorLearner>.from(learners),
        super(
          educatorId: 'educator-1',
          siteId: 'site-1',
        ) {
    _sessionsValue = List<EducatorSession>.from(_seedSessions);
    _learnersValue = List<EducatorLearner>.from(_seedLearners);
  }

  final bool failSessionLoad;
  final List<EducatorSession> _seedSessions;
  final List<EducatorLearner> _seedLearners;

  List<EducatorSession> _sessionsValue = <EducatorSession>[];
  List<EducatorLearner> _learnersValue = <EducatorLearner>[];
  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<EducatorSession> get sessions => _sessionsValue;

  @override
  List<EducatorLearner> get learners => _learnersValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadSessions() async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();

    await Future<void>.delayed(Duration.zero);

    if (failSessionLoad) {
      _errorValue = 'Failed to load sessions';
    } else {
      _sessionsValue = List<EducatorSession>.from(_seedSessions);
      _errorValue = null;
    }
    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<void> loadLearners() async {
    _learnersValue = List<EducatorLearner>.from(_seedLearners);
    notifyListeners();
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

AppState _buildHqState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'hq-user-1',
    'email': 'hq@scholesa.test',
    'displayName': 'HQ Admin',
    'role': 'hq',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required EducatorService educatorService,
  required FirestoreService firestoreService,
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
      home: EducatorSessionsPage(sharedPreferences: sharedPreferences),
    ),
  );
}

Widget _buildHqHarness({required FirestoreService firestoreService}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<FirestoreService>.value(value: firestoreService),
      ChangeNotifierProvider<AppState>.value(value: _buildHqState()),
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
      home: const HqCurriculumPage(),
    ),
  );
}

Future<void> _enterHqDialogTextField(
  WidgetTester tester,
  int index,
  String value,
) async {
  final Finder dialogFields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  final Finder field = dialogFields.at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

EducatorSession _buildSession({
  required String id,
  required String title,
  required String pillar,
  required String status,
}) {
  final DateTime start = DateTime(2026, 3, 20, 9 + id.length);
  return EducatorSession(
    id: id,
    title: title,
    pillar: pillar,
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    location: 'Studio A',
    enrolledCount: 12,
    maxCapacity: 16,
    status: status,
  );
}

Finder _filterChipLabel(String label) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Text &&
        widget.data == label &&
        widget.style?.fontSize == 13 &&
        widget.style?.fontWeight == FontWeight.w600,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'educator sessions page shows an explicit load error instead of an empty state',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService =
        _FakeEducatorService(firestoreService: firestoreService);

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not load sessions right now. Retry to check the current state.',
      ),
      findsOneWidget,
    );
    expect(find.text('Failed to load sessions'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No sessions yet'), findsNothing);
  });

  testWidgets(
      'educator sessions page keeps stale sessions visible after refresh failure',
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
      sessionsLoader: () async {
        loadCount += 1;
        if (loadCount == 1) {
          return EducatorSessionsSnapshot(
            sessions: <EducatorSession>[
              _buildSession(
                id: 'upcoming-1',
                title: 'Robotics Warm-up',
                pillar: 'future_skills',
                status: 'upcoming',
              ),
            ],
          );
        }
        throw Exception('network down');
      },
      learnersLoader: () async {
        return const EducatorLearnersSnapshot(learners: <EducatorLearner>[]);
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Robotics Warm-up'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Robotics Warm-up'), findsOneWidget);
    expect(
      find.text(
        'Unable to refresh sessions right now. Showing the last successful data. Failed to load sessions: Exception: network down',
      ),
      findsOneWidget,
    );
    expect(find.text('No sessions yet'), findsNothing);
  });

  testWidgets(
      'educator sessions tabs change visible content and selections persist on reopen',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'upcoming-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
        _buildSession(
          id: 'ongoing-1',
          title: 'Leadership Circle',
          pillar: 'leadership',
          status: 'in_progress',
        ),
        _buildSession(
          id: 'past-1',
          title: 'Impact Expo',
          pillar: 'impact',
          status: 'completed',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Robotics Warm-up'), findsOneWidget);
    expect(find.text('Leadership Circle'), findsNothing);
    expect(find.text('Impact Expo'), findsNothing);

    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();

    expect(find.text('Robotics Warm-up'), findsNothing);
    expect(find.text('Leadership Circle'), findsOneWidget);
    expect(find.text('Impact Expo'), findsNothing);

    // Legacy storage label 'Leadership' renders as the canonical strand
    // display 'Communicate & Lead' via curriculum display localization.
    await tester.tap(_filterChipLabel('Communicate & Lead'));
    await tester.pumpAndSettle();

    expect(find.text('Leadership Circle'), findsOneWidget);
    expect(find.text('Robotics Warm-up'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
        sharedPreferences: prefs,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Leadership Circle'), findsOneWidget);
    expect(find.text('Robotics Warm-up'), findsNothing);
    expect(find.text('Impact Expo'), findsNothing);
  });

  testWidgets(
      'educator sessions quick evidence capture stores the resolved session occurrence id',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'session-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
      ],
      learners: const <EducatorLearner>[
        EducatorLearner(
          id: 'learner-1',
          name: 'Ava Stone',
          email: 'ava@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 2,
          pillarProgress: <String, double>{
            'future_skills': 0.2,
            'leadership': 0.1,
            'impact': 0.0,
          },
          enrolledSessionIds: <String>['session-1'],
        ),
      ],
    );

    await firestore.collection('sessionOccurrences').doc('occurrence-1').set(
      <String, dynamic>{
        'sessionId': 'session-1',
        'siteId': 'site-1',
        'educatorId': 'educator-1',
        'status': 'upcoming',
        'startTime':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 20))),
        'endTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 1, minutes: 20))),
      },
    );
    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Prototype evidence',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );
    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    final Finder logEvidenceButton =
        find.widgetWithText(OutlinedButton, 'Log Evidence');
    await tester.ensureVisible(logEvidenceButton);
    await tester.tap(logEvidenceButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ava Stone').last);
    await tester.pumpAndSettle();

    final Finder dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.tap(dialogDropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prototype evidence').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What evidence did you see?'),
      'Explained each debugging step and corrected the sensor logic live.',
    );

    await tester.tap(find.text('Capture Evidence'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Live evidence captured for Ava Stone'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> evidenceSnapshot =
        await firestore.collection('evidenceRecords').get();
    expect(evidenceSnapshot.docs, hasLength(1));
    expect(
      evidenceSnapshot.docs.first.data()['sessionOccurrenceId'],
      'occurrence-1',
    );
  });

  testWidgets(
      'educator sessions quick evidence capture requires explicit mapped capability selection when available',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'session-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
      ],
      learners: const <EducatorLearner>[
        EducatorLearner(
          id: 'learner-1',
          name: 'Ava Stone',
          email: 'ava@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 2,
          pillarProgress: <String, double>{
            'future_skills': 0.2,
            'leadership': 0.1,
            'impact': 0.0,
          },
          enrolledSessionIds: <String>['session-1'],
        ),
      ],
    );

    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Prototype evidence',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    final Finder logEvidenceButton =
        find.widgetWithText(OutlinedButton, 'Log Evidence');
    await tester.ensureVisible(logEvidenceButton);
    await tester.tap(logEvidenceButton);
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(TextFormField, 'Capability focus'), findsNothing);
    expect(find.text('Prototype evidence'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What evidence did you see?'),
      'Explained each debugging step and corrected the sensor logic live.',
    );

    await tester.tap(find.text('Capture Evidence'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Choose a learner, add a capability focus, and capture what you observed.',
      ),
      findsOneWidget,
    );

    QuerySnapshot<Map<String, dynamic>> evidenceSnapshot =
        await firestore.collection('evidenceRecords').get();
    expect(evidenceSnapshot.docs, isEmpty);

    final Finder dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );

    await tester.tap(dialogDropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prototype evidence').last);
    await tester.pumpAndSettle();

    expect(find.text('Prototype evidence'), findsOneWidget);

    await tester.tap(find.text('Capture Evidence'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);

    evidenceSnapshot = await firestore.collection('evidenceRecords').get();
    expect(evidenceSnapshot.docs, hasLength(1));
    expect(evidenceSnapshot.docs.first.data()['capabilityId'], 'capability-1');
    expect(evidenceSnapshot.docs.first.data()['capabilityMapped'], isTrue);
  });

  testWidgets(
      'educator sessions studio card blocks live evidence when mapped capabilities are missing',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'session-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
      ],
      learners: const <EducatorLearner>[
        EducatorLearner(
          id: 'learner-1',
          name: 'Ava Stone',
          email: 'ava@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 2,
          pillarProgress: <String, double>{
            'future_skills': 0.2,
            'leadership': 0.1,
            'impact': 0.0,
          },
          enrolledSessionIds: <String>['session-1'],
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    expect(find.text('Capability mapping required'), findsOneWidget);
    expect(
      find.text(
        'This session pillar has no mapped capabilities yet, so live evidence cannot flow cleanly into growth or portfolio review. Add capability mappings before studio capture.',
      ),
      findsOneWidget,
    );

    final OutlinedButton logEvidenceButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Log Evidence'),
    );
    expect(logEvidenceButton.onPressed, isNull);

    final FilledButton takeAttendanceButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Take Attendance'),
    );
    expect(takeAttendanceButton.onPressed, isNotNull);
  });

  testWidgets(
      'educator sessions quick evidence capture persists structured artifact, checkpoint, and AI disclosure fields',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'session-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
      ],
      learners: const <EducatorLearner>[
        EducatorLearner(
          id: 'learner-1',
          name: 'Ava Stone',
          email: 'ava@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 2,
          pillarProgress: <String, double>{
            'future_skills': 0.2,
            'leadership': 0.1,
            'impact': 0.0,
          },
          enrolledSessionIds: <String>['session-1'],
        ),
      ],
    );
    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Prototype evidence',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    final Finder logEvidenceButton =
        find.widgetWithText(OutlinedButton, 'Log Evidence');
    await tester.ensureVisible(logEvidenceButton);
    await tester.tap(logEvidenceButton);
    await tester.pumpAndSettle();

    final Finder dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );

    await tester.tap(dialogDropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkpoint').last);
    await tester.pumpAndSettle();

    await tester.tap(dialogDropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prototype evidence').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Checkpoint captured'),
      'Learner explained why the sensor threshold needed recalibration.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What evidence did you see?'),
      'Explained each debugging step and corrected the sensor logic live.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Artifact links'),
      'https://example.com/debug-log\nhttps://example.com/fixed-sensor-video',
    );

    await tester.scrollUntilVisible(
      find.text('AI support observed'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(dialogDropdowns.at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI support observed').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'AI support details'),
      'AI suggested two threshold options, but the learner tested and chose the final value.',
    );

    await tester.tap(find.text('Capture Evidence'));
    await tester.pump();
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> evidenceSnapshot =
        await firestore.collection('evidenceRecords').get();
    expect(evidenceSnapshot.docs, hasLength(1));

    final Map<String, dynamic> evidence = evidenceSnapshot.docs.first.data();
    expect(evidence['checkpointSummary'],
        'Learner explained why the sensor threshold needed recalibration.');
    expect(evidence['artifactUrls'], <String>[
      'https://example.com/debug-log',
      'https://example.com/fixed-sensor-video',
    ]);
    expect(evidence['aiAssistanceUsed'], isTrue);
    expect(
      evidence['aiAssistanceDetails'],
      'AI suggested two threshold options, but the learner tested and chose the final value.',
    );
  });

  testWidgets(
      'educator live studio shows HQ rubric descriptors and checkpoint guidance from linked mission',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('sessions').doc('session-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Robotics Warm-up',
        'pillar': 'future_skills',
        'educatorId': 'educator-1',
        'teacherIds': <String>['educator-1'],
        'startTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
        'endTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1, hours: 1)),
        ),
      },
    );
    await firestore.collection('missions').doc('mission-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Robotics Warm-up Mission',
        'sessionId': 'session-1',
        'rubricId': 'rubric-1',
        'rubricTitle': 'HQ Live Evidence Rubric',
        'capabilityTitles': <String>['Prototype evidence'],
        'progressionDescriptors': <String>[
          'Secure: explains how the artifact proves the capability claim.',
        ],
        'checkpointMappings': <Map<String, dynamic>>[
          <String, dynamic>{
            'phaseKey': 'checkpoint',
            'phaseLabel': 'Checkpoint',
            'guidance':
                'Ask the learner to point to the exact artifact that proves current understanding.',
          },
        ],
      },
    );
    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Prototype evidence',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );
    await firestore.collection('users').doc('learner-1').set(
      <String, dynamic>{
        'name': 'Ava Stone',
        'email': 'ava@scholesa.test',
        'role': 'learner',
        'siteId': 'site-1',
        'educatorId': 'educator-1',
        'enrolledSessionIds': <String>['session-1'],
      },
    );

    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    expect(find.text('HQ teaching guidance'), findsOneWidget);
    expect(find.text('Rubric: HQ Live Evidence Rubric'), findsOneWidget);
    expect(
      find.text(
        'Secure: explains how the artifact proves the capability claim.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Checkpoint: Ask the learner to point to the exact artifact that proves current understanding.',
      ),
      findsOneWidget,
    );

    final Finder logEvidenceButton =
        find.widgetWithText(OutlinedButton, 'Log Evidence');
    await tester.ensureVisible(logEvidenceButton);
    await tester.tap(logEvidenceButton);
    await tester.pumpAndSettle();

    final Finder dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.tap(dialogDropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkpoint').last);
    await tester.pumpAndSettle();

    expect(find.text('Current teaching prompt'), findsOneWidget);
    expect(
      find.text(
        'Ask the learner to point to the exact artifact that proves current understanding.',
      ),
      findsWidgets,
    );
    expect(find.text('Rubric: HQ Live Evidence Rubric'), findsWidgets);
  });

  testWidgets(
      'educator live studio resolves legacy human-readable checkpoint keys into current teaching prompts',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('sessions').doc('session-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Robotics Warm-up',
        'pillar': 'future_skills',
        'educatorId': 'educator-1',
        'teacherIds': <String>['educator-1'],
        'startTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
        'endTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1, hours: 1)),
        ),
      },
    );
    await firestore.collection('missions').doc('mission-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Robotics Warm-up Mission',
        'sessionId': 'session-1',
        'rubricId': 'rubric-1',
        'rubricTitle': 'HQ Live Evidence Rubric',
        'capabilityTitles': <String>['Prototype evidence'],
        'checkpointMappings': <Map<String, dynamic>>[
          <String, dynamic>{
            'phaseKey': 'Checkpoint',
            'phaseLabel': 'Checkpoint',
            'guidance':
                'Ask the learner to point to the exact artifact that proves current understanding.',
          },
        ],
      },
    );
    await firestore.collection('capabilities').doc('capability-1').set(
      <String, dynamic>{
        'title': 'Prototype evidence',
        'pillarCode': 'FS',
        'siteId': 'site-1',
      },
    );
    await firestore.collection('users').doc('learner-1').set(
      <String, dynamic>{
        'name': 'Ava Stone',
        'email': 'ava@scholesa.test',
        'role': 'learner',
        'siteId': 'site-1',
        'educatorId': 'educator-1',
        'enrolledSessionIds': <String>['session-1'],
      },
    );

    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    final Finder logEvidenceButton =
        find.widgetWithText(OutlinedButton, 'Log Evidence');
    await tester.ensureVisible(logEvidenceButton);
    await tester.tap(logEvidenceButton);
    await tester.pumpAndSettle();

    final Finder dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.tap(dialogDropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkpoint').last);
    await tester.pumpAndSettle();

    expect(find.text('Current teaching prompt'), findsOneWidget);
    expect(
      find.text(
        'Ask the learner to point to the exact artifact that proves current understanding.',
      ),
      findsWidgets,
    );
  });

  testWidgets(
      'HQ capability mapping clears readiness and unblocks educator live evidence on reload',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );

    await firestore.collection('sessions').doc('session-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'title': 'Robotics Warm-up',
        'pillar': 'Future Skills',
        'educatorName': 'Educator One',
        'startTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
      },
    );

    await tester.pumpWidget(
      _buildHqHarness(firestoreService: firestoreService),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Robotics Warm-up'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);

    final Finder createMappedCurriculum =
        find.widgetWithText(OutlinedButton, 'Create mapped curriculum');
    await tester.ensureVisible(createMappedCurriculum);
    await tester.tap(createMappedCurriculum);
    await tester.pumpAndSettle();

    await _enterHqDialogTextField(tester, 0, 'Future Skills Studio Map');
    await _enterHqDialogTextField(
      tester,
      1,
      'Curriculum created from a blocked live session readiness row.',
    );
    await _enterHqDialogTextField(tester, 3, 'Prototype evidence');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Curriculum created'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('1 mapped capability'), findsOneWidget);

    final EducatorService educatorService = _FakeEducatorService(
      firestoreService: firestoreService,
      failSessionLoad: false,
      sessions: <EducatorSession>[
        _buildSession(
          id: 'session-1',
          title: 'Robotics Warm-up',
          pillar: 'future_skills',
          status: 'upcoming',
        ),
      ],
      learners: const <EducatorLearner>[
        EducatorLearner(
          id: 'learner-1',
          name: 'Ava Stone',
          email: 'ava@scholesa.test',
          attendanceRate: 92,
          missionsCompleted: 2,
          pillarProgress: <String, double>{
            'future_skills': 0.2,
            'leadership': 0.1,
            'impact': 0.0,
          },
          enrolledSessionIds: <String>['session-1'],
        ),
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        educatorService: educatorService,
        firestoreService: firestoreService,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Warm-up').first);
    await tester.pumpAndSettle();

    expect(find.text('Capability mapping required'), findsNothing);
    final OutlinedButton logEvidenceButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Log Evidence'),
    );
    expect(logEvidenceButton.onPressed, isNotNull);
  });
}
