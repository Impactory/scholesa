import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_feature_flags_page.dart';
import 'package:scholesa_app/services/federated_learning_prototype_uploader.dart';
import 'package:scholesa_app/services/federated_learning_runtime_adapter.dart';
import 'package:scholesa_app/services/workflow_bridge_service.dart';
import 'package:scholesa_app/runtime/bos_models.dart';
import 'package:scholesa_app/runtime/learning_runtime_provider.dart';

class _FakeWorkflowBridgeService extends WorkflowBridgeService {
  _FakeWorkflowBridgeService({
    List<Map<String, dynamic>>? flags,
    List<Map<String, dynamic>>? experiments,
    List<Map<String, dynamic>>? siteExperiments,
    List<Map<String, dynamic>>? aggregationRuns,
    List<Map<String, dynamic>>? mergeArtifacts,
  })  : _flags =
            List<Map<String, dynamic>>.from(flags ?? <Map<String, dynamic>>[]),
        _experiments = List<Map<String, dynamic>>.from(
            experiments ?? <Map<String, dynamic>>[]),
        _siteExperiments = List<Map<String, dynamic>>.from(
          siteExperiments ?? experiments ?? <Map<String, dynamic>>[],
        ),
        _aggregationRuns = List<Map<String, dynamic>>.from(
          aggregationRuns ?? <Map<String, dynamic>>[],
        ),
        _mergeArtifacts = List<Map<String, dynamic>>.from(
          mergeArtifacts ?? <Map<String, dynamic>>[],
        ),
        super(functions: null);

  final List<Map<String, dynamic>> _flags;
  final List<Map<String, dynamic>> _experiments;
  final List<Map<String, dynamic>> _siteExperiments;
  final List<Map<String, dynamic>> _aggregationRuns;
  final List<Map<String, dynamic>> _mergeArtifacts;
  final List<Map<String, dynamic>> recordedUpdates = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listFeatureFlags({int limit = 300}) async {
    return _flags
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<String?> upsertFeatureFlag(Map<String, dynamic> data) async {
    final String id = (data['id'] as String?) ?? 'flag-${_flags.length + 1}';
    final Map<String, dynamic> row = <String, dynamic>{
      'id': id,
      ...data,
    };
    _flags.removeWhere((entry) => entry['id'] == id);
    _flags.insert(0, row);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningExperiments({
    int limit = 120,
  }) async {
    return _experiments
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listSiteFederatedLearningExperiments({
    String? siteId,
    int limit = 40,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (siteId == null || siteId.isEmpty)
            ? _siteExperiments
            : _siteExperiments.where((Map<String, dynamic> row) {
                final List<dynamic> allowedSiteIds =
                    row['allowedSiteIds'] as List<dynamic>? ?? <dynamic>[];
                return allowedSiteIds.contains(siteId);
              });
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<String?> upsertFederatedLearningExperiment(
    Map<String, dynamic> data,
  ) async {
    final String id = (data['id'] as String?) ??
        'fl_exp_${(data['name'] as String? ?? 'prototype').toLowerCase().replaceAll(' ', '_')}';
    final Map<String, dynamic> row = <String, dynamic>{
      'id': id,
      ...data,
      'featureFlagId': 'feature_$id',
    };
    _experiments.removeWhere((entry) => entry['id'] == id);
    _experiments.insert(0, row);
    _siteExperiments.removeWhere((entry) => entry['id'] == id);
    _siteExperiments.insert(0, row);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningAggregationRuns({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (experimentId == null || experimentId.isEmpty)
            ? _aggregationRuns
            : _aggregationRuns.where(
                (Map<String, dynamic> row) => row['experimentId'] == experimentId,
              );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningMergeArtifacts({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (experimentId == null || experimentId.isEmpty)
            ? _mergeArtifacts
            : _mergeArtifacts.where(
                (Map<String, dynamic> row) => row['experimentId'] == experimentId,
              );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<String?> recordFederatedLearningPrototypeUpdate(
    Map<String, dynamic> data,
  ) async {
    final String id = 'update-${recordedUpdates.length + 1}';
    recordedUpdates.add(<String, dynamic>{'id': id, ...data});
    return id;
  }
}

Map<String, dynamic> _aggregationRunRow({
  String id = 'fl_agg_1',
  String experimentId = 'fl_exp_literacy_pilot',
  int totalSampleCount = 24,
  int summaryCount = 2,
  int distinctSiteCount = 2,
  String mergeArtifactId = 'fl_merge_1',
  String boundedDigest = 'sha256:digest-1',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'status': 'materialized',
    'threshold': 20,
    'thresholdMet': true,
    'mergeArtifactId': mergeArtifactId,
    'mergeArtifactStatus': 'generated',
    'mergeStrategy': 'prototype_weighted_metadata_digest',
    'boundedDigest': boundedDigest,
    'triggerSummaryId': 'update-2',
    'summaryIds': <String>['update-1', 'update-2'],
    'summaryCount': summaryCount,
    'distinctSiteCount': distinctSiteCount,
    'totalSampleCount': totalSampleCount,
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
    'schemaVersions': <String>['v1'],
    'runtimeTargets': <String>['flutter_mobile'],
  };
}

Map<String, dynamic> _mergeArtifactRow({
  String id = 'fl_merge_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String aggregationRunId = 'fl_agg_1',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'aggregationRunId': aggregationRunId,
    'status': 'generated',
    'mergeStrategy': 'prototype_weighted_metadata_digest',
    'boundedDigest': 'sha256:digest-1',
    'sampleCount': 24,
    'summaryCount': 2,
    'distinctSiteCount': 2,
    'schemaVersions': <String>['v1'],
    'runtimeTargets': <String>['flutter_mobile'],
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
  };
}

AppState _buildSiteState() {
  final AppState state = AppState();
  state.updateFromMeResponse(<String, dynamic>{
    'userId': 'site-admin-1',
    'email': 'site-admin-1@scholesa.org',
    'displayName': 'Site Admin',
    'role': 'site',
    'activeSiteId': 'site-1',
    'siteIds': <String>['site-1'],
    'localeCode': 'en',
    'entitlements': <dynamic>[],
  });
  return state;
}

Map<String, dynamic> _experimentRow({
  String id = 'fl_exp_literacy_pilot',
  String name = 'Literacy Pilot',
  List<String> allowedSiteIds = const <String>['site-1'],
  String status = 'pilot_ready',
  bool enablePrototypeUploads = true,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Site-scoped literacy cohort',
    'runtimeTarget': 'flutter_mobile',
    'status': status,
    'allowedSiteIds': allowedSiteIds,
    'aggregateThreshold': 25,
    'rawUpdateMaxBytes': 16384,
    'enablePrototypeUploads': enablePrototypeUploads,
    'featureFlagId': 'feature_$id',
    'featureFlag': <String, dynamic>{
      'id': 'feature_$id',
      'enabled': true,
      'scope': 'site',
      'enabledSites': allowedSiteIds,
      'status': 'enabled',
    },
  };
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
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
  );
}

void main() {
  setUp(() {
    FederatedLearningRuntimeAdapter.instance.resetForTesting();
  });

  test('repositories list federated experiments and summaries by site',
      () async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore
        .collection('federatedLearningExperiments')
        .doc('fl_exp_literacy_pilot')
        .set(<String, dynamic>{
      'name': 'Literacy Pilot',
      'runtimeTarget': 'flutter_mobile',
      'status': 'pilot_ready',
      'allowedSiteIds': <String>['site-1'],
      'aggregateThreshold': 25,
      'rawUpdateMaxBytes': 16384,
      'enablePrototypeUploads': true,
      'updatedAt': DateTime.now(),
    });
    await firestore
      .collection('federatedLearningAggregationRuns')
      .doc('fl_agg_1')
      .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'status': 'materialized',
      'threshold': 20,
      'thresholdMet': true,
      'mergeArtifactId': 'fl_merge_1',
      'mergeArtifactStatus': 'generated',
      'mergeStrategy': 'prototype_weighted_metadata_digest',
      'boundedDigest': 'sha256:digest-1',
      'triggerSummaryId': 'update-1',
      'summaryIds': <String>['update-1'],
      'summaryCount': 1,
      'distinctSiteCount': 1,
      'totalSampleCount': 14,
      'maxVectorLength': 128,
      'totalPayloadBytes': 1024,
      'averageUpdateNorm': 2.4,
      'schemaVersions': <String>['v1'],
      'runtimeTargets': <String>['flutter_mobile'],
      'createdAt': DateTime.now(),
    });
    await firestore
      .collection('federatedLearningMergeArtifacts')
      .doc('fl_merge_1')
      .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'aggregationRunId': 'fl_agg_1',
      'status': 'generated',
      'mergeStrategy': 'prototype_weighted_metadata_digest',
      'boundedDigest': 'sha256:digest-1',
      'sampleCount': 14,
      'summaryCount': 1,
      'distinctSiteCount': 1,
      'schemaVersions': <String>['v1'],
      'runtimeTargets': <String>['flutter_mobile'],
      'maxVectorLength': 128,
      'totalPayloadBytes': 1024,
      'averageUpdateNorm': 2.4,
      'createdAt': DateTime.now(),
    });

    final FederatedLearningAggregationRunRepository aggregationRepository =
      FederatedLearningAggregationRunRepository(firestore: firestore);
    final FederatedLearningMergeArtifactRepository artifactRepository =
      FederatedLearningMergeArtifactRepository(firestore: firestore);
    final List<FederatedLearningAggregationRunModel> aggregationRuns =
      await aggregationRepository.listByExperiment('fl_exp_literacy_pilot');
    final List<FederatedLearningMergeArtifactModel> mergeArtifacts =
      await artifactRepository.listByExperiment('fl_exp_literacy_pilot');

    expect(aggregationRuns, hasLength(1));
    expect(aggregationRuns.single.totalSampleCount, 14);
    expect(aggregationRuns.single.mergeArtifactStatus, 'generated');
    expect(mergeArtifacts, hasLength(1));
    expect(mergeArtifacts.single.aggregationRunId, 'fl_agg_1');

    await firestore
        .collection('federatedLearningUpdateSummaries')
        .doc('update-1')
        .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'siteId': 'site-1',
      'traceId': 'trace-1',
      'schemaVersion': 'v1',
      'sampleCount': 14,
      'vectorLength': 128,
      'payloadBytes': 1024,
      'updateNorm': 2.4,
      'payloadDigest': 'digest-1',
      'batteryState': 'charging',
      'networkType': 'wifi',
      'createdAt': DateTime.now(),
    });

    final FederatedLearningExperimentRepository experimentRepository =
        FederatedLearningExperimentRepository(firestore: firestore);
    final FederatedLearningUpdateSummaryRepository summaryRepository =
        FederatedLearningUpdateSummaryRepository(firestore: firestore);

    final List<FederatedLearningExperimentModel> experiments =
        await experimentRepository.listBySite('site-1');
    final List<FederatedLearningUpdateSummaryModel> summaries =
        await summaryRepository.listBySite('site-1');

    expect(experiments, hasLength(1));
    expect(experiments.single.name, 'Literacy Pilot');
    expect(summaries, hasLength(1));
    expect(summaries.single.traceId, 'trace-1');
  });

  test('uploader resolves assignments and records bounded summaries', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[_experimentRow(status: 'active')],
    );
    final FederatedLearningPrototypeUploader uploader =
        FederatedLearningPrototypeUploader(
      appState: _buildSiteState(),
      workflowBridge: bridge,
    );

    final List<FederatedLearningExperimentModel> assignments =
        await uploader.listAssignments();
    expect(assignments, hasLength(1));

    final String? updateId = await uploader.uploadSummary(
      experiment: assignments.single,
      traceId: 'trace-42',
      schemaVersion: 'v1',
      sampleCount: 12,
      vectorLength: 96,
      payloadBytes: 768,
      updateNorm: 1.7,
      payloadDigest: 'digest-42',
      batteryState: 'charging',
      networkType: 'wifi',
    );

    expect(updateId, 'update-1');
    expect(bridge.recordedUpdates, hasLength(1));
    expect(bridge.recordedUpdates.single['siteId'], 'site-1');
    expect(
        bridge.recordedUpdates.single['experimentId'], 'fl_exp_literacy_pilot');
  });

  test('runtime adapter uploads bounded BOS summaries on real triggers',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[_experimentRow(status: 'active')],
    );
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final AppState appState = _buildSiteState();
    FederatedLearningRuntimeAdapter.instance.configure(
      appState: appState,
      workflowBridge: bridge,
    );

    final LearningRuntimeProvider runtime = LearningRuntimeProvider(
      siteId: 'site-1',
      learnerId: 'learner-1',
      sessionOccurrenceId: 'occ-1',
      gradeBand: GradeBand.g4_6,
      firestore: firestore,
    );
    addTearDown(runtime.dispose);

    runtime.trackEvent(
      'mission_started',
      missionId: 'mission-1',
      payload: <String, dynamic>{'source': 'test'},
    );
    runtime.trackEvent(
      'checkpoint_submitted',
      missionId: 'mission-1',
      checkpointId: 'checkpoint-1',
      payload: <String, dynamic>{'attempt': 1, 'confidence': 0.8},
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(bridge.recordedUpdates, hasLength(1));
    expect(bridge.recordedUpdates.single['siteId'], 'site-1');
    expect(
        bridge.recordedUpdates.single['experimentId'], 'fl_exp_literacy_pilot');
    expect(bridge.recordedUpdates.single['sampleCount'], 2);
    expect(
        bridge.recordedUpdates.single['schemaVersion'], 'fl-prototype-bos-v1');
  });

  testWidgets('HQ page renders experiment section and saves a new cohort',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      flags: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'feature_demo',
          'name': 'feature_demo',
          'description': 'Demo flag',
          'enabled': true,
          'scope': 'site',
          'enabledSites': <String>['site-1'],
        },
      ],
      experiments: <Map<String, dynamic>>[_experimentRow()],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
        _aggregationRunRow(
          id: 'fl_agg_2',
          totalSampleCount: 20,
          summaryCount: 2,
          distinctSiteCount: 1,
          mergeArtifactId: 'fl_merge_2',
          boundedDigest: 'sha256:digest-2',
        ),
        _aggregationRunRow(
          id: 'fl_agg_3',
          totalSampleCount: 18,
          summaryCount: 1,
          distinctSiteCount: 1,
          mergeArtifactId: 'fl_merge_3',
          boundedDigest: 'sha256:digest-3',
        ),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
        _mergeArtifactRow(
          id: 'fl_merge_2',
          aggregationRunId: 'fl_agg_2',
        ),
        _mergeArtifactRow(
          id: 'fl_merge_3',
          aggregationRunId: 'fl_agg_3',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Federated learning experiments'), findsOneWidget);
    expect(find.text('Literacy Pilot'), findsOneWidget);
    expect(
      find.text(
        'Latest aggregation: 24 samples from 2 summaries across 2 sites.',
      ),
      findsOneWidget,
    );
    expect(find.text('Recent aggregation runs'), findsOneWidget);
    expect(
      find.text('Artifact generated: fl_merge_1'),
      findsWidgets,
    );

    await tester.tap(find.text('View history').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Aggregation history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        TextField,
        'Filter by run ID, artifact ID, or digest',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Strategy: prototype_weighted_metadata_digest'),
      findsWidgets,
    );
    expect(find.text('Digest: sha256:digest-1'), findsWidgets);
    expect(find.text('Artifact: fl_merge_1'), findsWidgets);
    expect(find.text('Showing 1-2 of 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Run fl_agg_3'), findsOneWidget);
    expect(find.text('Showing 3-3 of 3'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Filter by run ID, artifact ID, or digest'),
      'digest-2',
    );
    await tester.pumpAndSettle();
    expect(find.text('Digest: sha256:digest-2'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create experiment'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Experiment name'),
      'Math Pilot',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Math prototype cohort',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enabled site IDs'),
      'site-1, site-2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Aggregate threshold'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Raw update max bytes'),
      '8192',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Math Pilot'), findsOneWidget);
    expect(
      bridge._experiments
          .any((Map<String, dynamic> row) => row['name'] == 'Math Pilot'),
      isTrue,
    );
  });
}
