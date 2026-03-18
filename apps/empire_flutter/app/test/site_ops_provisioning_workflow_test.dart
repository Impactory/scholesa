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
  _FakeWorkflowBridgeService({
    List<Map<String, dynamic>>? launches,
    List<Map<String, dynamic>>? runtimeDeliveries,
    List<Map<String, dynamic>>? runtimeActivations,
    Map<String, dynamic>? resolvedRuntimePackage,
  })  : _launches = List<Map<String, dynamic>>.from(
            launches ?? <Map<String, dynamic>>[]),
        _runtimeDeliveries = List<Map<String, dynamic>>.from(
          runtimeDeliveries ?? <Map<String, dynamic>>[],
        ),
        _runtimeActivations = List<Map<String, dynamic>>.from(
          runtimeActivations ?? <Map<String, dynamic>>[],
        ),
        _resolvedRuntimePackage = resolvedRuntimePackage == null
            ? null
            : Map<String, dynamic>.from(resolvedRuntimePackage),
        super(functions: null);

  final List<Map<String, dynamic>> _launches;
  final List<Map<String, dynamic>> _runtimeDeliveries;
  final List<Map<String, dynamic>> _runtimeActivations;
  final Map<String, dynamic>? _resolvedRuntimePackage;
  int _nextLaunchId = 1;

  @override
  Future<List<Map<String, dynamic>>> listCohortLaunches({
    String? siteId,
    int limit = 80,
  }) async {
    final Iterable<Map<String, dynamic>> scoped = (siteId == null ||
            siteId.isEmpty)
        ? _launches
        : _launches
            .where((Map<String, dynamic> launch) => launch['siteId'] == siteId);
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

  @override
  Future<List<Map<String, dynamic>>>
      listSiteFederatedLearningRuntimeDeliveryRecords({
    String? siteId,
    int limit = 40,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _runtimeDeliveries
            : _runtimeDeliveries.where((Map<String, dynamic> record) {
                final List<dynamic> targetSiteIds =
                    record['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
                return targetSiteIds.cast<String>().contains(siteId);
              });
    return scoped
        .where((Map<String, dynamic> record) {
          final String status = (record['status'] as String? ?? '').trim();
          final String terminalLifecycleStatus =
              (record['terminalLifecycleStatus'] as String? ?? '').trim();
          return (status == 'assigned' || status == 'active') &&
              terminalLifecycleStatus.isEmpty;
        })
        .take(limit)
        .map((Map<String, dynamic> record) => Map<String, dynamic>.from(record))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listSiteFederatedLearningRuntimeDeliveryHistoryRecords({
    String? siteId,
    int limit = 20,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _runtimeDeliveries
            : _runtimeDeliveries.where((Map<String, dynamic> record) {
                final List<dynamic> targetSiteIds =
                    record['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
                return targetSiteIds.cast<String>().contains(siteId);
              });
    return scoped
        .take(limit)
        .map((Map<String, dynamic> record) => Map<String, dynamic>.from(record))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listSiteFederatedLearningRuntimeActivationRecords({
    String? siteId,
    int limit = 40,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _runtimeActivations
            : _runtimeActivations.where(
                (Map<String, dynamic> record) => record['siteId'] == siteId,
              );
    return scoped
        .take(limit)
        .map((Map<String, dynamic> record) => Map<String, dynamic>.from(record))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> resolveSiteFederatedLearningRuntimePackage({
    String? siteId,
    String? experimentId,
    String? runtimeTarget,
    String? deliveryRecordId,
  }) async {
    if (_resolvedRuntimePackage == null) {
      return null;
    }
    if ((siteId ?? '').isNotEmpty &&
        _resolvedRuntimePackage['siteId'] != siteId) {
      return null;
    }
    return Map<String, dynamic>.from(_resolvedRuntimePackage);
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
  final DateTime dayStart = DateTime(now.year, now.month, now.day);
  final String dayKey =
      '${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}';
  await firestore.collection('checkins').doc('checkin-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-1',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
  });
  await firestore
      .collection('checkins')
      .doc('checkout-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-2',
    'type': 'checkout',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 45))),
  });
  await firestore
      .collection('checkins')
      .doc('other-site')
      .set(<String, dynamic>{
    'siteId': 'site-2',
    'learnerId': 'learner-3',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
  });
  await firestore
      .collection('incidents')
      .doc('incident-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'status': 'open',
    'reportedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 25))),
  });
  await firestore
      .collection('incidents')
      .doc('incident-2')
      .set(<String, dynamic>{
    'siteId': 'site-2',
    'status': 'open',
    'reportedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
  });
  await firestore
      .collection('siteOpsEvents')
      .doc('ops-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'action': 'View Roster',
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
  });
  await firestore
      .collection('siteOpsEvents')
      .doc('ops-2')
      .set(<String, dynamic>{
    'siteId': 'site-2',
    'action': 'Check-in',
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
  });
  await firestore.collection('sessions').doc('session-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'title': 'Robotics Lab',
    'educatorName': 'Coach Ada',
    'room': 'Lab 2',
    'learnerCount': 14,
    'startTime': Timestamp.fromDate(
      dayStart.add(const Duration(hours: 9, minutes: 30)),
    ),
  });
  await firestore.collection('sessions').doc('session-2').set(<String, dynamic>{
    'siteId': 'site-2',
    'title': 'Ignore Other Site',
    'educatorName': 'Coach Lin',
    'room': 'Lab 9',
    'learnerCount': 10,
    'startTime': Timestamp.fromDate(dayStart.add(const Duration(hours: 11))),
  });
  await firestore
      .collection('siteOpsKitChecklist')
      .doc('arrival-tablets')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'dayKey': dayKey,
    'label': 'Tablets charged',
    'completed': false,
    'order': 1,
    'note': 'Verify every learner device is above 70%',
  });
  await firestore
      .collection('siteSafetyNotes')
      .doc('note-1')
      .set(<String, dynamic>{
    'siteId': 'site-1',
    'dayKey': dayKey,
    'note': 'Guardian pickup change confirmed',
    'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 20))),
    'createdByName': 'Site Admin',
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
    await firestore
        .collection('guardianLinks')
        .doc('link-1')
        .set(<String, dynamic>{
      'siteId': 'site-1',
      'parentId': 'parent-1',
      'learnerId': 'learner-1',
      'relationship': 'Parent',
      'isPrimary': true,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': 'site-admin-1',
    });
    await firestore
        .collection('guardianLinks')
        .doc('link-2')
        .set(<String, dynamic>{
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
  _FakeWorkflowBridgeService? workflowBridgeService,
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
        home: SiteOpsPage(workflowBridge: workflowBridgeService),
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
    workflowBridgeService:
        workflowBridgeService ?? _FakeWorkflowBridgeService(),
    useProvisioningApi: false,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(
          value: _buildSiteState(
              localeCode: locale.countryCode == 'TW'
                  ? 'zh-TW'
                  : locale.countryCode == 'CN'
                      ? 'zh-CN'
                      : 'en'),
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
    testWidgets(
        'site ops shows only active-site activity and opens day when learners are present',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedSiteOpsData(firestore);

      await _pumpSiteOpsPage(tester, firestore: firestore);

      expect(find.text('Site is OPEN'), findsOneWidget);
      expect(find.text('Manual check-in recorded'), findsOneWidget);
      expect(find.text('Manual check-out recorded'), findsOneWidget);
      expect(find.text('New incident created'), findsOneWidget);
      expect(find.text('Roster viewed'), findsOneWidget);
      expect(find.text('Today Timetable'), findsOneWidget);
      expect(find.text('Robotics Lab'), findsOneWidget);
      expect(find.text('Kit Checklist'), findsOneWidget);
      expect(find.text('Tablets charged'), findsOneWidget);
      expect(find.text('Safety Notes'), findsOneWidget);
      expect(find.text('Guardian pickup change confirmed'), findsOneWidget);
      expect(find.text('No recent activity yet'), findsNothing);
    });

    testWidgets(
        'site ops persists checklist toggles and safety notes for the active site',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedSiteOpsData(firestore);

      await _pumpSiteOpsPage(tester, firestore: firestore);

      await tester.tap(find.text('Tablets charged'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Learner allergy reminder shared with Coach Ada',
      );
      await tester.scrollUntilVisible(
        find.text('Save Safety Note'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save Safety Note'));
      await tester.pumpAndSettle();

      final DocumentSnapshot<Map<String, dynamic>> checklistDoc =
          await firestore
              .collection('siteOpsKitChecklist')
              .doc('arrival-tablets')
              .get();
      expect(checklistDoc.exists, isTrue);
      expect(checklistDoc.data()!['completed'], isTrue);

      final QuerySnapshot<Map<String, dynamic>> notes = await firestore
          .collection('siteSafetyNotes')
          .where('siteId', isEqualTo: 'site-1')
          .where(
            'note',
            isEqualTo: 'Learner allergy reminder shared with Coach Ada',
          )
          .get();
      expect(notes.docs, isNotEmpty);
      expect(
        find.text('Learner allergy reminder shared with Coach Ada'),
        findsOneWidget,
      );
    });

    testWidgets('site ops day status toggle persists for the active site',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedSiteOpsData(firestore);

      await _pumpSiteOpsPage(tester, firestore: firestore);

      expect(find.text('Site is OPEN'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final DateTime now = DateTime.now();
      final String dayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final DocumentSnapshot<Map<String, dynamic>> statusDoc = await firestore
          .collection('siteOpsDailyStatus')
          .doc('site-1-$dayKey')
          .get();
      expect(statusDoc.exists, isTrue);
      expect(statusDoc.data()!['isOpen'], isFalse);
      expect(find.text('Site is CLOSED'), findsOneWidget);
    });

    testWidgets(
        'site ops shows federated runtime rollout state for the active site',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await _seedSiteOpsData(firestore);
      final _FakeWorkflowBridgeService workflowBridgeService =
          _FakeWorkflowBridgeService(
        runtimeDeliveries: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'fl_delivery_site_1',
            'targetSiteIds': <String>['site-1'],
            'status': 'active',
            'runtimeTarget': 'flutter_mobile',
            'candidateModelPackageId': 'fl_pkg_1',
            'manifestDigest': 'sha256:delivery-1',
            'updatedAt': DateTime(2026, 3, 16, 8).millisecondsSinceEpoch,
          },
          <String, dynamic>{
            'id': 'fl_delivery_site_2',
            'targetSiteIds': <String>['site-2'],
            'status': 'active',
            'runtimeTarget': 'flutter_mobile',
            'candidateModelPackageId': 'fl_pkg_2',
            'manifestDigest': 'sha256:delivery-2',
            'updatedAt': DateTime(2026, 3, 16, 7).millisecondsSinceEpoch,
          },
          <String, dynamic>{
            'id': 'fl_delivery_site_0',
            'targetSiteIds': <String>['site-1'],
            'status': 'revoked',
            'runtimeTarget': 'flutter_mobile',
            'candidateModelPackageId': 'fl_pkg_old',
            'manifestDigest': 'sha256:delivery-0',
            'updatedAt': DateTime(2026, 3, 16, 6).millisecondsSinceEpoch,
            'terminalLifecycleStatus': 'revoked',
            'revocationReason': 'Revoked after bounded regression review.',
            'rolloutControlMode': 'paused',
            'rolloutControlReason': 'Paused pending bounded verification.',
          },
        ],
        runtimeActivations: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'fl_activation_site_1',
            'deliveryRecordId': 'fl_delivery_site_1',
            'siteId': 'site-1',
            'status': 'fallback',
            'runtimeTarget': 'flutter_mobile',
            'notes': 'Latest site report requested fallback.',
            'updatedAt': DateTime(2026, 3, 16, 9).millisecondsSinceEpoch,
          },
        ],
        resolvedRuntimePackage: <String, dynamic>{
          'packageId': 'fl_pkg_1',
          'deliveryRecordId': 'fl_delivery_site_1',
          'experimentId': 'fl_exp_literacy',
          'candidateModelPackageId': 'fl_pkg_1',
          'siteId': 'site-1',
          'runtimeTarget': 'flutter_mobile',
          'packageDigest': 'sha256:pkg-1',
          'manifestDigest': 'sha256:delivery-1',
          'resolutionStatus': 'paused',
          'modelVersion': 'fl_runtime_model_v1',
          'runtimeVectorLength': 8,
          'runtimeVector': <double>[],
          'runtimeVectorDigest': 'sha256:vector-1',
          'rolloutStatus': 'active',
          'rolloutControlMode': 'paused',
          'rolloutControlReason': 'Paused pending bounded verification.',
        },
      );

      await _pumpSiteOpsPage(
        tester,
        firestore: firestore,
        workflowBridgeService: workflowBridgeService,
      );

      expect(find.text('Federated Runtime'), findsOneWidget);
      expect(find.textContaining('Current package: fl_pkg_1 · paused'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Site rollout: 0 resolved · 0 staged · 1 fallback · 0 pending'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Latest site report: fallback · Latest site report requested fallback.'),
          findsOneWidget);
      expect(find.text('Recent runtime history'), findsOneWidget);
      expect(
          find.textContaining('fl_delivery_site_0 · revoked · flutter_mobile'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Lifecycle reason: Revoked after bounded regression review.'),
          findsOneWidget);
    });

    testWidgets(
        'provisioning delete confirmation renders zh-CN guardian link copy',
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

    testWidgets(
        'provisioning delete confirmation renders zh-TW guardian link copy',
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

    testWidgets(
        'provisioning deletes active-site guardian links and updates the UI',
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
      expect(
          (await firestore.collection('guardianLinks').doc('link-1').get())
              .exists,
          isFalse);
      expect(
          (await firestore.collection('guardianLinks').doc('link-2').get())
              .exists,
          isTrue);
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
      await tester.enterText(
          find.byType(TextFormField).at(1), 'ava@example.com');
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
      await tester.enterText(
          find.byType(TextFormField).at(1), 'mina.parent@example.com');
      await tester.enterText(
          find.byType(TextFormField).at(2), '+61 400 555 121');
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

    testWidgets(
        'provisioning creates a guardian link from the create link dialog',
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

      await tester.enterText(
          find.byType(TextFormField).at(0), 'Launch Cohort Alpha');
      await tester.enterText(find.byType(TextFormField).at(3), '24');
      await tester.enterText(
          find.byType(TextFormField).at(4), 'Parent kickoff scheduled.');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Cohort launch created successfully'), findsOneWidget);
      expect(find.text('Launch Cohort Alpha'), findsOneWidget);
      expect(find.text('Learner Count: 24'), findsOneWidget);
      expect(find.text('Parent kickoff scheduled.'), findsOneWidget);
    });

    testWidgets(
        'provisioning cohort dialog localizes labels and cohort cards show honest unavailable fallbacks',
        (WidgetTester tester) async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final _FakeWorkflowBridgeService workflowBridgeService =
          _FakeWorkflowBridgeService(
        launches: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'launch-honesty-1',
            'siteId': 'site-1',
            'cohortName': 'Launch Cohort Beta',
            'scheduleLabel': 'TBD',
            'curriculumTerm': '',
            'ageBand': '',
            'status': '',
            'rosterStatus': '',
            'parentCommunicationStatus': '',
            'baselineSurveyStatus': '',
            'kickoffStatus': '',
            'updatedAt': DateTime(2026, 3, 17, 12).toIso8601String(),
          },
        ],
      );

      await _pumpProvisioningPage(
        tester,
        firestore: firestore,
        locale: const Locale('zh', 'CN'),
        workflowBridgeService: workflowBridgeService,
      );

      await tester.tap(find.text('群组'));
      await tester.pumpAndSettle();

      expect(find.text('Launch Cohort Beta'), findsOneWidget);
      expect(find.text('日程不可用 • 课程周期不可用'), findsOneWidget);
      expect(find.text('学习者数量: 不可用'), findsOneWidget);
      expect(find.text('TBD'), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('创建群组启动'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
    });
  });
}
