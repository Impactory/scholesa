import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/parent/parent_consent_page.dart';
import 'package:scholesa_app/modules/parent/parent_consent_service.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingParentConsentService extends ParentConsentService {
  _ThrowingParentConsentService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<ParentConsentRecord>> listRecords(String parentId) async {
    throw StateError('consent unavailable');
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

Widget _buildHarness({
  required Widget child,
  required AppState appState,
  FirestoreService? firestoreService,
}) {
  final List<SingleChildWidget> providers = <SingleChildWidget>[
    ChangeNotifierProvider<AppState>.value(value: appState),
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
      home: child,
    ),
  );
}

Future<void> _seedConsentData(FakeFirebaseFirestore firestore) async {
  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'role': 'parent',
    'displayName': 'Parent One',
    'learnerIds': <String>['learner-1'],
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Ava Learner',
  });
  await firestore.collection('users').doc('learner-2').set(<String, dynamic>{
    'role': 'learner',
    'displayName': 'Hidden Learner',
    'parentIds': <String>['other-parent'],
  });
  await firestore.collection('guardianLinks').doc('link-1').set(<String, dynamic>{
    'parentId': 'parent-1',
    'learnerId': 'learner-1',
    'siteId': 'site-1',
  });
  await firestore.collection('learnerProfiles').doc('profile-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'preferredName': 'Ava Stone',
    },
  );
  await firestore.collection('mediaConsents').doc('media-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'photoCaptureAllowed': true,
      'shareWithLinkedParents': true,
      'marketingUseAllowed': false,
      'consentStatus': 'active',
      'consentStartDate': '2026-03-01',
    },
  );
  await firestore.collection('researchConsents').doc('research-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'parentId': 'parent-1',
      'consentGiven': true,
      'dataShareScope': 'pseudonymised',
      'consentVersion': 'v2',
    },
  );
  await firestore.collection('researchConsents').doc('research-2').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-2',
      'parentId': 'other-parent',
      'consentGiven': true,
      'dataShareScope': 'identifiable',
      'consentVersion': 'secret',
    },
  );
}

void main() {
  testWidgets('parent consent page shows linked learner consent records only',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedConsentData(firestore);

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildParentState(),
        child: ParentConsentPage(
          service: ParentConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Consent Records'), findsOneWidget);
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('Hidden Learner'), findsNothing);
    expect(find.textContaining('Photo capture: Allowed'), findsOneWidget);
    expect(find.textContaining('Data share scope: Pseudonymised'), findsOneWidget);
    expect(
      find.text(
        'This screen is view-only. Use the request flow below if any consent details need to change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Request Consent Review'), findsWidgets);
  });

  testWidgets('parent consent page persists consent review requests',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedConsentData(firestore);
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _FakeFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildParentState(),
        firestoreService: firestoreService,
        child: ParentConsentPage(
          service: ParentConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request Consent Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Consent review request submitted.'), findsOneWidget);
    final requests = await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    expect(requests.docs.single.data()['requestType'], 'parent_consent_review');
    expect(requests.docs.single.data()['source'], 'parent_consent_request_review');
    expect(
      (requests.docs.single.data()['metadata'] as Map<String, dynamic>)['learnerId'],
      'learner-1',
    );
  });

  testWidgets('parent consent page fails closed when support requests are unavailable',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedConsentData(firestore);

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildParentState(),
        child: ParentConsentPage(
          service: ParentConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request Consent Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Support requests are unavailable right now.'), findsOneWidget);
  });

  testWidgets('parent consent page shows explicit error state when loading fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildParentState(),
        child: ParentConsentPage(
          service: _ThrowingParentConsentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load consent records right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
