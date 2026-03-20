import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
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
        home: const ParentSchedulePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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
}
