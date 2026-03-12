import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/modules/site/site_ops_page.dart';
import 'package:scholesa_app/services/api_client.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';

final ThemeData _testTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkRipple.splashFactory,
);

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({List<Map<String, dynamic>>? launches})
      : _launches = List<Map<String, dynamic>>.from(launches ?? <Map<String, dynamic>>[]),
        super(functions: null);

  final List<Map<String, dynamic>> _launches;
  int _nextLaunchId = 1;

  @override
  Future<List<Map<String, dynamic>>> listCohortLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Iterable<Map<String, dynamic>> scoped = (siteId == null || siteId.isEmpty)
        ? _launches
        : _launches.where((Map<String, dynamic> launch) => launch['siteId'] == siteId);
    return scoped.take(limit).map((Map<String, dynamic> launch) => Map<String, dynamic>.from(launch)).toList();
  }

  @override
  Future<String?> upsertCohortLaunch(Map<String, dynamic> data) async {
    final String id = (data['id'] as String?)?.trim().isNotEmpty == true
        ? (data['id'] as String).trim()
        : 'launch-${_nextLaunchId++}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': id,
      'siteId': data['siteId'],
      'cohortName': data['cohortName'],
      'ageBand': data['ageBand'],
      'scheduleLabel': data['scheduleLabel'],
      'programFormat': data['programFormat'],
      'curriculumTerm': data['curriculumTerm'],
      'rosterStatus': data['rosterStatus'],
      'parentCommunicationStatus': data['parentCommunicationStatus'],
      'baselineSurveyStatus': data['baselineSurveyStatus'],
      'kickoffStatus': data['kickoffStatus'],
      'status': data['status'] ?? 'planning',
      'learnerCount': data['learnerCount'],
      'notes': data['notes'],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _launches.removeWhere((Map<String, dynamic> launch) => launch['id'] == id);
    _launches.insert(0, record);
    return id;
  }
}

AppState _buildSiteState({String localeCode = 'en'}) {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site001.demo@scholesa.org',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': localeCode,
    'entitlements': <dynamic>[],
  });
  return state;
}

Future<void> _seedSiteOpsData(FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  await firestore.collection('checkins').doc('checkin-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
  });
  await firestore.collection('checkins').doc('checkout-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-2',
    'type': 'checkout',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 45))),
  });
  await firestore.collection('checkins').doc('other-site').set(<String, dynamic>{
    'siteId': 'site-2',
    'learnerId': 'learner-3',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
  });
  await firestore.collection('incidents').doc('incident-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'status': 'open',
    'reportedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 25))),
  });
  await firestore.collection('incidents').doc('incident-2').set(<String, dynamic>{
    'siteId': 'site-2',
    'status': 'open',
    'reportedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
  });
  await firestore.collection('siteOpsEvents').doc('ops-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'action': 'View Roster',
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
  });
  await firestore.collection('siteOpsEvents').doc('ops-2').set(<String, dynamic>{
    'siteId': 'site-2',
    'action': 'Check-in',
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
  });
}

Future<void> _seedProvisioningData(
  FakeFirebaseFirestore firestore, {
  bool includeGuardianLinks = true,
  bool includeParentIds = true,
}) async {
  final DateTime now = DateTime.now();
  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'displayName': 'Parent One',
    'email': 'parent1@example.com',
    'role': 'parent',
    'siteIds': <String>['site-1'],
  });
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner1@example.com',
    'role': 'learner',
    'siteIds': <String>['site-1'],
    'parentIds': includeParentIds ? <String>['parent-1'] : <String>[],
  });
  if (includeGuardianLinks) {
    await firestore.collection('guardianLinks').doc('link-1').set(<String, dynamic>{
      'siteId': 'site-1',
      'parentId': 'parent-1',
      'learnerId': 'learner-1',
      'relationship': 'Parent',
      'isPrimary': true,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': 'site-admin-1',
    });
    await firestore.collection('guardianLinks').doc('link-2').set(<String, dynamic>{
      'siteId': 'site-2',
      'parentId': 'parent-2',
      'learnerId': 'learner-2',
      'relationship': 'Parent',
      'isPrimary': false,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': 'site-admin-2',
    });
  }
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>> _findUserByEmail(
  FakeFirebaseFirestore firestore,
  String email,
) async {
  final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
      .collection('users')
      .where('email', isEqualTo: email.trim().toLowerCase())
      .limit(1)
      .get();
  expect(snapshot.docs, isNotEmpty);
  return snapshot.docs.first;
}

Future<void> _pumpSiteOpsPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
}) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
        Provider<FirestoreService>.value(value: firestoreService),
      ],
      child: MaterialApp(
        theme: _testTheme,
        supportedLocales: <Locale>[
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
        ],
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SiteOpsPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _pumpProvisioningPage(
  WidgetTester tester, {
  required FakeFirebaseFirestore firestore,
  required Locale locale,
  _FakeWorkflowBridgeService? workflowBridgeService,
}) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final _MockFirebaseAuth auth = _MockFirebaseAuth();
  final ProvisioningService service = ProvisioningService(
    apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
    firestore: firestore,
    auth: auth,
    workflowBridgeService: workflowBridgeService ?? _FakeWorkflowBridgeService(),
    useProvisioningApi: false,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(
          value: _buildSiteState(localeCode: locale.countryCode == 'TW' ? 'zh-TW' : locale.countryCode == 'CN' ? 'zh-CN' : 'en'),
        ),
        ChangeNotifierProvider<ProvisioningService>.value(value: service),
      ],
      child: MaterialApp(
        theme: _testTheme,
        locale: locale,
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
        home: const ProvisioningPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('Site ops and provisioning workflows', () {
    testWidgets('site ops shows only active-site activity and opens day when learners are present',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedSiteOpsData(firestore);

      await _pumpSiteOpsPage(tester, firestore: firestore);

      expect(find.text('Site is OPEN'), findsOneWidget);
      expect(find.text('Manual check-in recorded'), findsOneWidget);
      expect(find.text('Manual check-out recorded'), findsOneWidget);
      expect(find.text('New incident created'), findsOneWidget);
      expect(find.text('Roster viewed'), findsOneWidget);
      expect(find.text('No recent activity yet'), findsNothing);
    });

    testWidgets('provisioning delete confirmation renders zh-CN guardian link copy',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedProvisioningData(firestore);

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('zh', 'CN'),
      );

      await tester.tap(find.text('关联'));
      await tester.pumpAndSettle();

      expect(find.text('Parent One → Learner One'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('删除关联'), findsOneWidget);
      expect(
        find.text('要移除 Parent One 与 Learner One 之间的监护人关联吗？'),
        findsOneWidget,
      );
    });

    testWidgets('provisioning delete confirmation renders zh-TW guardian link copy',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedProvisioningData(firestore);

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('zh', 'TW'),
      );

      await tester.tap(find.text('關聯'));
      await tester.pumpAndSettle();

      expect(find.text('Parent One → Learner One'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('刪除關聯'), findsOneWidget);
      expect(
        find.text('要移除 Parent One 與 Learner One 之間的監護人關聯嗎？'),
        findsOneWidget,
      );
    });

    testWidgets('provisioning deletes active-site guardian links and updates the UI',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedProvisioningData(firestore);

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('en'),
      );

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();

      expect(find.text('Parent One → Learner One'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Link removed'), findsOneWidget);
      expect(find.text('Parent One → Learner One'), findsNothing);
      expect((await firestore.collection('guardianLinks').doc('link-1').get()).exists, isFalse);
      expect((await firestore.collection('guardianLinks').doc('link-2').get()).exists, isTrue);
    });

    testWidgets('provisioning creates a learner from the add learner dialog',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('en'),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ava Maker');
      await tester.enterText(find.byType(TextFormField).at(1), 'ava@example.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Learner created successfully'), findsOneWidget);
      expect(find.text('Ava Maker'), findsOneWidget);

      final QueryDocumentSnapshot<Map<String, dynamic>> userDoc =
          await _findUserByEmail(firestore, 'ava@example.com');
      expect(userDoc.data()['role'], 'learner');
      expect(userDoc.data()['siteIds'], contains('site-1'));

      final DocumentSnapshot<Map<String, dynamic>> profileDoc =
          await firestore.collection('learnerProfiles').doc(userDoc.id).get();
      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()!['displayName'], 'Ava Maker');
    });

    testWidgets('provisioning creates a parent from the add parent dialog',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('en'),
      );

      await tester.tap(find.text('Parents'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Mina Parent');
      await tester.enterText(find.byType(TextFormField).at(1), 'mina.parent@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '+61 400 555 121');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Parent created successfully'), findsOneWidget);
      expect(find.text('Mina Parent'), findsOneWidget);

      final QueryDocumentSnapshot<Map<String, dynamic>> userDoc =
          await _findUserByEmail(firestore, 'mina.parent@example.com');
      expect(userDoc.data()['role'], 'parent');
      expect(userDoc.data()['siteIds'], contains('site-1'));

      final DocumentSnapshot<Map<String, dynamic>> profileDoc =
          await firestore.collection('parentProfiles').doc(userDoc.id).get();
      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()!['phone'], '+61 400 555 121');
    });

    testWidgets('provisioning creates a guardian link from the create link dialog',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedProvisioningData(
        firestore,
        includeGuardianLinks: false,
        includeParentIds: false,
      );

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('en'),
      );

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent One').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learner One').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primary guardian'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
      await tester.pumpAndSettle();

      expect(find.text('Guardian link created successfully'), findsOneWidget);
      expect(find.text('Parent One → Learner One'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);

      final QuerySnapshot<Map<String, dynamic>> linksSnapshot = await firestore
          .collection('guardianLinks')
          .where('siteId', isEqualTo: 'site-1')
          .get();
      expect(linksSnapshot.docs, hasLength(1));
      expect(linksSnapshot.docs.first.data()['isPrimary'], isTrue);

      final DocumentSnapshot<Map<String, dynamic>> learnerDoc =
          await firestore.collection('users').doc('learner-1').get();
      expect(learnerDoc.data()!['parentIds'], contains('parent-1'));
    });

    testWidgets('provisioning creates a cohort launch from the cohort dialog',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final _FakeWorkflowBridgeService workflowBridgeService =
          _FakeWorkflowBridgeService();

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('en'),
        workflowBridgeService: workflowBridgeService,
      );

      await tester.tap(find.text('Cohorts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Launch Cohort Alpha');
      await tester.enterText(find.byType(TextFormField).at(3), '24');
      await tester.enterText(find.byType(TextFormField).at(4), 'Parent kickoff scheduled.');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Cohort launch created successfully'), findsOneWidget);
      expect(find.text('Launch Cohort Alpha'), findsOneWidget);
      expect(find.text('Learner Count: 24'), findsOneWidget);
      expect(find.text('Parent kickoff scheduled.'), findsOneWidget);
    });
  });
}