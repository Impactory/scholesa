import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_models.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_page.dart';
import 'package:scholesa_app/modules/provisioning/provisioning_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/services/api_client.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({List<Map<String, dynamic>>? launches})
      : _launches = List<Map<String, dynamic>>.from(
          launches ?? <Map<String, dynamic>>[],
        ),
        super(functions: null);

  final List<Map<String, dynamic>> _launches;
  int _nextLaunchId = 1;

  @override
  Future<List<Map<String, dynamic>>> listCohortLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _launches
            : _launches.where(
                (Map<String, dynamic> launch) => launch['siteId'] == siteId,
              );
    return scoped
        .take(limit)
        .map((Map<String, dynamic> launch) => Map<String, dynamic>.from(launch))
        .toList();
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

class _FakeProvisioningService extends ProvisioningService {
  _FakeProvisioningService({
    List<LearnerProfile>? learners,
    this.loadError,
  })  : _learnersValue = learners ?? <LearnerProfile>[],
        super(
          apiClient: ApiClient(
            auth: _MockFirebaseAuth(),
            baseUrl: 'http://localhost',
          ),
          firestore: FakeFirebaseFirestore(),
          auth: _MockFirebaseAuth(),
          useProvisioningApi: false,
        );

  final List<LearnerProfile> _learnersValue;
  final String? loadError;

  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<LearnerProfile> get learners => _learnersValue;

  @override
  List<ParentProfile> get parents => const <ParentProfile>[];

  @override
  List<GuardianLink> get guardianLinks => const <GuardianLink>[];

  @override
  List<CohortLaunch> get cohortLaunches => const <CohortLaunch>[];

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadLearners(String siteId) async {
    _isLoadingValue = true;
    _errorValue = null;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _errorValue = loadError;
    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<void> loadParents(String siteId) async {}

  @override
  Future<void> loadGuardianLinks(String siteId) async {}

  @override
  Future<void> loadCohortLaunches(String siteId) async {}
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
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

Widget _buildHarness({required ProvisioningService service}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
      ChangeNotifierProvider<ProvisioningService>.value(value: service),
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
      home: const ProvisioningPage(),
    ),
  );
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

Future<void> _seedEditableProvisioningProfiles(
  FakeFirebaseFirestore firestore,
) async {
  await firestore.collection('users').doc('learner-1').set(<String, dynamic>{
    'displayName': 'Learner One',
    'email': 'learner1@example.com',
    'role': 'learner',
    'siteIds': <String>['site-1'],
    'activeSiteId': 'site-1',
    'gradeLevel': 5,
  });
  await firestore.collection('learnerProfiles').doc('learner-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'userId': 'learner-1',
    'displayName': 'Learner One',
    'gradeLevel': 5,
  });

  await firestore.collection('users').doc('parent-1').set(<String, dynamic>{
    'displayName': 'Parent One',
    'email': 'parent1@example.com',
    'phone': '+61 400 555 100',
    'role': 'parent',
    'siteIds': <String>['site-1'],
    'activeSiteId': 'site-1',
  });
  await firestore.collection('parentProfiles').doc('parent-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'parentId': 'parent-1',
    'userId': 'parent-1',
    'displayName': 'Parent One',
    'email': 'parent1@example.com',
    'phone': '+61 400 555 100',
  });
}

void main() {
  Future<void> pumpProvisioningPage(
    WidgetTester tester, {
    required ProvisioningService service,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildHarness(service: service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'provisioning page shows an explicit learner load error instead of an empty state',
      (WidgetTester tester) async {
    await pumpProvisioningPage(
      tester,
      service: _FakeProvisioningService(
        loadError: 'Failed to load learners from test',
      ),
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Unable to load learners'), findsOneWidget);
    expect(find.text('Failed to load learners from test'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No learners yet'), findsNothing);
  });

  testWidgets(
      'provisioning page keeps loaded learners visible behind a stale-data banner',
      (WidgetTester tester) async {
    await pumpProvisioningPage(
      tester,
      service: _FakeProvisioningService(
        learners: const <LearnerProfile>[
          LearnerProfile(
            id: 'learner-1',
            siteId: 'site-1',
            userId: 'learner-user-1',
            displayName: 'Learner One',
            gradeLevel: 6,
          ),
        ],
        loadError: 'Failed to refresh learners from test',
      ),
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(
      find.text(
        'Showing last loaded provisioning data. Failed to refresh learners from test',
      ),
      findsOneWidget,
    );
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Grade 6'), findsOneWidget);
  });

  testWidgets('provisioning page creates a learner from the add learner dialog',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

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

  testWidgets('provisioning page creates a parent from the add parent dialog',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Parents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Mina Parent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'mina.parent@example.com',
    );
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

  testWidgets('provisioning page creates a guardian link from the link dialog',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedProvisioningData(
      firestore,
      includeGuardianLinks: false,
      includeParentIds: false,
    );
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

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

  testWidgets('provisioning page deletes active-site guardian links',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedProvisioningData(firestore);
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();

    expect(find.text('Parent One → Learner One'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Link removed'), findsOneWidget);
    expect(find.text('Parent One → Learner One'), findsNothing);
    expect(
      (await firestore.collection('guardianLinks').doc('link-1').get()).exists,
      isFalse,
    );
    expect(
      (await firestore.collection('guardianLinks').doc('link-2').get()).exists,
      isTrue,
    );
  });

  testWidgets('provisioning page creates a cohort launch from the cohort dialog',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final _FakeWorkflowBridgeService workflowBridgeService =
        _FakeWorkflowBridgeService();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: workflowBridgeService,
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Cohorts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Launch Cohort Alpha',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '24');
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Parent kickoff scheduled.',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Cohort launch created successfully'), findsOneWidget);
    expect(find.text('Launch Cohort Alpha'), findsOneWidget);
    expect(find.text('Learner Count: 24'), findsOneWidget);
    expect(find.text('Parent kickoff scheduled.'), findsOneWidget);
  });

  testWidgets('provisioning page edits a learner and persists the change',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedEditableProvisioningProfiles(firestore);
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

    expect(find.text('Learner One'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Learner'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Learner Prime');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Learner updated'), findsOneWidget);
    expect(find.text('Learner Prime'), findsOneWidget);
    expect(find.text('Learner One'), findsNothing);

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await firestore.collection('users').doc('learner-1').get();
    final DocumentSnapshot<Map<String, dynamic>> profileDoc = await firestore
        .collection('learnerProfiles')
        .doc('learner-1')
        .get();
    expect(userDoc.data()!['displayName'], 'Learner Prime');
    expect(profileDoc.data()!['displayName'], 'Learner Prime');
  });

  testWidgets('provisioning page edits a parent and persists the change',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedEditableProvisioningProfiles(firestore);
    final _MockFirebaseAuth auth = _MockFirebaseAuth();
    final ProvisioningService service = ProvisioningService(
      apiClient: ApiClient(auth: auth, baseUrl: 'http://localhost'),
      firestore: firestore,
      auth: auth,
      workflowBridgeService: _FakeWorkflowBridgeService(),
      useProvisioningApi: false,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Parents'));
    await tester.pumpAndSettle();
    expect(find.text('Parent One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Parent'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Parent Prime');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      '+61 400 555 999',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Parent updated'), findsOneWidget);
    expect(find.text('Parent Prime'), findsOneWidget);
    expect(find.text('Parent One'), findsNothing);

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await firestore.collection('users').doc('parent-1').get();
    final DocumentSnapshot<Map<String, dynamic>> profileDoc = await firestore
        .collection('parentProfiles')
        .doc('parent-1')
        .get();
    expect(userDoc.data()!['displayName'], 'Parent Prime');
    expect(userDoc.data()!['phone'], '+61 400 555 999');
    expect(profileDoc.data()!['displayName'], 'Parent Prime');
    expect(profileDoc.data()!['phone'], '+61 400 555 999');
  });
}
