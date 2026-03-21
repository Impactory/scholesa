import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_schedule_page.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubParentService extends ChangeNotifier implements ParentService {
  _StubParentService({
    required this.parentId,
    required this.learnerSummaries,
    this.error,
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
  String? get error => _error;

  @override
  bool get isLoading => _isLoading;

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
  FirestoreService? firestoreService,
  SharedPreferences? sharedPreferences,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildParentState()),
        ChangeNotifierProvider<ParentService>.value(value: parentService),
        if (firestoreService != null)
          Provider<FirestoreService>.value(value: firestoreService),
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
        home: ParentSchedulePage(sharedPreferences: sharedPreferences),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LearnerSummary _buildLearnerSummaryWithEvents() {
  final DateTime now = DateTime.now();
  return LearnerSummary(
    learnerId: 'learner-1',
    learnerName: 'Ava Learner',
    currentLevel: 4,
    totalXp: 120,
    missionsCompleted: 8,
    currentStreak: 3,
    attendanceRate: 0.94,
    upcomingEvents: <UpcomingEvent>[
      UpcomingEvent(
        id: 'event-1',
        title: 'Design Studio',
        dateTime: now.add(const Duration(days: 1, hours: 2)),
        type: 'class',
        location: 'Room A',
      ),
      UpcomingEvent(
        id: 'event-2',
        title: 'Reflection Circle',
        dateTime: now.add(const Duration(days: 10, hours: 1)),
        type: 'conference',
        location: 'Room B',
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'parent schedule page shows explicit load error instead of empty linked-state copy',
      (WidgetTester tester) async {
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: const <LearnerSummary>[],
      error: 'Failed to load data: schedule unavailable',
    );

    await _pumpPage(
      tester,
      parentService: service,
    );

    expect(find.text('Unable to load schedule right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text(
        'No learner links found yet. Request a linking review and we will check your family account.',
      ),
      findsNothing,
    );
    final int loadCallCountAfterMount = service.loadCallCount;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.loadCallCount, loadCallCountAfterMount + 1);
  });

  testWidgets('parent schedule empty state persists linked learner review requests',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _FakeFirebaseAuth(),
    );
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: const <LearnerSummary>[],
      firestoreService: firestoreService,
    );

    await _pumpPage(
      tester,
      parentService: service,
      firestoreService: firestoreService,
    );

    expect(find.text('Request Linking Review'), findsOneWidget);
    await tester.tap(find.text('Request Linking Review'));
    await tester.pumpAndSettle();

    expect(find.text('Linked learner review request submitted.'), findsOneWidget);
    final requests = await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    expect(requests.docs.single.data()['requestType'], 'parent_linked_learner_review');
    expect(requests.docs.single.data()['source'], 'parent_schedule_request_linked_learner_review');
  });

  testWidgets('parent schedule empty state fails closed when support requests are unavailable',
      (WidgetTester tester) async {
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: const <LearnerSummary>[],
    );

    await _pumpPage(
      tester,
      parentService: service,
    );

    await tester.tap(find.text('Request Linking Review'));
    await tester.pumpAndSettle();

    expect(find.text('Support requests are unavailable right now.'), findsOneWidget);
  });

  testWidgets('parent schedule month view changes visible content and persists on reopen',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _StubParentService service = _StubParentService(
      parentId: 'parent-test-1',
      learnerSummaries: <LearnerSummary>[
        _buildLearnerSummaryWithEvents(),
      ],
    );

    await _pumpPage(
      tester,
      parentService: service,
      sharedPreferences: prefs,
    );

    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('This Month'), findsNothing);

    final Finder monthToggle = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data == 'M' &&
          widget.style?.fontSize == 12,
      description: 'month view toggle',
    );
    await tester.tap(monthToggle);
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('This Week'), findsNothing);
    expect(find.text('Design Studio'), findsWidgets);
    expect(find.text('Reflection Circle'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpPage(
      tester,
      parentService: service,
      sharedPreferences: prefs,
    );

    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('This Week'), findsNothing);
  });

  testWidgets('parent schedule keeps stale learner schedule visible when a refresh fails',
      (WidgetTester tester) async {
    final _SequencedParentService service = _SequencedParentService(
      parentId: 'parent-test-1',
      snapshots: <_ParentLoadSnapshot>[
        _ParentLoadSnapshot(
          learnerSummaries: <LearnerSummary>[
            _buildLearnerSummaryWithEvents(),
          ],
        ),
        const _ParentLoadSnapshot(error: 'refresh failed'),
      ],
    );

    await _pumpPage(
      tester,
      parentService: service,
    );

    expect(find.text('This Week'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Design Studio'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Design Studio'), findsWidgets);
    expect(
      find.text(
        'Unable to refresh family dashboard right now. Showing the last successful data.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No learner links found yet. Request a linking review and we will check your family account.',
      ),
      findsNothing,
    );
  });
}
