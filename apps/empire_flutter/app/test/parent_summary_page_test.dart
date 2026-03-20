import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_models.dart';
import 'package:scholesa_app/modules/parent/parent_service.dart';
import 'package:scholesa_app/modules/parent/parent_summary_page.dart';
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
  testWidgets('parent summary empty state persists linked learner review requests',
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

    expect(find.text('Linked learner review request submitted.'), findsOneWidget);
    final requests = await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    expect(requests.docs.single.data()['requestType'], 'parent_linked_learner_review');
    expect(requests.docs.single.data()['source'], 'parent_summary_request_linked_learner_review');
  });

  testWidgets('parent summary empty state fails closed when support requests are unavailable',
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

    expect(find.text('Unable to submit linked learner review right now.'), findsOneWidget);
  });
}