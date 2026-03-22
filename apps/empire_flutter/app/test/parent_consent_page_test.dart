import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/modules/parent/parent_consent_page.dart';
import 'package:scholesa_app/modules/parent/parent_consent_service.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

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

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-1-admin',
    'email': 'site-admin@scholesa.test',
    'displayName': 'Site Admin',
    'role': 'site',
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
  List<SingleChildWidget> providers = const <SingleChildWidget>[],
}) {
  final List<SingleChildWidget> resolvedProviders = <SingleChildWidget>[
    ChangeNotifierProvider<AppState>.value(value: appState),
    ...providers,
  ];
  if (firestoreService != null) {
    resolvedProviders.add(
      Provider<FirestoreService>.value(value: firestoreService),
    );
  }
  return MultiProvider(
    providers: resolvedProviders,
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

Future<void> _pumpProvisioningPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  final ProvisioningService service = ProvisioningService(
    apiClient: ApiClient(auth: _FakeFirebaseAuth(), baseUrl: 'http://localhost'),
    firestore: firestore,
    auth: _FakeFirebaseAuth(),
    useProvisioningApi: false,
  );

  await tester.pumpWidget(
    _buildHarness(
      appState: _buildSiteState(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ProvisioningService>.value(value: service),
      ],
      child: const ProvisioningPage(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
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

  testWidgets(
      'parent consent page shows provisioning-linked learner consent records only',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProvisioningPage(tester, firestore: firestore);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nia Consent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'nia.consent@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parents').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Pat Consent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'pat.consent@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '555-0114');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'nia.consent@example.com')
        .get();
    expect(learnerUsers.docs, hasLength(1));
    final String learnerId = learnerUsers.docs.single.id;

    final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'pat.consent@example.com')
        .get();
    expect(parentUsers.docs, hasLength(1));
    final String parentId = parentUsers.docs.single.id;

    await tester.tap(find.text('Links').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pat Consent').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nia Consent').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
    await tester.pump();
    await tester.pumpAndSettle();

    await firestore.collection('mediaConsents').doc('media-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': learnerId,
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
        'learnerId': learnerId,
        'parentId': parentId,
        'consentGiven': true,
        'dataShareScope': 'pseudonymised',
        'consentVersion': 'v2',
      },
    );

    await firestore.collection('users').doc('hidden-learner-1').set(
      <String, dynamic>{
        'role': 'learner',
        'displayName': 'Hidden Learner',
      },
    );
    await firestore.collection('researchConsents').doc('research-hidden').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': 'hidden-learner-1',
        'parentId': 'other-parent',
        'consentGiven': true,
        'dataShareScope': 'identifiable',
        'consentVersion': 'secret',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: (() {
          final AppState state = AppState();
          state.updateFromMeResponse(<String, dynamic>{
            'userId': parentId,
            'email': 'pat.consent@example.com',
            'displayName': 'Pat Consent',
            'role': 'parent',
            'activeSiteId': 'site-1',
            'siteIds': <String>['site-1'],
            'entitlements': const <dynamic>[],
          });
          return state;
        })(),
        child: ParentConsentPage(
          service: ParentConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nia Consent'), findsOneWidget);
    expect(find.text('Hidden Learner'), findsNothing);
    expect(find.textContaining('Photo capture: Allowed'), findsOneWidget);
    expect(find.textContaining('Data share scope: Pseudonymised'), findsOneWidget);
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

  testWidgets(
      'parent consent page persists consent review requests for provisioning-linked families',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FirestoreService firestoreService = FirestoreService(
      firestore: firestore,
      auth: _FakeFirebaseAuth(),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProvisioningPage(tester, firestore: firestore);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nia Consent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'nia.consent-review@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parents').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Pat Consent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'pat.consent-review@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '555-0120');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'nia.consent-review@example.com')
        .get();
    expect(learnerUsers.docs, hasLength(1));
    final String learnerId = learnerUsers.docs.single.id;

    final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'pat.consent-review@example.com')
        .get();
    expect(parentUsers.docs, hasLength(1));
    final String parentId = parentUsers.docs.single.id;

    await tester.tap(find.text('Links').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pat Consent').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nia Consent').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
    await tester.pump();
    await tester.pumpAndSettle();

    await firestore.collection('mediaConsents').doc('media-linked-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': learnerId,
        'photoCaptureAllowed': true,
        'shareWithLinkedParents': true,
        'marketingUseAllowed': false,
        'consentStatus': 'active',
        'consentStartDate': '2026-03-01',
      },
    );
    await firestore.collection('researchConsents').doc('research-linked-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': learnerId,
        'parentId': parentId,
        'consentGiven': true,
        'dataShareScope': 'pseudonymised',
        'consentVersion': 'v2',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: (() {
          final AppState state = AppState();
          state.updateFromMeResponse(<String, dynamic>{
            'userId': parentId,
            'email': 'pat.consent-review@example.com',
            'displayName': 'Pat Consent',
            'role': 'parent',
            'activeSiteId': 'site-1',
            'siteIds': <String>['site-1'],
            'entitlements': const <dynamic>[],
          });
          return state;
        })(),
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
    final QuerySnapshot<Map<String, dynamic>> requests =
        await firestore.collection('supportRequests').get();
    expect(requests.docs, hasLength(1));
    final Map<String, dynamic> request = requests.docs.single.data();
    expect(request['requestType'], 'parent_consent_review');
    expect(request['source'], 'parent_consent_request_review');
    expect(request['userId'], parentId);
    expect(
      (request['metadata'] as Map<String, dynamic>)['learnerId'],
      learnerId,
    );
    expect(
      (request['metadata'] as Map<String, dynamic>)['learnerName'],
      'Nia Consent',
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
