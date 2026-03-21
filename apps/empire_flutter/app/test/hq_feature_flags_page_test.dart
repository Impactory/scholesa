import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_feature_flags_page.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/ui/theme/scholesa_theme.dart';

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({
    List<Map<String, dynamic>>? flags,
    List<Map<String, dynamic>>? experiments,
    List<Map<String, dynamic>>? aggregationRuns,
    List<Map<String, dynamic>>? candidatePackages,
    List<Map<String, dynamic>>? runtimeDeliveries,
    List<Map<String, dynamic>>? runtimeActivations,
    List<Map<String, dynamic>>? runtimeRolloutEscalations,
    List<Map<String, dynamic>>? runtimeRolloutControls,
    this.failOnUpsertFeatureFlag = false,
    this.failOnUpsertRolloutEscalation = false,
    this.failOnUpsertRolloutControl = false,
    this.failFeatureFlagsOnCall,
    this.failExperimentsOnCall,
  }) : _flags =
            List<Map<String, dynamic>>.from(flags ?? <Map<String, dynamic>>[]),
       _aggregationRuns = List<Map<String, dynamic>>.from(
         aggregationRuns ?? <Map<String, dynamic>>[],
       ),
       _candidatePackages = List<Map<String, dynamic>>.from(
         candidatePackages ?? <Map<String, dynamic>>[],
       ),
       _runtimeDeliveries = List<Map<String, dynamic>>.from(
         runtimeDeliveries ?? <Map<String, dynamic>>[],
       ),
       _runtimeActivations = List<Map<String, dynamic>>.from(
         runtimeActivations ?? <Map<String, dynamic>>[],
       ),
       _runtimeRolloutEscalations = List<Map<String, dynamic>>.from(
         runtimeRolloutEscalations ?? <Map<String, dynamic>>[],
       ),
       _runtimeRolloutControls = List<Map<String, dynamic>>.from(
         runtimeRolloutControls ?? <Map<String, dynamic>>[],
       ),
       _experiments = List<Map<String, dynamic>>.from(
         experiments ?? <Map<String, dynamic>>[],
       );

  final List<Map<String, dynamic>> _flags;
  final List<Map<String, dynamic>> _aggregationRuns;
  final List<Map<String, dynamic>> _candidatePackages;
  final List<Map<String, dynamic>> _experiments;
  final List<Map<String, dynamic>> _runtimeActivations;
  final List<Map<String, dynamic>> _runtimeDeliveries;
  final List<Map<String, dynamic>> _runtimeRolloutEscalations;
  final List<Map<String, dynamic>> _runtimeRolloutControls;
  final bool failOnUpsertFeatureFlag;
  final bool failOnUpsertRolloutEscalation;
  final bool failOnUpsertRolloutControl;
  final int? failFeatureFlagsOnCall;
  final int? failExperimentsOnCall;
  final List<Map<String, dynamic>> recordedFlagUpdates =
      <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> recordedRolloutEscalationUpdates =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRolloutControlUpdates =
      <Map<String, dynamic>>[];
  int featureFlagsLoadCount = 0;
  int experimentsLoadCount = 0;

  @override
  Future<List<Map<String, dynamic>>> listFeatureFlags({int limit = 300}) async {
    featureFlagsLoadCount += 1;
    if (failFeatureFlagsOnCall == featureFlagsLoadCount) {
      throw Exception('feature flags load failed');
    }
    return _flags
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningExperiments({
    int limit = 120,
  }) async {
    experimentsLoadCount += 1;
    if (failExperimentsOnCall == experimentsLoadCount) {
      throw Exception('experiments load failed');
    }
    return _experiments
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningExperimentReviewRecords({
    String? experimentId,
    int limit = 120,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningAggregationRuns({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> rows = experimentId == null
        ? _aggregationRuns
        : _aggregationRuns.where(
            (Map<String, dynamic> row) => row['experimentId'] == experimentId,
          );
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningMergeArtifacts({
    String? experimentId,
    int limit = 60,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidateModelPackages({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> rows = experimentId == null
        ? _candidatePackages
        : _candidatePackages.where(
            (Map<String, dynamic> row) => row['experimentId'] == experimentId,
          );
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningPilotEvidenceRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningPilotApprovalRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningPilotExecutionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeDeliveryRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> rows = _runtimeDeliveries;
    if (experimentId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeActivationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? siteId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> rows = _runtimeActivations;
    if (experimentId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    if (siteId != null) {
      rows = rows.where((Map<String, dynamic> row) => row['siteId'] == siteId);
    }
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutAlertRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutEscalationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> rows = _runtimeRolloutEscalations;
    if (experimentId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    if (deliveryRecordId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (status != null) {
      rows = rows.where((Map<String, dynamic> row) => row['status'] == status);
    }
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutControlRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? mode,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> rows = _runtimeRolloutControls;
    if (experimentId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    if (deliveryRecordId != null) {
      rows = rows.where(
        (Map<String, dynamic> row) => row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (mode != null) {
      rows = rows.where((Map<String, dynamic> row) => row['mode'] == mode);
    }
    return rows
        .take(limit)
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRevocationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async =>
          <Map<String, dynamic>>[];

  @override
  Future<String?> upsertFeatureFlag(Map<String, dynamic> data) async {
    if (failOnUpsertFeatureFlag) {
      throw Exception('feature flag save failed');
    }
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
    recordedFlagUpdates.add(normalized);
    final String id = normalized['id'] as String? ?? 'flag-${_flags.length + 1}';
    final int existingIndex =
        _flags.indexWhere((Map<String, dynamic> row) => row['id'] == id);
    final Map<String, dynamic> persisted = <String, dynamic>{
      ...normalized,
      'id': id,
    };
    if (existingIndex >= 0) {
      _flags[existingIndex] = persisted;
    } else {
      _flags.add(persisted);
    }
    return id;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeRolloutControlRecord(
    Map<String, dynamic> data,
  ) async {
    if (failOnUpsertRolloutControl) {
      throw Exception('runtime rollout control save failed');
    }
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
    recordedRolloutControlUpdates.add(normalized);
    final String deliveryRecordId =
        normalized['deliveryRecordId'] as String? ?? 'delivery-1';
    final Map<String, dynamic>? delivery = _runtimeDeliveries.cast<Map<String, dynamic>?>().firstWhere(
          (Map<String, dynamic>? row) => row?['id'] == deliveryRecordId,
          orElse: () => null,
        );
    final String id = 'runtime-rollout-control-$deliveryRecordId';
    final Map<String, dynamic> persisted = <String, dynamic>{
      'id': id,
      'deliveryRecordId': deliveryRecordId,
      'experimentId': delivery?['experimentId'] as String? ?? '',
      'candidateModelPackageId':
          delivery?['candidateModelPackageId'] as String? ?? '',
      'runtimeTarget': delivery?['runtimeTarget'] as String? ?? '',
      'targetSiteIds':
          List<String>.from(delivery?['targetSiteIds'] as List? ?? const <String>[]),
      'packageDigest': delivery?['packageDigest'] as String? ?? '',
      'boundedDigest': delivery?['boundedDigest'] as String? ?? '',
      'triggerSummaryId': delivery?['triggerSummaryId'] as String? ?? '',
      'summaryIds':
          List<String>.from(delivery?['summaryIds'] as List? ?? const <String>[]),
      'schemaVersions':
          List<String>.from(delivery?['schemaVersions'] as List? ?? const <String>[]),
      'optimizerStrategies': List<String>.from(
        delivery?['optimizerStrategies'] as List? ?? const <String>[],
      ),
      'compatibilityKey': delivery?['compatibilityKey'] as String? ?? '',
      'warmStartPackageId': delivery?['warmStartPackageId'] as String?,
      'warmStartModelVersion': delivery?['warmStartModelVersion'] as String?,
      'manifestDigest': delivery?['manifestDigest'] as String? ?? '',
      'mode': normalized['mode'] as String? ?? 'monitor',
      'ownerUserId': normalized['ownerUserId'] as String? ?? '',
      'reason': normalized['reason'] as String? ?? '',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 21, 12)),
    };
    final int existingIndex = _runtimeRolloutControls.indexWhere(
      (Map<String, dynamic> row) => row['deliveryRecordId'] == deliveryRecordId,
    );
    if (existingIndex >= 0) {
      _runtimeRolloutControls[existingIndex] = persisted;
    } else {
      _runtimeRolloutControls.add(persisted);
    }
    return id;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeRolloutEscalationRecord(
    Map<String, dynamic> data,
  ) async {
    if (failOnUpsertRolloutEscalation) {
      throw Exception('runtime rollout escalation save failed');
    }
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
    recordedRolloutEscalationUpdates.add(normalized);
    final String deliveryRecordId =
        normalized['deliveryRecordId'] as String? ?? 'delivery-1';
    final Map<String, dynamic>? delivery = _runtimeDeliveries.cast<Map<String, dynamic>?>().firstWhere(
          (Map<String, dynamic>? row) => row?['id'] == deliveryRecordId,
          orElse: () => null,
        );
    final int pendingCount = (delivery?['targetSiteIds'] as List?)?.length ?? 0;
    final String id = 'runtime-rollout-escalation-$deliveryRecordId';
    final Map<String, dynamic> persisted = <String, dynamic>{
      'id': id,
      'deliveryRecordId': deliveryRecordId,
      'experimentId': delivery?['experimentId'] as String? ?? '',
      'candidateModelPackageId':
          delivery?['candidateModelPackageId'] as String? ?? '',
      'runtimeTarget': delivery?['runtimeTarget'] as String? ?? '',
      'targetSiteIds':
          List<String>.from(delivery?['targetSiteIds'] as List? ?? const <String>[]),
      'packageDigest': delivery?['packageDigest'] as String? ?? '',
      'boundedDigest': delivery?['boundedDigest'] as String? ?? '',
      'triggerSummaryId': delivery?['triggerSummaryId'] as String? ?? '',
      'summaryIds':
          List<String>.from(delivery?['summaryIds'] as List? ?? const <String>[]),
      'schemaVersions':
          List<String>.from(delivery?['schemaVersions'] as List? ?? const <String>[]),
      'optimizerStrategies': List<String>.from(
        delivery?['optimizerStrategies'] as List? ?? const <String>[],
      ),
      'compatibilityKey': delivery?['compatibilityKey'] as String? ?? '',
      'warmStartPackageId': delivery?['warmStartPackageId'] as String?,
      'warmStartModelVersion': delivery?['warmStartModelVersion'] as String?,
      'manifestDigest': delivery?['manifestDigest'] as String? ?? '',
      'status': normalized['status'] as String? ?? 'open',
      'fallbackCount': 0,
      'pendingCount': pendingCount,
      'ownerUserId': normalized['ownerUserId'] as String? ?? '',
      'notes': normalized['notes'] as String? ?? '',
      'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 21, 12)),
    };
    final int existingIndex = _runtimeRolloutEscalations.indexWhere(
      (Map<String, dynamic> row) => row['deliveryRecordId'] == deliveryRecordId,
    );
    if (existingIndex >= 0) {
      _runtimeRolloutEscalations[existingIndex] = persisted;
    } else {
      _runtimeRolloutEscalations.add(persisted);
    }
    return id;
  }
}

class _FakeUpdateSummaryRepository
    extends FederatedLearningUpdateSummaryRepository {
  _FakeUpdateSummaryRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<FederatedLearningUpdateSummaryModel>> listByIds(
    List<String> ids,
  ) async =>
      const <FederatedLearningUpdateSummaryModel>[];
}

void main() {
  _FakeWorkflowBridgeService buildRolloutGovernanceHarness({
    bool failOnUpsertRolloutControl = false,
  }) {
    return _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'exp-1',
          'name': 'Prototype Voice Loop',
          'status': 'active',
          'runtimeTarget': 'flutter_mobile',
          'allowedSiteIds': <String>['site-1'],
          'aggregateThreshold': 25,
          'minDistinctSiteCount': 1,
          'rawUpdateMaxBytes': 16384,
          'enablePrototypeUploads': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1, 10)),
        },
      ],
      aggregationRuns: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'run-1',
          'experimentId': 'exp-1',
          'status': 'materialized',
          'summaryIds': <String>['summary-1'],
          'summaryCount': 1,
          'distinctSiteCount': 1,
          'contributingSiteIds': <String>['site-1'],
          'totalSampleCount': 30,
          'threshold': 25,
          'thresholdMet': true,
          'runtimeTargets': <String>['flutter_mobile'],
          'schemaVersions': <String>['v1'],
          'optimizerStrategies': <String>['fedavg'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 2, 10)),
        },
      ],
      candidatePackages: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pkg-1',
          'experimentId': 'exp-1',
          'aggregationRunId': 'run-1',
          'mergeArtifactId': 'artifact-1',
          'status': 'staged',
          'triggerSummaryId': 'summary-1',
          'summaryIds': <String>['summary-1'],
          'packageFormat': 'bundle',
          'rolloutStatus': 'active',
          'modelVersion': 'fl_runtime_model_v1',
          'packageDigest': 'pkg-digest',
          'boundedDigest': 'bounded-digest',
          'runtimeVectorDigest': 'vector-digest',
          'sampleCount': 30,
          'summaryCount': 1,
          'distinctSiteCount': 1,
          'contributingSiteIds': <String>['site-1'],
          'schemaVersions': <String>['v1'],
          'runtimeTargets': <String>['flutter_mobile'],
          'optimizerStrategies': <String>['fedavg'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2, 11)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 2, 11)),
        },
      ],
      runtimeDeliveries: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'delivery-1',
          'experimentId': 'exp-1',
          'candidateModelPackageId': 'pkg-1',
          'aggregationRunId': 'run-1',
          'mergeArtifactId': 'artifact-1',
          'pilotExecutionRecordId': 'pilot-1',
          'runtimeTarget': 'flutter_mobile',
          'targetSiteIds': <String>['site-1'],
          'status': 'active',
          'packageDigest': 'pkg-digest',
          'boundedDigest': 'bounded-digest',
          'triggerSummaryId': 'summary-1',
          'summaryIds': <String>['summary-1'],
          'schemaVersions': <String>['v1'],
          'optimizerStrategies': <String>['fedavg'],
          'manifestDigest': 'manifest-digest',
          'compatibilityKey': 'compat-1',
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 2, 12)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 2, 12)),
        },
      ],
      runtimeActivations: const <Map<String, dynamic>>[],
      runtimeRolloutEscalations: const <Map<String, dynamic>>[],
      runtimeRolloutControls: const <Map<String, dynamic>>[],
      failOnUpsertRolloutEscalation: false,
      failOnUpsertRolloutControl: failOnUpsertRolloutControl,
    );
  }

  Widget buildHarness({
    required _FakeWorkflowBridgeService workflowBridge,
  }) {
    return MaterialApp(
      theme: ScholesaTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      home: HqFeatureFlagsPage(
        workflowBridge: workflowBridge,
        updateSummaryRepository: _FakeUpdateSummaryRepository(),
      ),
    );
  }

  testWidgets('hq feature flags page shows honest empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildHarness(workflowBridge: _FakeWorkflowBridgeService()),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byTooltip('Review change history'), findsOneWidget);
    expect(find.text('Feature Flags'), findsOneWidget);
    expect(find.text('No feature flags found'), findsOneWidget);
    expect(
      find.text('No federated-learning experiments are configured yet.'),
      findsOneWidget,
    );
  });

  testWidgets('hq feature flags page persists a toggle change',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'ai_help_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Account menu'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, hasLength(1));
    expect(workflowBridge.recordedFlagUpdates.single['enabled'], isTrue);
    expect(workflowBridge.recordedFlagUpdates.single['name'], 'ai_help_loop');
    expect(find.text('ai_help_loop enabled'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets(
      'hq feature flags page canonicalizes legacy loop names at the rendered surface',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'miloos_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ai_help_loop'), findsOneWidget);
    expect(find.text('miloos_loop'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, hasLength(1));
    expect(workflowBridge.recordedFlagUpdates.single['name'], 'ai_help_loop');
    expect(find.text('ai_help_loop enabled'), findsOneWidget);
    expect(find.text('miloos_loop enabled'), findsNothing);
  });

  testWidgets(
      'hq feature flags page keeps the prior toggle state when save fails',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'ai_help_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': false,
          'scope': 'global',
        },
      ],
      failOnUpsertFeatureFlag: true,
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedFlagUpdates, isEmpty);
    expect(find.text('Feature flag update failed'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets(
      'hq feature flags page shows explicit unavailable state when flags fail to load',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildHarness(
        workflowBridge: _FakeWorkflowBridgeService(failFeatureFlagsOnCall: 1),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Feature flags are temporarily unavailable'), findsOneWidget);
    expect(
      find.text(
        'We could not load feature flags right now. Retry to check the current state. Details: Exception: feature flags load failed',
      ),
      findsOneWidget,
    );
    expect(find.text('No feature flags found'), findsNothing);
  });

  testWidgets(
      'hq feature flags page retains stale flags after refresh failure',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge = _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'flag-1',
          'name': 'ai_help_loop',
          'description': 'Enable spoken AI help loop runtime',
          'enabled': true,
          'scope': 'global',
        },
      ],
      failFeatureFlagsOnCall: 2,
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ai_help_loop'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh feature flags right now. Showing the last successful data. Details: Exception: feature flags load failed',
      ),
      findsOneWidget,
    );
    expect(find.text('ai_help_loop'), findsOneWidget);
    expect(find.text('No feature flags found'), findsNothing);
  });

  testWidgets(
      'hq feature flags page shows explicit unavailable state when experiments fail to load',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildHarness(
        workflowBridge: _FakeWorkflowBridgeService(failExperimentsOnCall: 1),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Federated-learning experiments are temporarily unavailable'),
      findsOneWidget,
    );
    expect(
      find.text(
        'We could not load federated-learning experiments right now. Retry to check the current state. Details: Exception: experiments load failed',
      ),
      findsOneWidget,
    );
    expect(
      find.text('No federated-learning experiments are configured yet.'),
      findsNothing,
    );
  });

  testWidgets(
      'hq feature flags page retains stale experiments after refresh failure',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'exp-1',
          'name': 'Prototype Voice Loop',
          'status': 'draft',
          'capabilityId': 'future_skills_voice',
          'targetSiteIds': <String>['site-1'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1, 10)),
        },
      ],
      failExperimentsOnCall: 2,
    );

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Prototype Voice Loop'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to refresh federated-learning experiments right now. Showing the last successful data. Details: Exception: experiments load failed',
      ),
      findsOneWidget,
    );
    expect(find.text('Prototype Voice Loop'), findsOneWidget);
    expect(
      find.text('No federated-learning experiments are configured yet.'),
      findsNothing,
    );
  });

  testWidgets(
      'hq feature flags rollout control requires an owner for restricted mode',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        buildRolloutGovernanceHarness();

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    final Finder rolloutControlButton =
      find.widgetWithText(TextButton, 'Rollout control');

    await tester.ensureVisible(rolloutControlButton);
    await tester.pumpAndSettle();

    expect(rolloutControlButton, findsOneWidget);

    await tester.tap(rolloutControlButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('restricted').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Owner user ID is required for restricted or paused control.'),
      findsOneWidget,
    );
    expect(workflowBridge.recordedRolloutControlUpdates, isEmpty);
    expect(workflowBridge.experimentsLoadCount, 1);
  });

  testWidgets(
      'hq feature flags rollout control saves and reloads authoritative data',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        buildRolloutGovernanceHarness();

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(workflowBridge.experimentsLoadCount, 1);
    final Finder rolloutControlButton =
      find.widgetWithText(TextButton, 'Rollout control');

    await tester.ensureVisible(rolloutControlButton);
    await tester.pumpAndSettle();

    expect(rolloutControlButton, findsOneWidget);

    await tester.tap(rolloutControlButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('restricted').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner user ID'),
      'hq-operator-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Control reason'),
      'Fallback pending while HQ reviews bounded rollout health.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedRolloutControlUpdates, hasLength(1));
    expect(
      workflowBridge.recordedRolloutControlUpdates.single['mode'],
      'restricted',
    );
    expect(
      workflowBridge.recordedRolloutControlUpdates.single['ownerUserId'],
      'hq-operator-1',
    );
    expect(workflowBridge.experimentsLoadCount, 2);
    expect(find.text('Rollout control saved'), findsOneWidget);
    expect(find.text('Update control'), findsOneWidget);
  });

  testWidgets(
      'hq feature flags escalation requires an owner while issue remains active',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        buildRolloutGovernanceHarness();

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    final Finder escalateAlertButton =
        find.widgetWithText(TextButton, 'Escalate alert');

    await tester.ensureVisible(escalateAlertButton);
    await tester.pumpAndSettle();

    expect(escalateAlertButton, findsOneWidget);

    await tester.tap(escalateAlertButton);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Owner user ID is required while the rollout issue remains active.',
      ),
      findsOneWidget,
    );
    expect(workflowBridge.recordedRolloutEscalationUpdates, isEmpty);
    expect(workflowBridge.experimentsLoadCount, 1);
  });

  testWidgets(
      'hq feature flags escalation saves and reloads authoritative data',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService workflowBridge =
        buildRolloutGovernanceHarness();

    await tester.pumpWidget(buildHarness(workflowBridge: workflowBridge));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(workflowBridge.experimentsLoadCount, 1);

    final Finder escalateAlertButton =
        find.widgetWithText(TextButton, 'Escalate alert');

    await tester.ensureVisible(escalateAlertButton);
    await tester.pumpAndSettle();

    expect(escalateAlertButton, findsOneWidget);

    await tester.tap(escalateAlertButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner user ID'),
      'hq-escalation-owner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Escalation notes'),
      'Pending rollout requires HQ follow-up before wider activation.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(workflowBridge.recordedRolloutEscalationUpdates, hasLength(1));
    expect(
      workflowBridge.recordedRolloutEscalationUpdates.single['status'],
      'open',
    );
    expect(
      workflowBridge.recordedRolloutEscalationUpdates.single['ownerUserId'],
      'hq-escalation-owner',
    );
    expect(workflowBridge.experimentsLoadCount, 2);
    expect(find.text('Rollout escalation saved'), findsOneWidget);
    expect(find.text('Update escalation'), findsOneWidget);
  });
}
