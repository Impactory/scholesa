import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/attendance/attendance_models.dart';
import 'package:scholesa_app/modules/attendance/attendance_page.dart';
import 'package:scholesa_app/modules/attendance/attendance_service.dart';
import 'package:scholesa_app/offline/sync_coordinator.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/ui/common/error_state.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

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
    notifyListeners();
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

void main() {
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

  testWidgets('attendance page shows load failure instead of fake empty classes',
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
          ChangeNotifierProvider<AttendanceService>.value(value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: NoSplash.splashFactory),
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
      find.text('We could not load attendance sessions right now. Retry to check the current state.'),
      findsOneWidget,
    );
    expect(find.text('No classes today'), findsNothing);
  });

  testWidgets('attendance page keeps stale occurrences visible after refresh failure',
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
          ChangeNotifierProvider<AttendanceService>.value(value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: NoSplash.splashFactory),
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

  testWidgets('attendance roster keeps stale learners visible after refresh failure',
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
          ChangeNotifierProvider<AttendanceService>.value(value: attendanceService),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: NoSplash.splashFactory),
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
}
