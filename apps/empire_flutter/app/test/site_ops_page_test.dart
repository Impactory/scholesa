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
import 'package:scholesa_app/modules/site/site_ops_page.dart';
import 'package:scholesa_app/services/firestore_service.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _RuntimeLoadSnapshot {
  const _RuntimeLoadSnapshot({
    this.deliveries = const <Map<String, dynamic>>[],
    this.history = const <Map<String, dynamic>>[],
    this.activations = const <Map<String, dynamic>>[],
    this.resolvedRuntimePackage,
    this.error,
  });

  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> activations;
  final Map<String, dynamic>? resolvedRuntimePackage;
  final Object? error;
}

class _SequencedRuntimeWorkflowBridgeService extends WorkflowBridgeService {
  _SequencedRuntimeWorkflowBridgeService({required List<_RuntimeLoadSnapshot> snapshots})
      : _snapshots = snapshots,
        super(functions: null);

  final List<_RuntimeLoadSnapshot> _snapshots;
  int _deliveryCalls = 0;
  int _historyCalls = 0;
  int _activationCalls = 0;
  int _packageCalls = 0;

  _RuntimeLoadSnapshot _snapshotFor(int callIndex) {
    if (_snapshots.isEmpty) {
      return const _RuntimeLoadSnapshot();
    }
    final int resolvedIndex = callIndex < _snapshots.length ? callIndex : _snapshots.length - 1;
    return _snapshots[resolvedIndex];
  }

  List<Map<String, dynamic>> _copyRows(List<Map<String, dynamic>> rows) {
    return rows.map((Map<String, dynamic> row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> listSiteFederatedLearningRuntimeDeliveryRecords({String? siteId, int limit = 40}) async {
    final _RuntimeLoadSnapshot snapshot = _snapshotFor(_deliveryCalls++);
    if (snapshot.error != null) throw snapshot.error!;
    return _copyRows(snapshot.deliveries);
  }

  @override
  Future<List<Map<String, dynamic>>> listSiteFederatedLearningRuntimeDeliveryHistoryRecords({String? siteId, int limit = 20}) async {
    final _RuntimeLoadSnapshot snapshot = _snapshotFor(_historyCalls++);
    if (snapshot.error != null) throw snapshot.error!;
    return _copyRows(snapshot.history);
  }

  @override
  Future<List<Map<String, dynamic>>> listSiteFederatedLearningRuntimeActivationRecords({String? siteId, int limit = 40}) async {
    final _RuntimeLoadSnapshot snapshot = _snapshotFor(_activationCalls++);
    if (snapshot.error != null) throw snapshot.error!;
    return _copyRows(snapshot.activations);
  }

  @override
  Future<Map<String, dynamic>?> resolveSiteFederatedLearningRuntimePackage({String? siteId, String? experimentId, String? runtimeTarget, String? deliveryRecordId}) async {
    final _RuntimeLoadSnapshot snapshot = _snapshotFor(_packageCalls++);
    if (snapshot.error != null) throw snapshot.error!;
    final Map<String, dynamic>? row = snapshot.resolvedRuntimePackage;
    return row == null ? null : Map<String, dynamic>.from(row);
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

Map<String, dynamic> _runtimeDeliveryRow() {
  return <String, dynamic>{
    'id': 'fl_delivery_1',
    'experimentId': 'fl_exp_1',
    'runtimeTarget': 'flutter_mobile',
    'status': 'active',
    'packageDigest': 'sha256:pkg-1',
    'boundedDigest': 'sha256:digest-1',
    'manifestDigest': 'sha256:manifest-1',
    'rolloutControlMode': 'monitor',
    'assignedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9)),
  };
}

Map<String, dynamic> _runtimeActivationRow() {
  return <String, dynamic>{
    'id': 'activation-1',
    'deliveryRecordId': 'fl_delivery_1',
    'experimentId': 'fl_exp_1',
    'siteId': 'site-1',
    'runtimeTarget': 'flutter_mobile',
    'packageDigest': 'sha256:pkg-1',
    'boundedDigest': 'sha256:digest-1',
    'manifestDigest': 'sha256:manifest-1',
    'status': 'resolved',
    'notes': 'Latest site report requested fallback.',
    'reportedAt': Timestamp.fromDate(DateTime(2026, 3, 17, 9, 5)),
  };
}

Future<void> _pumpPage(WidgetTester tester, {required FakeFirebaseFirestore firestore, required WorkflowBridgeService workflowBridge}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 2200));
  final FirestoreService firestoreService = FirestoreService(
    firestore: firestore,
    auth: _MockFirebaseAuth(),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: _buildSiteState()),
        Provider<FirestoreService>.value(value: firestoreService),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN'), Locale('zh', 'TW')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SiteOpsPage(workflowBridge: workflowBridge),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _seedSiteOpsWorkflowData(FakeFirebaseFirestore firestore) async {
  final DateTime now = DateTime.now();
  final DateTime dayStart = DateTime(now.year, now.month, now.day);

  await firestore.collection('learners').doc('learner-a').set(<String, dynamic>{
    'siteId': 'site-1',
    'displayName': 'Ava Stone',
  });
  await firestore.collection('learners').doc('learner-b').set(<String, dynamic>{
    'siteId': 'site-1',
    'displayName': 'Ben Lake',
  });
  await firestore.collection('learners').doc('learner-c').set(<String, dynamic>{
    'siteId': 'site-1',
    'displayName': 'Cora Vale',
  });
  await firestore.collection('learners').doc('learner-z').set(<String, dynamic>{
    'siteId': 'site-2',
    'displayName': 'Other Site Learner',
  });

  await firestore.collection('enrollments').doc('enrollment-a').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-a',
    'sessionId': 'session-site-1',
  });
  await firestore.collection('enrollments').doc('enrollment-b').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-b',
    'sessionId': 'session-site-1',
  });
  await firestore.collection('enrollments').doc('enrollment-c').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-c',
    'sessionId': 'session-site-1',
  });

  await firestore.collection('sessions').doc('session-site-1').set(<String, dynamic>{
    'siteId': 'site-1',
    'title': 'Robotics Studio',
    'startTime': Timestamp.fromDate(dayStart.add(const Duration(hours: 10))),
    'educatorName': 'Coach Ada',
    'room': 'Lab 1',
    'learnerCount': 3,
  });
  await firestore.collection('sessions').doc('session-site-1-later').set(<String, dynamic>{
    'siteId': 'site-1',
    'title': 'Design Lab',
    'startTime': Timestamp.fromDate(dayStart.add(const Duration(hours: 14))),
    'educatorName': 'Coach Lin',
    'room': 'Maker Bay',
    'learnerCount': 2,
  });
  await firestore.collection('sessions').doc('session-site-2').set(<String, dynamic>{
    'siteId': 'site-2',
    'title': 'Other Site Session',
    'startTime': Timestamp.fromDate(dayStart.add(const Duration(hours: 11))),
    'educatorName': 'Coach Elsewhere',
    'room': 'Remote Room',
    'learnerCount': 99,
  });

  await firestore.collection('checkins').doc('checkin-a').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-a',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 8, minutes: 5))),
  });
  await firestore.collection('checkins').doc('checkin-b').set(<String, dynamic>{
    'siteId': 'site-1',
    'learnerId': 'learner-b',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 8, minutes: 12))),
  });
  await firestore.collection('checkins').doc('checkin-z').set(<String, dynamic>{
    'siteId': 'site-2',
    'learnerId': 'learner-z',
    'type': 'checkin',
    'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 8, minutes: 20))),
  });
}

void main() {
  testWidgets('site ops page composes same-site checkins and today sessions into live ops status',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSiteOpsWorkflowData(firestore);

    await _pumpPage(
      tester,
      firestore: firestore,
      workflowBridge: _SequencedRuntimeWorkflowBridgeService(
        snapshots: const <_RuntimeLoadSnapshot>[ _RuntimeLoadSnapshot() ],
      ),
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Site is OPEN'), findsOneWidget);
    expect(find.text('Robotics Studio'), findsOneWidget);
    expect(find.text('Design Lab'), findsOneWidget);
    expect(find.text('Other Site Session'), findsNothing);
    expect(find.text('3 learners'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);

    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    await firestore.collection('checkins').doc('checkin-c').set(<String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-c',
      'type': 'checkin',
      'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 8, minutes: 35))),
    });

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsWidgets);
    expect(find.text('Present'), findsOneWidget);
  });

  testWidgets('site ops page removes checked-out same-site learners from live present status',
      (WidgetTester tester) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await _seedSiteOpsWorkflowData(firestore);

    await _pumpPage(
      tester,
      firestore: firestore,
      workflowBridge: _SequencedRuntimeWorkflowBridgeService(
        snapshots: const <_RuntimeLoadSnapshot>[_RuntimeLoadSnapshot()],
      ),
    );

    expect(find.text('Site is OPEN'), findsOneWidget);
    expect(find.text('Other Site Session'), findsNothing);

    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    await firestore.collection('checkins').doc('checkout-a').set(<String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-a',
      'type': 'checkout',
      'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 15, minutes: 5))),
    });
    await firestore.collection('checkins').doc('checkout-b').set(<String, dynamic>{
      'siteId': 'site-1',
      'learnerId': 'learner-b',
      'type': 'checkout',
      'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 15, minutes: 10))),
    });
    await firestore.collection('checkins').doc('checkin-z-late').set(<String, dynamic>{
      'siteId': 'site-2',
      'learnerId': 'learner-z',
      'type': 'checkin',
      'timestamp': Timestamp.fromDate(dayStart.add(const Duration(hours: 15, minutes: 12))),
    });

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Site is CLOSED'), findsOneWidget);
    expect(find.text('Toggle switch to open the day'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Other Site Session'), findsNothing);
  });

  testWidgets('site ops page shows unavailable runtime copy and can retry from the same screen',
      (WidgetTester tester) async {
    final _SequencedRuntimeWorkflowBridgeService workflowBridge =
        _SequencedRuntimeWorkflowBridgeService(
      snapshots: <_RuntimeLoadSnapshot>[
        _RuntimeLoadSnapshot(error: StateError('runtime rollout unavailable')),
        _RuntimeLoadSnapshot(
          deliveries: <Map<String, dynamic>>[_runtimeDeliveryRow()],
          history: const <Map<String, dynamic>>[],
          activations: <Map<String, dynamic>>[_runtimeActivationRow()],
          resolvedRuntimePackage: <String, dynamic>{
            'packageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'experimentId': 'fl_exp_1',
            'siteId': 'site-1',
            'runtimeTarget': 'flutter_mobile',
            'packageDigest': 'sha256:pkg-1',
            'manifestDigest': 'sha256:manifest-1',
            'resolutionStatus': 'resolved',
            'modelVersion': 'fl_runtime_model_v1',
            'runtimeVectorLength': 8,
            'runtimeVector': <double>[0.1, 0.2, 0.3, 0.4],
            'runtimeVectorDigest': 'sha256:runtime-digest-1',
            'rolloutStatus': 'distributed',
            'rolloutControlMode': 'monitor',
          },
        ),
      ],
    );

    await _pumpPage(
      tester,
      firestore: FakeFirebaseFirestore(),
      workflowBridge: workflowBridge,
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Runtime rollout details are unavailable right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Runtime rollout details are unavailable right now'), findsNothing);
    expect(find.text('Current package: fl_pkg_1 · resolved'), findsOneWidget);
  });

  testWidgets('site ops page keeps live rollout data visible after refresh failure',
      (WidgetTester tester) async {
    final _SequencedRuntimeWorkflowBridgeService workflowBridge =
        _SequencedRuntimeWorkflowBridgeService(
      snapshots: <_RuntimeLoadSnapshot>[
        _RuntimeLoadSnapshot(
          deliveries: <Map<String, dynamic>>[_runtimeDeliveryRow()],
          history: const <Map<String, dynamic>>[],
          activations: <Map<String, dynamic>>[_runtimeActivationRow()],
          resolvedRuntimePackage: <String, dynamic>{
            'packageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'experimentId': 'fl_exp_1',
            'siteId': 'site-1',
            'runtimeTarget': 'flutter_mobile',
            'packageDigest': 'sha256:pkg-1',
            'manifestDigest': 'sha256:manifest-1',
            'resolutionStatus': 'resolved',
            'modelVersion': 'fl_runtime_model_v1',
            'runtimeVectorLength': 8,
            'runtimeVector': <double>[0.1, 0.2, 0.3, 0.4],
            'runtimeVectorDigest': 'sha256:runtime-digest-1',
            'rolloutStatus': 'distributed',
            'rolloutControlMode': 'monitor',
          },
        ),
        _RuntimeLoadSnapshot(
          history: const <Map<String, dynamic>>[],
          error: StateError('runtime rollout refresh unavailable'),
        ),
      ],
    );

    await _pumpPage(
      tester,
      firestore: FakeFirebaseFirestore(),
      workflowBridge: workflowBridge,
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Current package: fl_pkg_1 · resolved'), findsOneWidget);
    expect(find.text('Site rollout: 1 resolved · 0 staged · 0 fallback · 0 pending'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Guardian pickup updated after runtime refresh issue.',
    );
    await tester.scrollUntilVisible(
      find.text('Save Safety Note'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Safety Note'));
    await tester.pumpAndSettle();

    expect(find.text('Runtime rollout details are partially unavailable right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}