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
import 'package:scholesa_app/modules/site/site_consent_page.dart';
import 'package:scholesa_app/modules/site/site_consent_service.dart';
import 'package:scholesa_app/services/api_client.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingSiteConsentService extends SiteConsentService {
  _ThrowingSiteConsentService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<SiteConsentRecord>> listRecords(String siteId) async {
    throw StateError('consents unavailable');
  }
}

class _SequencedSiteConsentService extends SiteConsentService {
  _SequencedSiteConsentService({required this.snapshots})
      : super(firestore: FakeFirebaseFirestore());

  final List<Object> snapshots;
  int _callCount = 0;

  @override
  Future<List<SiteConsentRecord>> listRecords(String siteId) async {
    final Object snapshot = _callCount < snapshots.length
        ? snapshots[_callCount]
        : snapshots.last;
    _callCount += 1;
    if (snapshot is Exception) {
      throw snapshot;
    }
    if (snapshot is Error) {
      throw snapshot;
    }
    return List<SiteConsentRecord>.from(snapshot as List<SiteConsentRecord>);
  }
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
    'localeCode': 'en',
    'entitlements': const <Map<String, dynamic>>[],
  });
  return state;
}

Widget _buildHarness({
  required AppState appState,
  required Widget child,
  List<SingleChildWidget> providers = const <SingleChildWidget>[],
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
      ...providers,
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
      home: child,
    ),
  );
}

Future<void> _pumpProvisioningPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  final _FakeFirebaseAuth auth = _FakeFirebaseAuth();
  final ProvisioningService service = ProvisioningService(
    apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
    firestore: firestore,
    auth: auth,
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
  await firestore.collection('learnerProfiles').doc('profile-1').set(
    <String, dynamic>{
      'learnerId': 'learner-1',
      'siteId': 'site-1',
      'preferredName': 'Ava Stone',
    },
  );
  await firestore.collection('learnerProfiles').doc('profile-2').set(
    <String, dynamic>{
      'learnerId': 'learner-2',
      'siteId': 'site-1',
      'preferredName': 'Ben Rivers',
    },
  );
  await firestore.collection('guardianLinks').doc('guardian-link-1').set(
    <String, dynamic>{
      'parentId': 'parent-1',
      'learnerId': 'learner-2',
      'siteId': 'site-1',
      'relationship': 'Guardian',
      'isPrimary': true,
    },
  );
  await firestore.collection('parentProfiles').doc('parent-1').set(
    <String, dynamic>{
      'parentId': 'parent-1',
      'siteId': 'site-1',
      'preferredName': 'Bea Rivers',
      'email': 'bea@example.com',
    },
  );
  await firestore.collection('users').doc('parent-1').set(
    <String, dynamic>{
      'displayName': 'Bea Rivers',
      'email': 'bea@example.com',
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
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9)),
    },
  );
  await firestore.collection('researchConsents').doc('research-1').set(
    <String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-1',
      'parentId': 'parent-1',
      'consentGiven': true,
      'dataShareScope': 'pseudonymised',
      'consentVersion': 'v1',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 18, 9, 15)),
    },
  );
}

void main() {
  testWidgets(
      'site consent loads live consent records and persists media and research updates with audit logs',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedConsentData(firestore);

    await tester.binding.setSurfaceSize(const Size(1280, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SiteConsentPage(
          service: SiteConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('Ben Rivers'), findsOneWidget);
    expect(find.text('No media consent has been recorded for this learner yet.'),
        findsOneWidget);
    expect(find.textContaining('Bea Rivers'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Edit Media Consent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow photo capture'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Consent document URL'),
      'https://example.com/media-ben.pdf',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit Research Consent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research consent granted'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Consent version'),
      'v2',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> mediaSnapshot = await firestore
        .collection('mediaConsents')
        .where('siteId', isEqualTo: 'site-1')
        .where('learnerId', isEqualTo: 'learner-2')
        .get();
    expect(mediaSnapshot.docs, hasLength(1));
    expect(mediaSnapshot.docs.first.data()['photoCaptureAllowed'], isTrue);
    expect(
      mediaSnapshot.docs.first.data()['consentDocumentUrl'],
      'https://example.com/media-ben.pdf',
    );

    final QuerySnapshot<Map<String, dynamic>> researchSnapshot = await firestore
        .collection('researchConsents')
        .where('siteId', isEqualTo: 'site-1')
        .where('learnerId', isEqualTo: 'learner-2')
        .get();
    expect(researchSnapshot.docs, hasLength(1));
    expect(researchSnapshot.docs.first.data()['parentId'], 'parent-1');
    expect(researchSnapshot.docs.first.data()['consentGiven'], isTrue);
    expect(researchSnapshot.docs.first.data()['consentVersion'], 'v2');

    final QuerySnapshot<Map<String, dynamic>> auditSnapshot =
        await firestore.collection('auditLogs').get();
    expect(
      auditSnapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              doc.data()['action'])
          .whereType<String>()
          .toSet(),
      containsAll(<String>[
        'consent.media.updated',
        'consent.research.updated',
      ]),
    );
  });

  testWidgets(
      'site consent shows provisioning-linked learners and parents in the live consent workflow',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

    await tester.binding.setSurfaceSize(const Size(1280, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProvisioningPage(tester, firestore: firestore);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nia Consent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'nia.site.consent@example.com',
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
      'pat.site.consent@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '555-0126');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pumpAndSettle();

    final QuerySnapshot<Map<String, dynamic>> learnerUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'nia.site.consent@example.com')
        .get();
    expect(learnerUsers.docs, hasLength(1));
    final String learnerId = learnerUsers.docs.single.id;

    final QuerySnapshot<Map<String, dynamic>> parentUsers = await firestore
        .collection('users')
        .where('email', isEqualTo: 'pat.site.consent@example.com')
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

    await firestore.collection('mediaConsents').doc('media-live-1').set(
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
    await firestore.collection('researchConsents').doc('research-live-1').set(
      <String, dynamic>{
        'siteId': 'site-1',
        'learnerId': learnerId,
        'parentId': parentId,
        'consentGiven': true,
        'dataShareScope': 'pseudonymised',
        'consentVersion': 'v1',
      },
    );
    await firestore.collection('learnerProfiles').doc('other-site-profile-1').set(
      <String, dynamic>{
        'learnerId': 'other-site-learner-1',
        'siteId': 'site-2',
        'preferredName': 'Other Site Learner',
      },
    );
    await firestore.collection('researchConsents').doc('research-other-site').set(
      <String, dynamic>{
        'siteId': 'site-2',
        'learnerId': 'other-site-learner-1',
        'parentId': 'other-parent',
        'consentGiven': true,
        'dataShareScope': 'identifiable',
        'consentVersion': 'secret',
      },
    );

    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SiteConsentPage(
          service: SiteConsentService(firestore: firestore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nia Consent'), findsOneWidget);
    expect(find.textContaining('Pat Consent'), findsOneWidget);
    expect(find.text('Other Site Learner'), findsNothing);
    expect(find.textContaining('Photo capture: Allowed'), findsOneWidget);
    expect(find.textContaining('Consent version: v1'), findsOneWidget);
  });

  testWidgets('site consent shows explicit error state when loading fails',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SiteConsentPage(
          service: _ThrowingSiteConsentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load consent records right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('site consent keeps stale records visible after refresh failure',
      (WidgetTester tester) async {
    final _SequencedSiteConsentService service = _SequencedSiteConsentService(
      snapshots: <Object>[
        <SiteConsentRecord>[
          SiteConsentRecord(
            learnerId: 'learner-1',
            learnerName: 'Ava Stone',
            guardians: const <SiteConsentGuardianOption>[],
          ),
        ],
        StateError('consent refresh unavailable'),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildHarness(
        appState: _buildSiteState(),
        child: SiteConsentPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('No learner consent records are available for this site yet.'), findsNothing);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to refresh consent records right now. Showing the last successful data.'),
      findsOneWidget,
    );
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('No learner consent records are available for this site yet.'), findsNothing);
  });
}
