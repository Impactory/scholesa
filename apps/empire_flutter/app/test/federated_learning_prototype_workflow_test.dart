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
    List<Map<String, dynamic>>? candidatePackages,
    List<Map<String, dynamic>>? promotionRecords,
    List<Map<String, dynamic>>? promotionRevocationRecords,
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
        _candidatePackages = List<Map<String, dynamic>>.from(
          candidatePackages ?? <Map<String, dynamic>>[],
        ),
        _promotionRecords = List<Map<String, dynamic>>.from(
          promotionRecords ?? <Map<String, dynamic>>[],
        ),
        _promotionRevocationRecords = List<Map<String, dynamic>>.from(
          promotionRevocationRecords ?? <Map<String, dynamic>>[],
        ),
        super(functions: null);

  final List<Map<String, dynamic>> _flags;
  final List<Map<String, dynamic>> _experiments;
  final List<Map<String, dynamic>> _siteExperiments;
  final List<Map<String, dynamic>> _aggregationRuns;
  final List<Map<String, dynamic>> _mergeArtifacts;
  final List<Map<String, dynamic>> _candidatePackages;
  final List<Map<String, dynamic>> _promotionRecords;
    final List<Map<String, dynamic>> _promotionRevocationRecords;
  final List<Map<String, dynamic>> recordedUpdates = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedPromotionDecisions =
      <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> recordedPromotionRevocations =
      <Map<String, dynamic>>[];

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
  Future<List<Map<String, dynamic>>> listFederatedLearningCandidateModelPackages({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (experimentId == null || experimentId.isEmpty)
            ? _candidatePackages
            : _candidatePackages.where(
                (Map<String, dynamic> row) => row['experimentId'] == experimentId,
              );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listFederatedLearningCandidatePromotionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _promotionRecords;
    if (experimentId != null && experimentId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null && candidateModelPackageId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRevocationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _promotionRevocationRecords;
    if (experimentId != null && experimentId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['experimentId'] == experimentId,
      );
    }
    if (candidateModelPackageId != null && candidateModelPackageId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['candidateModelPackageId'] == candidateModelPackageId,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<String?> upsertFederatedLearningCandidatePromotionRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final String status = (data['status'] as String? ?? '').trim();
    final String rawTarget = (data['target'] as String? ?? 'sandbox_eval').trim();
    final String target = rawTarget.isEmpty ? 'sandbox_eval' : rawTarget;
    final String rationale = (data['rationale'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String promotionId =
        'fl_prom_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': promotionId,
      'experimentId': packageRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'status': status,
      'target': target,
      'rationale': rationale,
      'decidedBy': 'hq-1',
      'decidedAt': DateTime(2026, 3, 14, 13),
      'createdAt': DateTime(2026, 3, 14, 13),
      'updatedAt': DateTime(2026, 3, 14, 13),
    };
    _promotionRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == promotionId,
    );
    _promotionRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestPromotionRecordId': promotionId,
        'latestPromotionStatus': status,
        'latestPromotionRevocationRecordId': '',
      };
    }
    _promotionRevocationRecords.removeWhere(
      (Map<String, dynamic> row) => row['candidateModelPackageId'] == packageId,
    );
    recordedPromotionDecisions.add(<String, dynamic>{...record});
    return promotionId;
  }

  @override
  Future<String?> revokeFederatedLearningCandidatePromotionRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final Map<String, dynamic> promotionRow = _promotionRecords.firstWhere(
      (Map<String, dynamic> row) => row['candidateModelPackageId'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String revocationId =
        'fl_prom_revoke_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': revocationId,
      'experimentId': promotionRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'candidatePromotionRecordId': promotionRow['id'] ?? '',
      'aggregationRunId': promotionRow['aggregationRunId'] ?? '',
      'mergeArtifactId': promotionRow['mergeArtifactId'] ?? '',
      'revokedStatus': promotionRow['status'] ?? '',
      'target': promotionRow['target'] ?? 'sandbox_eval',
      'rationale': (data['rationale'] as String? ?? '').trim(),
      'revokedBy': 'hq-1',
      'revokedAt': DateTime(2026, 3, 14, 14),
      'createdAt': DateTime(2026, 3, 14, 14),
      'updatedAt': DateTime(2026, 3, 14, 14),
    };
    _promotionRevocationRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == revocationId,
    );
    _promotionRevocationRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestPromotionStatus': 'revoked',
        'latestPromotionRevocationRecordId': revocationId,
      };
    }
    recordedPromotionRevocations.add(<String, dynamic>{...record});
    return revocationId;
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
  DateTime? createdAt,
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'status': 'materialized',
    'threshold': 20,
    'thresholdMet': true,
    'mergeArtifactId': mergeArtifactId,
    'mergeArtifactStatus': 'generated',
    'candidateModelPackageId': mergeArtifactId.isEmpty
      ? ''
      : mergeArtifactId.replaceFirst('fl_merge_', 'fl_pkg_'),
    'candidateModelPackageStatus': mergeArtifactId.isEmpty ? '' : 'staged',
    'candidateModelPackageFormat':
      mergeArtifactId.isEmpty ? '' : 'bounded_metadata_manifest',
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
    'createdAt': createdAt ?? DateTime(2026, 3, 14, 12),
  };
}

Map<String, dynamic> _candidatePackageRow({
  String id = 'fl_pkg_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String boundedDigest = 'sha256:digest-1',
  int sampleCount = 24,
  int summaryCount = 2,
  int distinctSiteCount = 2,
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'status': 'staged',
    'packageFormat': 'bounded_metadata_manifest',
    'rolloutStatus': 'not_distributed',
    'latestPromotionRecordId': '',
    'latestPromotionStatus': '',
    'latestPromotionRevocationRecordId': '',
    'packageDigest': 'sha256:pkg-${id.replaceAll('fl_pkg_', '')}',
    'boundedDigest': boundedDigest,
    'sampleCount': sampleCount,
    'summaryCount': summaryCount,
    'distinctSiteCount': distinctSiteCount,
    'schemaVersions': <String>['v1'],
    'runtimeTargets': <String>['flutter_mobile'],
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
  };
}

Map<String, dynamic> _promotionRevocationRecordRow({
  String id = 'fl_prom_revoke_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String candidatePromotionRecordId = 'fl_prom_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String revokedStatus = 'approved_for_eval',
  String rationale = 'Sandbox regression exceeded the bounded threshold.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'candidatePromotionRecordId': candidatePromotionRecordId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'revokedStatus': revokedStatus,
    'target': 'sandbox_eval',
    'rationale': rationale,
    'revokedBy': 'hq-1',
    'revokedAt': DateTime(2026, 3, 14, 14),
    'createdAt': DateTime(2026, 3, 14, 14),
    'updatedAt': DateTime(2026, 3, 14, 14),
  };
}

Map<String, dynamic> _promotionRecordRow({
  String id = 'fl_prom_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String status = 'approved_for_eval',
  String rationale = 'Ready for bounded sandbox evaluation.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'status': status,
    'target': 'sandbox_eval',
    'rationale': rationale,
    'decidedBy': 'hq-1',
    'decidedAt': DateTime(2026, 3, 14, 12),
    'createdAt': DateTime(2026, 3, 14, 12),
    'updatedAt': DateTime(2026, 3, 14, 12),
  };
}

Map<String, dynamic> _mergeArtifactRow({
  String id = 'fl_merge_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String aggregationRunId = 'fl_agg_1',
  String boundedDigest = 'sha256:digest-1',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'aggregationRunId': aggregationRunId,
    'status': 'generated',
    'mergeStrategy': 'prototype_weighted_metadata_digest',
    'boundedDigest': boundedDigest,
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
    await firestore
      .collection('federatedLearningCandidateModelPackages')
      .doc('fl_pkg_1')
      .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'aggregationRunId': 'fl_agg_1',
      'mergeArtifactId': 'fl_merge_1',
      'status': 'staged',
      'packageFormat': 'bounded_metadata_manifest',
      'rolloutStatus': 'not_distributed',
      'packageDigest': 'sha256:pkg-1',
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
    await firestore
      .collection('federatedLearningCandidatePromotionRecords')
      .doc('fl_prom_1')
      .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'candidateModelPackageId': 'fl_pkg_1',
      'aggregationRunId': 'fl_agg_1',
      'mergeArtifactId': 'fl_merge_1',
      'status': 'approved_for_eval',
      'target': 'sandbox_eval',
      'rationale': 'Ready for bounded sandbox evaluation.',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });

    final FederatedLearningAggregationRunRepository aggregationRepository =
      FederatedLearningAggregationRunRepository(firestore: firestore);
    final FederatedLearningMergeArtifactRepository artifactRepository =
      FederatedLearningMergeArtifactRepository(firestore: firestore);
    final FederatedLearningCandidateModelPackageRepository packageRepository =
      FederatedLearningCandidateModelPackageRepository(firestore: firestore);
    final FederatedLearningCandidatePromotionRecordRepository promotionRepository =
      FederatedLearningCandidatePromotionRecordRepository(firestore: firestore);
    final List<FederatedLearningAggregationRunModel> aggregationRuns =
      await aggregationRepository.listByExperiment('fl_exp_literacy_pilot');
    final List<FederatedLearningMergeArtifactModel> mergeArtifacts =
      await artifactRepository.listByExperiment('fl_exp_literacy_pilot');
    final List<FederatedLearningCandidateModelPackageModel> candidatePackages =
      await packageRepository.listByExperiment('fl_exp_literacy_pilot');
    final List<FederatedLearningCandidatePromotionRecordModel> promotions =
      await promotionRepository.listByExperiment('fl_exp_literacy_pilot');

    expect(aggregationRuns, hasLength(1));
    expect(aggregationRuns.single.totalSampleCount, 14);
    expect(aggregationRuns.single.mergeArtifactStatus, 'generated');
    expect(mergeArtifacts, hasLength(1));
    expect(mergeArtifacts.single.aggregationRunId, 'fl_agg_1');
    expect(candidatePackages, hasLength(1));
    expect(candidatePackages.single.mergeArtifactId, 'fl_merge_1');
    expect(promotions, hasLength(1));
    expect(promotions.single.candidateModelPackageId, 'fl_pkg_1');

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
        _aggregationRunRow(
          createdAt: DateTime(2026, 3, 14, 12),
        ),
        _aggregationRunRow(
          id: 'fl_agg_2',
          totalSampleCount: 20,
          summaryCount: 2,
          distinctSiteCount: 1,
          mergeArtifactId: 'fl_merge_2',
          boundedDigest: 'sha256:digest-2',
          createdAt: DateTime(2026, 3, 13, 12),
        ),
        _aggregationRunRow(
          id: 'fl_agg_3',
          totalSampleCount: 18,
          summaryCount: 1,
          distinctSiteCount: 1,
          mergeArtifactId: '',
          boundedDigest: 'sha256:digest-3',
          createdAt: DateTime(2026, 3, 12, 12),
        ),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
        _mergeArtifactRow(
          id: 'fl_merge_2',
          aggregationRunId: 'fl_agg_2',
          boundedDigest: 'sha256:digest-2',
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
        _candidatePackageRow(
          id: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          boundedDigest: 'sha256:digest-2',
          sampleCount: 20,
        ),
      ],
      promotionRecords: <Map<String, dynamic>>[
        _promotionRecordRow(),
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
    expect(
      find.text('Latest candidate package: fl_pkg_1 (bounded_metadata_manifest)'),
      findsOneWidget,
    );
    expect(
      find.text('Latest package promotion: approved_for_eval (sandbox_eval)'),
      findsOneWidget,
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
    expect(find.text('Sort runs'), findsOneWidget);
    expect(find.text('Latest only'), findsOneWidget);
    expect(find.text('Artifact generated'), findsWidgets);
    expect(find.text('Artifact missing'), findsOneWidget);
    expect(find.text('Artifacts generated: 2'), findsOneWidget);
    expect(find.text('Artifacts missing: 1'), findsOneWidget);
    expect(find.text('Packages staged: 2'), findsOneWidget);
    expect(find.text('Samples: 62'), findsOneWidget);
    expect(
      find.text('Strategy: prototype_weighted_metadata_digest'),
      findsWidgets,
    );
    expect(find.text('Digest: sha256:digest-1'), findsWidgets);
    expect(find.text('Artifact: fl_merge_1'), findsWidgets);
    expect(find.text('Package: fl_pkg_1'), findsWidgets);
    expect(
      find.text('Package format: bounded_metadata_manifest'),
      findsWidgets,
    );
    expect(find.text('Showing 1-2 of 3'), findsOneWidget);

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Artifact missing'), findsWidgets);
    expect(find.text('Digest: sha256:digest-3'), findsOneWidget);
    expect(find.text('Showing 3-3 of 3'), findsOneWidget);

    await tester.ensureVisible(find.text('Previous'));
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Latest only'));
    await tester.tap(find.text('Latest only'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(find.text('Artifact: fl_merge_1'), findsOneWidget);
    expect(find.text('Packages staged: 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Latest only'));
    await tester.tap(find.text('Latest only'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Artifact missing'));
    await tester.tap(find.text('Artifact missing'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(find.text('Artifact missing'), findsWidgets);
    expect(find.text('Digest: sha256:digest-3'), findsOneWidget);
    expect(find.text('Packages staged: 0'), findsOneWidget);

    await tester.ensureVisible(find.text('Artifact missing'));
    await tester.tap(find.text('Artifact missing'));
    await tester.pumpAndSettle();

    final Finder viewPackagesButton = find.widgetWithText(
      TextButton,
      'View packages',
    );
    await tester.ensureVisible(viewPackagesButton.first);
    final TextButton viewPackagesControl = tester.widget<TextButton>(
      viewPackagesButton.first,
    );
    viewPackagesControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Candidate packages: Literacy Pilot'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, or digest',
      ),
      findsOneWidget,
    );
    final Finder approvedFilterChip = find.widgetWithText(
      FilterChip,
      'Approved for eval',
    );
    final Finder awaitingFilterChip = find.widgetWithText(
      FilterChip,
      'Awaiting promotion',
    );
    final Finder holdFilterChip = find.widgetWithText(
      FilterChip,
      'On hold',
    );
    expect(find.text('Sort packages'), findsOneWidget);
    expect(approvedFilterChip, findsOneWidget);
    expect(awaitingFilterChip, findsOneWidget);
    expect(holdFilterChip, findsOneWidget);
    expect(find.text('Packages: 2'), findsOneWidget);
    expect(find.text('Approved for eval: 1'), findsOneWidget);
    expect(find.text('Awaiting promotion: 1'), findsOneWidget);
    expect(find.text('On hold: 0'), findsOneWidget);
    expect(find.text('Samples: 44'), findsOneWidget);
    expect(find.text('Promotion: approved_for_eval (sandbox_eval)'), findsOneWidget);
    expect(
      find.text('Rationale: Ready for bounded sandbox evaluation.'),
      findsOneWidget,
    );

    await tester.ensureVisible(approvedFilterChip);
    await tester.tap(approvedFilterChip);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(
      find.text('Package fl_pkg_1 · 24 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );

    await tester.ensureVisible(approvedFilterChip);
    await tester.tap(approvedFilterChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(awaitingFilterChip);
    await tester.tap(awaitingFilterChip);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(
      find.text('Package fl_pkg_2 · 20 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );
    expect(find.text('Promotion: awaiting decision'), findsOneWidget);

    final Finder holdButton = find.widgetWithText(
      OutlinedButton,
      'Mark hold',
    );
    await tester.ensureVisible(holdButton.first);
    final OutlinedButton holdControl = tester.widget<OutlinedButton>(
      holdButton.first,
    );
    holdControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Record package decision'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rationale'),
      'Need another bounded review pass.',
    );
    final Finder saveDecisionButton = find.widgetWithText(
      FilledButton,
      'Save decision',
    );
    final FilledButton saveDecisionControl = tester.widget<FilledButton>(
      saveDecisionButton,
    );
    saveDecisionControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedPromotionDecisions, hasLength(1));
    expect(bridge.recordedPromotionDecisions.single['status'], 'hold');
    expect(
      bridge.recordedPromotionDecisions.single['candidateModelPackageId'],
      'fl_pkg_2',
    );

    await tester.ensureVisible(holdFilterChip);
    await tester.tap(holdFilterChip);
    await tester.pumpAndSettle();
    expect(find.text('Promotion: hold (sandbox_eval)'), findsOneWidget);
    expect(
      find.text('Rationale: Need another bounded review pass.'),
      findsOneWidget,
    );
    expect(find.text('Awaiting promotion: 0'), findsOneWidget);
    expect(find.text('On hold: 1'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(
      find.text('Package fl_pkg_2 · 20 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );

    await tester.ensureVisible(holdFilterChip);
    await tester.tap(holdFilterChip);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, or digest',
      ),
      'pkg_2',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Package fl_pkg_2 · 20 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    final Finder viewPromotionsButton = find.widgetWithText(
      TextButton,
      'View promotions',
    );
    await tester.ensureVisible(viewPromotionsButton.first);
    final TextButton viewPromotionsControl = tester.widget<TextButton>(
      viewPromotionsButton.first,
    );
    viewPromotionsControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Promotion history: Literacy Pilot'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, or rationale',
      ),
      findsOneWidget,
    );
    final Finder approvedPromotionChip = find.widgetWithText(
      FilterChip,
      'Approved for eval',
    );
    final Finder holdPromotionChip = find.widgetWithText(
      FilterChip,
      'On hold',
    );
    expect(find.text('Sort promotions'), findsOneWidget);
    expect(approvedPromotionChip, findsOneWidget);
    expect(holdPromotionChip, findsOneWidget);
    expect(find.text('Decisions: 2'), findsOneWidget);
    expect(find.text('Approved: 1'), findsOneWidget);
    expect(find.text('On hold: 1'), findsOneWidget);
    expect(find.text('Revoked: 0'), findsOneWidget);
    expect(find.text('Samples: 44'), findsOneWidget);
    expect(
      find.text('Decision fl_prom_1 · approved_for_eval (sandbox_eval)'),
      findsOneWidget,
    );
    expect(
      find.text('Decision fl_prom_2 · hold (sandbox_eval)'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, or rationale',
      ),
      '',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(approvedPromotionChip);
    await tester.tap(approvedPromotionChip);
    await tester.pumpAndSettle();
    expect(find.text('Decisions: 1'), findsOneWidget);
    expect(
      find.text('Decision fl_prom_1 · approved_for_eval (sandbox_eval)'),
      findsOneWidget,
    );

    final Finder revokeDecisionButton = find.widgetWithText(
      OutlinedButton,
      'Revoke decision',
    );
    final OutlinedButton revokeDecisionControl = tester.widget<OutlinedButton>(
      revokeDecisionButton.first,
    );
    revokeDecisionControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Revoke package decision'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rollback rationale'),
      'Sandbox regression exceeded the bounded threshold.',
    );
    final Finder saveRollbackButton = find.widgetWithText(
      FilledButton,
      'Save rollback',
    );
    final FilledButton saveRollbackControl = tester.widget<FilledButton>(
      saveRollbackButton,
    );
    saveRollbackControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedPromotionRevocations, hasLength(1));
    expect(
      bridge.recordedPromotionRevocations.single['candidateModelPackageId'],
      'fl_pkg_1',
    );
    expect(
      bridge.recordedPromotionRevocations.single['revokedStatus'],
      'approved_for_eval',
    );

    await tester.ensureVisible(approvedPromotionChip);
    await tester.tap(approvedPromotionChip);
    await tester.pumpAndSettle();

    expect(find.text('Decisions: 2'), findsOneWidget);
    expect(find.text('Approved: 0'), findsOneWidget);
    expect(find.text('On hold: 1'), findsOneWidget);
    expect(find.text('Revoked: 1'), findsOneWidget);
    expect(
      find.text('Decision fl_prom_1 · revoked (sandbox_eval)'),
      findsOneWidget,
    );
    expect(
      find.text('Revocation: fl_prom_revoke_1 · revoked approved_for_eval · 2026-03-14T14:00:00.000'),
      findsOneWidget,
    );
    expect(
      find.text('Rollback rationale: Sandbox regression exceeded the bounded threshold.'),
      findsOneWidget,
    );

    final Finder revokedPromotionChip = find.widgetWithText(
      FilterChip,
      'Revoked',
    );
    await tester.ensureVisible(revokedPromotionChip);
    await tester.tap(revokedPromotionChip);
    await tester.pumpAndSettle();
    expect(find.text('Decisions: 1'), findsOneWidget);
    expect(find.text('Approved: 0'), findsOneWidget);
    expect(find.text('On hold: 0'), findsOneWidget);
    expect(find.text('Revoked: 1'), findsOneWidget);
    expect(
      find.text('Decision fl_prom_1 · revoked (sandbox_eval)'),
      findsOneWidget,
    );

    await tester.ensureVisible(holdPromotionChip);
    await tester.tap(holdPromotionChip);
    await tester.pumpAndSettle();
    expect(find.text('Decisions: 1'), findsOneWidget);
    expect(
      find.text('Decision fl_prom_2 · hold (sandbox_eval)'),
      findsOneWidget,
    );
    expect(
      find.text('Rationale: Need another bounded review pass.'),
      findsOneWidget,
    );

    await tester.ensureVisible(holdPromotionChip);
    await tester.tap(holdPromotionChip);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, or rationale',
      ),
      'fl_prom_2',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Decision fl_prom_2 · hold (sandbox_eval)'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Filter by run ID, artifact ID, or digest'),
      'digest-2',
    );
    await tester.pumpAndSettle();
    expect(find.text('Artifact: fl_merge_2'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    final Finder createExperimentButton = find.widgetWithText(
      FilledButton,
      'Create experiment',
    );
    await tester.ensureVisible(createExperimentButton);
    final FilledButton createExperimentControl = tester.widget<FilledButton>(
      createExperimentButton,
    );
    createExperimentControl.onPressed?.call();
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
