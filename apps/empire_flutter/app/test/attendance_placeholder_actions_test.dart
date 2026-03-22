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
import 'package:scholesa_app/modules/attendance/attendance_models.dart';
import 'package:scholesa_app/modules/attendance/attendance_page.dart';
import 'package:scholesa_app/modules/attendance/attendance_service.dart';
import 'package:scholesa_app/modules/educator/educator_service.dart';
import 'package:scholesa_app/modules/educator/educator_sessions_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/modules/site/site_sessions_page.dart';
import 'package:scholesa_app/offline/offline_queue.dart';
import 'package:scholesa_app/offline/sync_coordinator.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/telemetry_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/ui/common/error_state.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

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

class _FakeAttendanceService extends AttendanceService {
  _FakeAttendanceService({
    required SessionOccurrence rosterOccurrence,
    List<SessionOccurrence>? occurrences,
    this.loadError,
  })  : _occurrences = occurrences,
        _rosterOccurrence = rosterOccurrence,
        super(
          apiClient: _MockApiClient(),
          syncCoordinator: _MockSyncCoordinator(),
          educatorId: 'educator-1',
          siteId: 'site-1',
        );

  final SessionOccurrence _rosterOccurrence;
  final List<SessionOccurrence>? _occurrences;
  final String? loadError;

  @override
  List<SessionOccurrence> get todayOccurrences =>
      _occurrences ??
      <SessionOccurrence>[
        SessionOccurrence(
          id: _rosterOccurrence.id,
          sessionId: _rosterOccurrence.sessionId,
          siteId: _rosterOccurrence.siteId,
          title: _rosterOccurrence.title,
          startTime: _rosterOccurrence.startTime,
          endTime: _rosterOccurrence.endTime,
          roomName: _rosterOccurrence.roomName,
          learnerCount: _rosterOccurrence.roster.length,
        ),
      ];

  SessionOccurrence? _currentOccurrence;

  @override
  SessionOccurrence? get currentOccurrence => _currentOccurrence;

  @override
  bool get isLoading => false;

  @override
  String? get error => loadError;

  @override
  Future<void> loadTodayOccurrences() async {
    notifyListeners();
  }

  @override
  Future<void> loadOccurrenceRoster(String occurrenceId) async {
    _currentOccurrence = _rosterOccurrence;
    notifyListeners();
  }

  @override
  void clearCurrentOccurrence() {
    _currentOccurrence = null;
  }
}

class _FailingAttendanceSaveService extends _FakeAttendanceService {
  _FailingAttendanceSaveService({required super.rosterOccurrence});

  @override
  Future<AttendanceBatchSaveResult> batchRecordAttendance(
    List<AttendanceRecord> records,
  ) async {
    return AttendanceBatchSaveResult.failed;
  }
}

AppState _buildAppState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'educator-1',
    'email': 'educator-1@scholesa.test',
    'displayName': 'Educator One',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'zh-CN',
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

AppState _buildSiteAppState() {
  final AppState appState = AppState();
  appState.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <Map<String, dynamic>>[],
  });
  return appState;
}

Future<void> _seedAttendanceCouplingData(
  FakeFirebaseFirestore firestore,
) async {
  final DateTime now = DateTime.now();
  final DateTime startTime = DateTime(now.year, now.month, now.day, 9, 0);
  final DateTime endTime = startTime.add(const Duration(hours: 1));

  await firestore
      .collection('sessionOccurrences')
      .doc('occ-1')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'siteId': 'site-1',
    'title': 'Robotics Lab',
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'roomName': 'Studio A',
  });

  await firestore
      .collection('enrollments')
      .doc('enrollment-1')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'learnerId': 'learner-1',
    'status': 'active',
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-2')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'learnerId': 'learner-2',
    'status': 'active',
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-3')
      .set(<String, dynamic>{
    'sessionId': 'session-1',
    'learnerId': 'learner-3',
    'status': 'inactive',
  });
  await firestore
      .collection('enrollments')
      .doc('enrollment-4')
      .set(<String, dynamic>{
    'sessionId': 'session-2',
    'learnerId': 'learner-4',
    'status': 'active',
  });

  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Ava Learner',
    'role': 'learner',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'displayName': 'Milo Builder',
    'role': 'learner',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('users').doc('learner-3').set(<String, dynamic>{
    'displayName': 'Inactive Learner',
    'role': 'learner',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('users').doc('learner-4').set(<String, dynamic>{
    'displayName': 'Other Session Learner',
    'role': 'learner',
    'siteIds': <String>['site-1'],
  });
}

Future<void> _seedSessionCreateOptions(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('educator-1').set(<String, dynamic>{
    'displayName': 'Educator One',
    'email': 'educator-1@scholesa.test',
    'role': 'educator',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('rooms').doc('room-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'name': 'Lab 1',
  });
}

Future<void> _seedEducatorRosterImportData(
  FakeFirebaseFirestore firestore,
) async {
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

  await firestore.collection('sessionOccurrences').doc('occ-roster-1').set(
    <String, dynamic>{
      'sessionId': 'session-roster-1',
      'siteId': 'site-1',
      'title': 'Launch Lab',
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'roomName': 'Studio A',
    },
  );

  await firestore.collection('users').doc('learner-known-1').set(
    <String, dynamic>{
      'displayName': 'Known Learner',
      'email': 'known@example.com',
      'role': 'learner',
      'siteIds': <String>['site-1'],
    },
  );
}

Widget _buildTestMaterialApp({required Widget child}) {
  return MaterialApp(
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
  );
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
  setUpAll(() {
    registerFallbackValue(OpType.attendanceRecord);
  });

  testWidgets('attendance page shows a recoverable missing-service state',
      (WidgetTester tester) async {
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Attendance is temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
        'Reopen attendance from your dashboard or refresh after the app reconnects.',
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('attendance roster localizes unavailable learner identities',
      (WidgetTester tester) async {
    final _FakeAttendanceService attendanceService = _FakeAttendanceService(
      rosterOccurrence: SessionOccurrence(
        id: 'occ-1',
        sessionId: 'session-1',
        siteId: 'site-1',
        title: 'Robotics Lab',
        startTime: DateTime(2026, 3, 17, 9),
        endTime: DateTime(2026, 3, 17, 10),
        roomName: 'Studio A',
        roster: const <RosterLearner>[
          RosterLearner(
            id: 'learner-1',
            displayName: 'Unknown',
          ),
        ],
      ),
    );
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
            value: attendanceService,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          locale: const Locale('zh', 'CN'),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('账户菜单'), findsOneWidget);
    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    expect(find.text('学习者信息不可用'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets(
      'attendance page shows load failure instead of fake empty classes',
      (WidgetTester tester) async {
    final _FakeAttendanceService attendanceService = _FakeAttendanceService(
      rosterOccurrence: SessionOccurrence(
        id: 'occ-1',
        sessionId: 'session-1',
        siteId: 'site-1',
        title: 'Robotics Lab',
        startTime: DateTime(2026, 3, 17, 9),
      ),
      occurrences: const <SessionOccurrence>[],
      loadError: 'Failed to load occurrences from test',
    );
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(
              useMaterial3: true, splashFactory: NoSplash.splashFactory),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
          'We could not load attendance sessions right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No classes today'), findsNothing);
  });

  testWidgets(
      'attendance page keeps stale occurrences visible after refresh failure',
      (WidgetTester tester) async {
    final _FakeAttendanceService attendanceService = _FakeAttendanceService(
      rosterOccurrence: SessionOccurrence(
        id: 'occ-1',
        sessionId: 'session-1',
        siteId: 'site-1',
        title: 'Robotics Lab',
        startTime: DateTime(2026, 3, 17, 9),
      ),
      loadError: 'Failed to load occurrences from test',
    );
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(
              useMaterial3: true, splashFactory: NoSplash.splashFactory),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh attendance sessions right now. Showing the last successful data. Failed to load occurrences from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Robotics Lab'), findsOneWidget);
    expect(find.text('No classes today'), findsNothing);
  });

  testWidgets('attendance page loads live roster from enrolled learners',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Robotics Lab'), findsOneWidget);
    expect(find.text('2 students'), findsOneWidget);

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    expect(find.text('Ava Learner'), findsOneWidget);
    expect(find.text('Milo Builder'), findsOneWidget);
    expect(find.text('Inactive Learner'), findsNothing);
    expect(find.text('Other Session Learner'), findsNothing);
    expect(find.text('Save Attendance (0/2)'), findsOneWidget);
  });

  testWidgets(
      'educator roster import flows into the attendance roster for the same class',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedEducatorRosterImportData(firestore);

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildAppState();
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
        child: _buildTestMaterialApp(
          child: EducatorSessionsPage(sharedPreferences: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Launch Lab'), findsOneWidget);

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
      'name,email\nKnown Learner,known@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Roster import complete: 1 enrolled, 0 already present'),
      findsOneWidget,
    );

    final QuerySnapshot<Map<String, dynamic>> enrollments =
        await firestore.collection('enrollments').get();
    expect(enrollments.docs, hasLength(1));
    expect(enrollments.docs.single.data()['learnerId'], 'learner-known-1');
    expect(enrollments.docs.single.data()['sessionId'], 'session-roster-1');

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
            value: attendanceService,
          ),
        ],
        child: _buildTestMaterialApp(
          child: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Launch Lab'), findsOneWidget);
    expect(find.text('1 students'), findsOneWidget);

    await tester.tap(find.text('Launch Lab').last);
    await tester.pumpAndSettle();

    expect(find.text('Known Learner'), findsOneWidget);
    expect(find.text('Save Attendance (0/1)'), findsOneWidget);
  });

  testWidgets(
      'attendance page shows a class created through site sessions via the generated occurrence',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSessionCreateOptions(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      _buildTestMaterialApp(
        child: MultiProvider(
          providers: <SingleChildWidget>[
            Provider<FirestoreService>.value(value: firestoreService),
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: const SiteSessionsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Session'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Session Title'),
      'Evidence Studio',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Learner Count'),
      '0',
    );

    final Finder createButton =
        find.widgetWithText(ElevatedButton, 'Create Session');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pumpAndSettle();

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      _buildTestMaterialApp(
        child: MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<SyncCoordinator>.value(
              value: syncCoordinator,
            ),
            ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService,
            ),
          ],
          child: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Studio'), findsOneWidget);
    expect(find.text('0 students'), findsOneWidget);
    expect(find.text('No classes today'), findsNothing);
  });

  testWidgets(
      'queued roster imports reconcile through site provisioning into the attendance roster',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedEducatorRosterImportData(firestore);

    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _MockFirebaseAuth(),
    );
    final AppState educatorAppState = _buildAppState();
    final EducatorService educatorService = EducatorService(
      firestoreService: firestoreService,
      educatorId: 'educator-1',
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<FirestoreService>.value(value: firestoreService),
          ChangeNotifierProvider<AppState>.value(value: educatorAppState),
          ChangeNotifierProvider<EducatorService>.value(value: educatorService),
        ],
        child: _buildTestMaterialApp(
          child: EducatorSessionsPage(sharedPreferences: prefs),
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
      'name,email\nQueued Learner,queued@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Roster import complete: 0 enrolled, 1 queued for provisioning'),
      findsOneWidget,
    );

    final QuerySnapshot<Map<String, dynamic>> queuedImports =
        await firestore.collection('rosterImports').get();
    expect(queuedImports.docs, hasLength(1));
    expect(queuedImports.docs.single.data()['status'], 'pending_provisioning');
    expect(queuedImports.docs.single.data()['email'], 'queued@example.com');

    final QuerySnapshot<Map<String, dynamic>> enrollmentsBeforeProvisioning =
        await firestore.collection('enrollments').get();
    expect(enrollmentsBeforeProvisioning.docs, isEmpty);

    final AppState siteAppState = _buildSiteAppState();
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
          ChangeNotifierProvider<AppState>.value(value: siteAppState),
          ChangeNotifierProvider<ProvisioningService>.value(
            value: provisioningService,
          ),
        ],
        child: _buildTestMaterialApp(
          child: const ProvisioningPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Queued Learner');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'queued@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Learner created successfully'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> users = await firestore
        .collection('users')
        .where('email', isEqualTo: 'queued@example.com')
        .limit(1)
        .get();
    expect(users.docs, hasLength(1));
    final String learnerId = users.docs.single.id;

    final QuerySnapshot<Map<String, dynamic>> enrollmentsAfterProvisioning =
        await firestore.collection('enrollments').get();
    expect(enrollmentsAfterProvisioning.docs, hasLength(1));
    expect(enrollmentsAfterProvisioning.docs.single.data()['learnerId'],
        learnerId);
    expect(
      enrollmentsAfterProvisioning.docs.single.data()['sessionId'],
      'session-roster-1',
    );
    expect(
      enrollmentsAfterProvisioning.docs.single.data()['status'],
      'active',
    );

    final QuerySnapshot<Map<String, dynamic>> reconciledImports =
        await firestore.collection('rosterImports').get();
    expect(reconciledImports.docs.single.data()['status'], 'provisioned');
    expect(reconciledImports.docs.single.data()['learnerId'], learnerId);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: educatorAppState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
            value: attendanceService,
          ),
        ],
        child: _buildTestMaterialApp(
          child: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Launch Lab'), findsOneWidget);
    expect(find.text('1 students'), findsOneWidget);

    await tester.tap(find.text('Launch Lab').last);
    await tester.pumpAndSettle();

    expect(find.text('Queued Learner'), findsOneWidget);
    expect(find.text('Save Attendance (0/1)'), findsOneWidget);
  });

  testWidgets(
      'attendance roster keeps stale learners visible after refresh failure',
      (WidgetTester tester) async {
    final _FakeAttendanceService attendanceService = _FakeAttendanceService(
      rosterOccurrence: SessionOccurrence(
        id: 'occ-1',
        sessionId: 'session-1',
        siteId: 'site-1',
        title: 'Robotics Lab',
        startTime: DateTime(2026, 3, 17, 9),
        endTime: DateTime(2026, 3, 17, 10),
        roomName: 'Studio A',
        roster: const <RosterLearner>[
          RosterLearner(
            id: 'learner-1',
            displayName: 'Amina Patel',
          ),
        ],
      ),
      loadError: 'Failed to load roster from test',
    );
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(
              useMaterial3: true, splashFactory: NoSplash.splashFactory),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh attendance roster right now. Showing the last successful data. Failed to load roster from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Amina Patel'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('attendance page saves attendance records to Firestore',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Present'));
    await tester.pumpAndSettle();
    expect(find.text('Save Attendance (2/2)'), findsOneWidget);

    await tester.tap(find.text('Save Attendance (2/2)'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance saved successfully'), findsOneWidget);

    final QuerySnapshot<Map<String, dynamic>> attendanceSnapshot =
        await firestore
            .collection('attendanceRecords')
            .where('occurrenceId', isEqualTo: 'occ-1')
            .get();

    expect(attendanceSnapshot.docs, hasLength(2));
    final Set<String> learnerIds = attendanceSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.data()['learnerId'] as String)
        .toSet();
    final Set<String> statuses = attendanceSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            doc.data()['status'] as String)
        .toSet();

    expect(learnerIds, equals(<String>{'learner-1', 'learner-2'}));
    expect(statuses, equals(<String>{'present'}));
  });

  testWidgets('attendance page logs save telemetry on live save',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<SyncCoordinator>.value(
              value: syncCoordinator,
            ),
            ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService,
            ),
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
            home: const AttendancePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Robotics Lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Attendance (2/2)'));
      await tester.pumpAndSettle();
    });

    expect(
      events.any(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'cta.clicked' &&
            (payload['metadata'] as Map<String, dynamic>)['cta'] ==
                'attendance_save' &&
            (payload['metadata'] as Map<String, dynamic>)['occurrence_id'] ==
                'occ-1' &&
            (payload['metadata'] as Map<String, dynamic>)['records_count'] == 2,
      ),
      isTrue,
    );
    expect(
      events.any(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'attendance.recorded' &&
            (payload['metadata'] as Map<String, dynamic>)['occurrence_id'] ==
                'occ-1' &&
            (payload['metadata'] as Map<String, dynamic>)['records_count'] == 2,
      ),
      isTrue,
    );
  });

  testWidgets('attendance page shows explicit save failure',
      (WidgetTester tester) async {
    final _FailingAttendanceSaveService attendanceService =
        _FailingAttendanceSaveService(
      rosterOccurrence: SessionOccurrence(
        id: 'occ-1',
        sessionId: 'session-1',
        siteId: 'site-1',
        title: 'Robotics Lab',
        startTime: DateTime(2026, 3, 17, 9),
        endTime: DateTime(2026, 3, 17, 10),
        roomName: 'Studio A',
        roster: const <RosterLearner>[
          RosterLearner(id: 'learner-1', displayName: 'Ava Learner'),
          RosterLearner(id: 'learner-2', displayName: 'Milo Builder'),
        ],
      ),
    );
    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Attendance (2/2)'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to save attendance right now'), findsOneWidget);
    expect(find.text('Attendance saved successfully'), findsNothing);
    expect(find.text('Robotics Lab'), findsOneWidget);
  });

  testWidgets('attendance page reloads saved attendance from Firestore',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(true);
    when(() => syncCoordinator.pendingCount).thenReturn(0);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Attendance (2/2)'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance saved successfully'), findsOneWidget);
    expect(find.text('Robotics Lab'), findsOneWidget);

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();

    expect(find.text('Save Attendance (2/2)'), findsOneWidget);
    expect(attendanceService.currentOccurrence, isNotNull);
    final List<RosterLearner> roster =
        attendanceService.currentOccurrence!.roster;
    expect(roster, hasLength(2));
    expect(
      roster.every((RosterLearner learner) =>
          learner.currentAttendance?.status == AttendanceStatus.present),
      isTrue,
    );
  });

  testWidgets('attendance page queues attendance when offline',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(false);
    when(() => syncCoordinator.pendingCount).thenReturn(2);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    when(() => syncCoordinator.queueOperation(any(), any())).thenAnswer(
      (_) async => QueuedOp(
        type: OpType.attendanceRecord,
        payload: const <String, dynamic>{},
      ),
    );

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SyncCoordinator>.value(value: syncCoordinator),
          ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService),
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
          home: const AttendancePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robotics Lab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Attendance (2/2)'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance queued to sync'), findsOneWidget);
    verify(() => syncCoordinator.queueOperation(OpType.attendanceRecord, any()))
        .called(2);
    expect(
      (await firestore.collection('attendanceRecords').get()).docs,
      isEmpty,
    );
  });

  testWidgets('attendance page logs queue telemetry when offline',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedAttendanceCouplingData(firestore);

    final _MockSyncCoordinator syncCoordinator = _MockSyncCoordinator();
    when(() => syncCoordinator.isOnline).thenReturn(false);
    when(() => syncCoordinator.pendingCount).thenReturn(2);
    when(() => syncCoordinator.isSyncing).thenReturn(false);
    when(() => syncCoordinator.retryFailed()).thenAnswer((_) async {});
    when(() => syncCoordinator.queueOperation(any(), any())).thenAnswer(
      (_) async => QueuedOp(
        type: OpType.attendanceRecord,
        payload: const <String, dynamic>{},
      ),
    );

    final AttendanceService attendanceService = AttendanceService(
      apiClient: _MockApiClient(),
      syncCoordinator: syncCoordinator,
      firestore: firestore,
      siteId: 'site-1',
    );
    final AppState appState = _buildAppState();

    final List<Map<String, dynamic>> events = await _captureTelemetry(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<SyncCoordinator>.value(
              value: syncCoordinator,
            ),
            ChangeNotifierProvider<AttendanceService>.value(
              value: attendanceService,
            ),
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
            home: const AttendancePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Robotics Lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Attendance (2/2)'));
      await tester.pumpAndSettle();
    });

    expect(
      events.any(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'cta.clicked' &&
            (payload['metadata'] as Map<String, dynamic>)['cta'] ==
                'attendance_save' &&
            (payload['metadata'] as Map<String, dynamic>)['occurrence_id'] ==
                'occ-1' &&
            (payload['metadata'] as Map<String, dynamic>)['records_count'] == 2,
      ),
      isTrue,
    );
    expect(
      events.any(
        (Map<String, dynamic> payload) =>
            payload['event'] == 'attendance.record_queued' &&
            (payload['metadata'] as Map<String, dynamic>)['occurrence_id'] ==
                'occ-1' &&
            (payload['metadata'] as Map<String, dynamic>)['records_count'] == 2,
      ),
      isTrue,
    );
  });
}
