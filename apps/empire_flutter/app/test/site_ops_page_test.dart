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

void main() {
  testWidgets('site ops page shows unavailable runtime copy on load failure',
      (WidgetTester tester) async {
    final _SequencedRuntimeWorkflowBridgeService workflowBridge =
        _SequencedRuntimeWorkflowBridgeService(
      snapshots: <_RuntimeLoadSnapshot>[
        _RuntimeLoadSnapshot(error: StateError('runtime rollout unavailable')),
      ],
    );

    await _pumpPage(
      tester,
      firestore: FakeFirebaseFirestore(),
      workflowBridge: workflowBridge,
    );

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.text('Runtime rollout details are unavailable right now'), findsOneWidget);
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
  });
}