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

class _DeterministicProvisioningService extends ProvisioningService {
  _DeterministicProvisioningService({
    List<LearnerProfile>? learners,
    List<ParentProfile>? parents,
    List<GuardianLink>? guardianLinks,
    List<CohortLaunch>? cohortLaunches,
    this.failCreateLearner = false,
    this.failCreateParent = false,
    this.failCreateGuardianLink = false,
    this.failCreateCohortLaunch = false,
    this.failUpdateLearner = false,
    this.failUpdateParent = false,
    this.failDeleteGuardianLink = false,
  })  : _learnersValue = List<LearnerProfile>.from(learners ?? const <LearnerProfile>[]),
        _parentsValue = List<ParentProfile>.from(parents ?? const <ParentProfile>[]),
        _guardianLinksValue = List<GuardianLink>.from(guardianLinks ?? const <GuardianLink>[]),
        _cohortLaunchesValue = List<CohortLaunch>.from(cohortLaunches ?? const <CohortLaunch>[]),
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
  final List<ParentProfile> _parentsValue;
  final List<GuardianLink> _guardianLinksValue;
  final List<CohortLaunch> _cohortLaunchesValue;
  final bool failCreateLearner;
  final bool failCreateParent;
  final bool failCreateGuardianLink;
  final bool failCreateCohortLaunch;
  final bool failUpdateLearner;
  final bool failUpdateParent;
  final bool failDeleteGuardianLink;

  bool _isLoadingValue = false;
  String? _errorValue;

  @override
  List<LearnerProfile> get learners => _learnersValue;

  @override
  List<ParentProfile> get parents => _parentsValue;

  @override
  List<GuardianLink> get guardianLinks => _guardianLinksValue;

  @override
  List<CohortLaunch> get cohortLaunches => _cohortLaunchesValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadLearners(String siteId) async {}

  @override
  Future<void> loadParents(String siteId) async {}

  @override
  Future<void> loadGuardianLinks(String siteId) async {}

  @override
  Future<void> loadCohortLaunches(String siteId) async {}

  @override
  Future<LearnerProfile?> createLearner({
    required String siteId,
    required String email,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    if (failCreateLearner) {
      _errorValue = 'Failed to create learner from test';
      notifyListeners();
      return null;
    }
    return super.createLearner(
      siteId: siteId,
      email: email,
      displayName: displayName,
      gradeLevel: gradeLevel,
      dateOfBirth: dateOfBirth,
      notes: notes,
    );
  }

  @override
  Future<ParentProfile?> createParent({
    required String siteId,
    required String email,
    required String displayName,
    String? phone,
  }) async {
    if (failCreateParent) {
      _errorValue = 'Failed to create parent from test';
      notifyListeners();
      return null;
    }
    return super.createParent(
      siteId: siteId,
      email: email,
      displayName: displayName,
      phone: phone,
    );
  }

  @override
  Future<GuardianLink?> createGuardianLink({
    required String siteId,
    required String parentId,
    required String learnerId,
    required String relationship,
    bool isPrimary = false,
  }) async {
    if (failCreateGuardianLink) {
      _errorValue = 'Failed to create guardian link from test';
      notifyListeners();
      return null;
    }
    return super.createGuardianLink(
      siteId: siteId,
      parentId: parentId,
      learnerId: learnerId,
      relationship: relationship,
      isPrimary: isPrimary,
    );
  }

  @override
  Future<CohortLaunch?> createCohortLaunch({
    required String siteId,
    required String cohortName,
    required String ageBand,
    required String scheduleLabel,
    required String programFormat,
    required String curriculumTerm,
    required String rosterStatus,
    required String parentCommunicationStatus,
    required String baselineSurveyStatus,
    required String kickoffStatus,
    int? learnerCount,
    String? notes,
  }) async {
    if (failCreateCohortLaunch) {
      _errorValue = 'Failed to create cohort launch from test';
      notifyListeners();
      return null;
    }
    return super.createCohortLaunch(
      siteId: siteId,
      cohortName: cohortName,
      ageBand: ageBand,
      scheduleLabel: scheduleLabel,
      programFormat: programFormat,
      curriculumTerm: curriculumTerm,
      rosterStatus: rosterStatus,
      parentCommunicationStatus: parentCommunicationStatus,
      baselineSurveyStatus: baselineSurveyStatus,
      kickoffStatus: kickoffStatus,
      learnerCount: learnerCount,
      notes: notes,
    );
  }

  @override
  Future<LearnerProfile?> updateLearner({
    required String siteId,
    required String learnerId,
    required String displayName,
    int? gradeLevel,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    if (failUpdateLearner) {
      _errorValue = 'Failed to update learner from test';
      notifyListeners();
      return null;
    }
    final int index =
        _learnersValue.indexWhere((LearnerProfile learner) => learner.id == learnerId);
    if (index >= 0) {
      _learnersValue[index] = LearnerProfile(
        id: learnerId,
        siteId: siteId,
        userId: learnerId,
        displayName: displayName,
        gradeLevel: gradeLevel,
        dateOfBirth: dateOfBirth,
        notes: notes,
      );
      notifyListeners();
      return _learnersValue[index];
    }
    return null;
  }

  @override
  Future<ParentProfile?> updateParent({
    required String siteId,
    required String parentId,
    required String displayName,
    String? phone,
    String? email,
  }) async {
    if (failUpdateParent) {
      _errorValue = 'Failed to update parent from test';
      notifyListeners();
      return null;
    }
    final int index =
        _parentsValue.indexWhere((ParentProfile parent) => parent.id == parentId);
    if (index >= 0) {
      _parentsValue[index] = ParentProfile(
        id: parentId,
        siteId: siteId,
        userId: parentId,
        displayName: displayName,
        phone: phone,
        email: email,
      );
      notifyListeners();
      return _parentsValue[index];
    }
    return null;
  }

  @override
  Future<bool> deleteGuardianLink(String linkId) async {
    if (failDeleteGuardianLink) {
      _errorValue = 'Failed to delete guardian link from test';
      notifyListeners();
      return false;
    }
    _guardianLinksValue.removeWhere((GuardianLink link) => link.id == linkId);
    notifyListeners();
    return true;
  }
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

  testWidgets('provisioning page shows explicit learner create failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      failCreateLearner: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Failed Learner');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'failed.learner@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create learner from test'), findsOneWidget);
    expect(find.text('Learner created successfully'), findsNothing);
    expect(find.text('Failed Learner'), findsNothing);
    expect(find.text('Add Learner'), findsOneWidget);
  });

  testWidgets('provisioning page shows explicit parent create failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      failCreateParent: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Parents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Failed Parent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'failed.parent@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create parent from test'), findsOneWidget);
    expect(find.text('Parent created successfully'), findsNothing);
    expect(find.text('Failed Parent'), findsNothing);
    expect(find.text('Add Parent'), findsOneWidget);
  });

  testWidgets('provisioning page shows explicit guardian link create failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      learners: const <LearnerProfile>[
        LearnerProfile(
          id: 'learner-1',
          siteId: 'site-1',
          userId: 'learner-1',
          displayName: 'Learner One',
        ),
      ],
      parents: const <ParentProfile>[
        ParentProfile(
          id: 'parent-1',
          siteId: 'site-1',
          userId: 'parent-1',
          displayName: 'Parent One',
          email: 'parent1@example.com',
        ),
      ],
      failCreateGuardianLink: true,
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
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Link'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create guardian link from test'), findsOneWidget);
    expect(find.text('Guardian link created successfully'), findsNothing);
    expect(find.text('Create Guardian Link'), findsOneWidget);
    expect(find.text('Parent One → Learner One'), findsNothing);
  });

  testWidgets('provisioning page shows explicit cohort create failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      failCreateCohortLaunch: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Cohorts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Failed Cohort',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to create cohort launch from test'), findsOneWidget);
    expect(find.text('Cohort launch created successfully'), findsNothing);
    expect(find.text('Failed Cohort'), findsNothing);
    expect(find.text('Create Cohort Launch'), findsOneWidget);
  });

  testWidgets('provisioning page shows explicit learner edit failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      learners: const <LearnerProfile>[
        LearnerProfile(
          id: 'learner-1',
          siteId: 'site-1',
          userId: 'learner-1',
          displayName: 'Learner One',
          gradeLevel: 5,
        ),
      ],
      failUpdateLearner: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Learner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Learner Broken');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to update learner from test'), findsOneWidget);
    expect(find.text('Learner updated'), findsNothing);
    expect(find.text('Learner One'), findsOneWidget);
    expect(find.text('Learner Broken'), findsNothing);
    expect(find.text('Edit Learner'), findsOneWidget);
  });

  testWidgets('provisioning page shows explicit parent edit failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      parents: const <ParentProfile>[
        ParentProfile(
          id: 'parent-1',
          siteId: 'site-1',
          userId: 'parent-1',
          displayName: 'Parent One',
          email: 'parent1@example.com',
          phone: '+61 400 555 100',
        ),
      ],
      failUpdateParent: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Parents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Parent'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Parent Broken');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to update parent from test'), findsOneWidget);
    expect(find.text('Parent updated'), findsNothing);
    expect(find.text('Parent One'), findsOneWidget);
    expect(find.text('Parent Broken'), findsNothing);
    expect(find.text('Edit Parent'), findsOneWidget);
  });

  testWidgets('provisioning page shows explicit guardian link delete failure',
      (WidgetTester tester) async {
    final ProvisioningService service = _DeterministicProvisioningService(
      guardianLinks: <GuardianLink>[
        GuardianLink(
          id: 'link-1',
          siteId: 'site-1',
          parentId: 'parent-1',
          learnerId: 'learner-1',
          relationship: 'Parent',
          isPrimary: true,
          createdAt: DateTime(2026, 3, 21),
          createdBy: 'site-admin-1',
          parentName: 'Parent One',
          learnerName: 'Learner One',
        ),
      ],
      failDeleteGuardianLink: true,
    );

    await pumpProvisioningPage(tester, service: service);

    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    expect(find.text('Parent One → Learner One'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to delete guardian link from test'), findsOneWidget);
    expect(find.text('Link removed'), findsNothing);
    expect(find.text('Parent One → Learner One'), findsOneWidget);
  });
}
