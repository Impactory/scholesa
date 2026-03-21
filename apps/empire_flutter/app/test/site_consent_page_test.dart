import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/site/site_consent_page.dart';
import 'package:scholesa_app/modules/site/site_consent_service.dart';

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
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: appState),
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
