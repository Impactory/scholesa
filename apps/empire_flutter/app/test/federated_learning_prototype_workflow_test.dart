import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholesa_app/auth/app_state.dart';
import 'package:scholesa_app/domain/models.dart';
import 'package:scholesa_app/domain/repositories.dart';
import 'package:scholesa_app/modules/hq_admin/hq_feature_flags_page.dart';
import 'package:scholesa_app/services/federated_learning_runtime_activation_reporter.dart';
import 'package:scholesa_app/services/federated_learning_runtime_package_resolver.dart';
import 'package:scholesa_app/services/federated_learning_runtime_delivery_resolver.dart';
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
    List<Map<String, dynamic>>? experimentReviewRecords,
    List<Map<String, dynamic>>? pilotEvidenceRecords,
    List<Map<String, dynamic>>? pilotApprovalRecords,
    List<Map<String, dynamic>>? pilotExecutionRecords,
    List<Map<String, dynamic>>? runtimeDeliveryRecords,
    List<Map<String, dynamic>>? runtimeActivationRecords,
    List<Map<String, dynamic>>? runtimeRolloutAlertRecords,
    List<Map<String, dynamic>>? runtimeRolloutEscalationRecords,
    List<Map<String, dynamic>>? runtimeRolloutEscalationHistoryRecords,
    List<Map<String, dynamic>>? runtimeRolloutControlRecords,
    List<Map<String, dynamic>>? runtimeRolloutAuditEvents,
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
        _experimentReviewRecords = List<Map<String, dynamic>>.from(
          experimentReviewRecords ?? <Map<String, dynamic>>[],
        ),
        _pilotEvidenceRecords = List<Map<String, dynamic>>.from(
          pilotEvidenceRecords ?? <Map<String, dynamic>>[],
        ),
        _pilotApprovalRecords = List<Map<String, dynamic>>.from(
          pilotApprovalRecords ?? <Map<String, dynamic>>[],
        ),
        _pilotExecutionRecords = List<Map<String, dynamic>>.from(
          pilotExecutionRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeDeliveryRecords = List<Map<String, dynamic>>.from(
          runtimeDeliveryRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeActivationRecords = List<Map<String, dynamic>>.from(
          runtimeActivationRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeRolloutAlertRecords = List<Map<String, dynamic>>.from(
          runtimeRolloutAlertRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeRolloutEscalationRecords = List<Map<String, dynamic>>.from(
          runtimeRolloutEscalationRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeRolloutEscalationHistoryRecords =
            List<Map<String, dynamic>>.from(
          runtimeRolloutEscalationHistoryRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeRolloutControlRecords = List<Map<String, dynamic>>.from(
          runtimeRolloutControlRecords ?? <Map<String, dynamic>>[],
        ),
        _runtimeRolloutAuditEvents = List<Map<String, dynamic>>.from(
          runtimeRolloutAuditEvents ?? <Map<String, dynamic>>[],
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
  final List<Map<String, dynamic>> _experimentReviewRecords;
  final List<Map<String, dynamic>> _pilotEvidenceRecords;
  final List<Map<String, dynamic>> _pilotApprovalRecords;
  final List<Map<String, dynamic>> _pilotExecutionRecords;
  final List<Map<String, dynamic>> _runtimeDeliveryRecords;
  final List<Map<String, dynamic>> _runtimeActivationRecords;
  final List<Map<String, dynamic>> _runtimeRolloutAlertRecords;
  final List<Map<String, dynamic>> _runtimeRolloutEscalationRecords;
  final List<Map<String, dynamic>> _runtimeRolloutEscalationHistoryRecords;
  final List<Map<String, dynamic>> _runtimeRolloutControlRecords;
  final List<Map<String, dynamic>> _runtimeRolloutAuditEvents;
  final List<Map<String, dynamic>> _promotionRecords;
  final List<Map<String, dynamic>> _promotionRevocationRecords;
  final List<Map<String, dynamic>> recordedUpdates = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedExperimentReviewSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedPilotEvidenceSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedPilotApprovalSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedPilotExecutionSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRuntimeDeliverySaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRuntimeActivationSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRuntimeRolloutAlertSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRuntimeRolloutEscalationSaves =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recordedRuntimeRolloutControlSaves =
      <Map<String, dynamic>>[];
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
  Future<List<Map<String, dynamic>>>
      listFederatedLearningExperimentReviewRecords({
    String? experimentId,
    int limit = 120,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (experimentId == null || experimentId.isEmpty)
            ? _experimentReviewRecords
            : _experimentReviewRecords
                .where((Map<String, dynamic> row) =>
                    row['experimentId'] == experimentId)
                .toList();
    return scoped
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
      'allowedSiteIds': List<String>.from(
        data['allowedSiteIds'] as List<dynamic>? ?? <dynamic>[],
      ),
      'updatedAt': DateTime(2026, 3, 14, 15),
    };
    _experiments.removeWhere((Map<String, dynamic> row) => row['id'] == id);
    _siteExperiments.removeWhere((Map<String, dynamic> row) => row['id'] == id);
    _experiments.insert(0, row);
    _siteExperiments.insert(0, row);
    return id;
  }

  @override
  Future<String?> upsertFederatedLearningExperimentReviewRecord(
    Map<String, dynamic> data,
  ) async {
    final String experimentId = (data['experimentId'] as String? ?? '').trim();
    final String reviewId =
        'fl_review_${experimentId.replaceAll('fl_exp_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': reviewId,
      'experimentId': experimentId,
      'status': (data['status'] as String? ?? 'pending').trim(),
      'privacyReviewComplete': data['privacyReviewComplete'] == true,
      'signoffChecklistComplete': data['signoffChecklistComplete'] == true,
      'rolloutRiskAcknowledged': data['rolloutRiskAcknowledged'] == true,
      'notes': (data['notes'] as String? ?? '').trim(),
      'reviewedBy': 'hq-1',
      'reviewedAt': DateTime(2026, 3, 14, 15),
      'createdAt': DateTime(2026, 3, 14, 15),
      'updatedAt': DateTime(2026, 3, 14, 15),
    };
    _experimentReviewRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == reviewId,
    );
    _experimentReviewRecords.insert(0, record);
    recordedExperimentReviewSaves.add(<String, dynamic>{...record});
    return reviewId;
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
                (Map<String, dynamic> row) =>
                    row['experimentId'] == experimentId,
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
                (Map<String, dynamic> row) =>
                    row['experimentId'] == experimentId,
              );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidateModelPackages({
    String? experimentId,
    int limit = 60,
  }) async {
    final Iterable<Map<String, dynamic>> scoped =
        (experimentId == null || experimentId.isEmpty)
            ? _candidatePackages
            : _candidatePackages.where(
                (Map<String, dynamic> row) =>
                    row['experimentId'] == experimentId,
              );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningCandidatePromotionRecords({
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
  Future<List<Map<String, dynamic>>> listFederatedLearningPilotEvidenceRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _pilotEvidenceRecords;
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
  Future<List<Map<String, dynamic>>> listFederatedLearningPilotApprovalRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _pilotApprovalRecords;
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
      listFederatedLearningPilotExecutionRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _pilotExecutionRecords;
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
      listFederatedLearningRuntimeDeliveryRecords({
    String? experimentId,
    String? candidateModelPackageId,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _runtimeDeliveryRecords;
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
      listSiteFederatedLearningRuntimeDeliveryRecords({
    String? siteId,
    int limit = 40,
  }) async {
    final String resolvedSiteId = (siteId ?? '').trim();
    final Iterable<Map<String, dynamic>> scoped = _runtimeDeliveryRecords.where(
      (Map<String, dynamic> row) {
        final List<dynamic> targetSiteIds =
            row['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
        final String status = (row['status'] as String? ?? '').trim();
        final DateTime now = DateTime(2026, 3, 15, 10, 0);
        final DateTime? expiresAt = row['expiresAt'] as DateTime?;
        final DateTime? revokedAt = row['revokedAt'] as DateTime?;
        final DateTime? supersededAt = row['supersededAt'] as DateTime?;
        final bool terminalLifecycle = status == 'revoked' ||
            status == 'superseded' ||
            revokedAt != null ||
            supersededAt != null ||
            (expiresAt != null && !expiresAt.isAfter(now));
        return targetSiteIds.contains(resolvedSiteId) &&
            (status == 'assigned' || status == 'active') &&
            !terminalLifecycle;
      },
    );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
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
    Iterable<Map<String, dynamic>> scoped = _runtimeActivationRecords;
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
    if (siteId != null && siteId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['siteId'] == siteId,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
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
  }) async {
    Iterable<Map<String, dynamic>> scoped = _runtimeRolloutAlertRecords;
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
    if (deliveryRecordId != null && deliveryRecordId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (status != null && status.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['status'] == status,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutEscalationRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 60,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _runtimeRolloutEscalationRecords;
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
    if (deliveryRecordId != null && deliveryRecordId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (status != null && status.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['status'] == status,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutEscalationHistoryRecords({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? status,
    int limit = 80,
  }) async {
    Iterable<Map<String, dynamic>> scoped =
        _runtimeRolloutEscalationHistoryRecords;
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
    if (deliveryRecordId != null && deliveryRecordId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (status != null && status.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['status'] == status,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
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
    Iterable<Map<String, dynamic>> scoped = _runtimeRolloutControlRecords;
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
    if (deliveryRecordId != null && deliveryRecordId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId,
      );
    }
    if (mode != null && mode.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) => row['mode'] == mode,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listFederatedLearningRuntimeRolloutAuditEvents({
    String? experimentId,
    String? candidateModelPackageId,
    String? deliveryRecordId,
    String? siteId,
    int limit = 80,
  }) async {
    Iterable<Map<String, dynamic>> scoped = _runtimeRolloutAuditEvents;
    if (experimentId != null && experimentId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            (row['details'] as Map<String, dynamic>? ??
                <String, dynamic>{})['experimentId'] ==
            experimentId,
      );
    }
    if (candidateModelPackageId != null && candidateModelPackageId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            (row['details'] as Map<String, dynamic>? ??
                <String, dynamic>{})['candidateModelPackageId'] ==
            candidateModelPackageId,
      );
    }
    if (deliveryRecordId != null && deliveryRecordId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            (row['details'] as Map<String, dynamic>? ??
                <String, dynamic>{})['deliveryRecordId'] ==
            deliveryRecordId,
      );
    }
    if (siteId != null && siteId.isNotEmpty) {
      scoped = scoped.where(
        (Map<String, dynamic> row) =>
            (row['details'] as Map<String, dynamic>? ??
                <String, dynamic>{})['siteId'] ==
            siteId,
      );
    }
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>>
      listSiteFederatedLearningRuntimeActivationRecords({
    String? siteId,
    int limit = 40,
  }) async {
    final String resolvedSiteId = (siteId ?? '').trim();
    final Iterable<Map<String, dynamic>> scoped =
        _runtimeActivationRecords.where(
      (Map<String, dynamic> row) => row['siteId'] == resolvedSiteId,
    );
    return scoped
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> resolveSiteFederatedLearningRuntimePackage({
    String? siteId,
    String? experimentId,
    String? runtimeTarget,
    String? deliveryRecordId,
  }) async {
    final String resolvedSiteId = (siteId ?? '').trim();
    const Map<String, int> deliveryPriority = <String, int>{
      'active': 4,
      'assigned': 3,
      'revoked': 2,
      'superseded': 1,
    };
    final Map<String, dynamic> deliveryRow = deliveryRecordId != null &&
            deliveryRecordId.isNotEmpty
        ? _runtimeDeliveryRecords.firstWhere(
            (Map<String, dynamic> row) => row['id'] == deliveryRecordId,
            orElse: () => <String, dynamic>{},
          )
        : (() {
            final List<Map<String, dynamic>> matches = _runtimeDeliveryRecords
                .where((Map<String, dynamic> row) {
              final List<dynamic> targetSiteIds =
                  row['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
              final String status = (row['status'] as String? ?? '').trim();
              final bool matchesExperiment =
                  (experimentId ?? '').trim().isEmpty ||
                      row['experimentId'] == experimentId;
              final bool matchesRuntime =
                  (runtimeTarget ?? '').trim().isEmpty ||
                      row['runtimeTarget'] == runtimeTarget;
              return targetSiteIds.contains(resolvedSiteId) &&
                  deliveryPriority.containsKey(status) &&
                  matchesExperiment &&
                  matchesRuntime;
            }).toList()
              ..sort((Map<String, dynamic> left, Map<String, dynamic> right) {
                final int leftPriority = deliveryPriority[
                        (left['status'] as String? ?? '').trim()] ??
                    0;
                final int rightPriority = deliveryPriority[
                        (right['status'] as String? ?? '').trim()] ??
                    0;
                if (leftPriority != rightPriority) {
                  return rightPriority.compareTo(leftPriority);
                }
                final DateTime? leftUpdatedAt = left['updatedAt'] as DateTime?;
                final DateTime? rightUpdatedAt =
                    right['updatedAt'] as DateTime?;
                if (leftUpdatedAt == null && rightUpdatedAt == null) {
                  return 0;
                }
                if (leftUpdatedAt == null) {
                  return 1;
                }
                if (rightUpdatedAt == null) {
                  return -1;
                }
                return rightUpdatedAt.compareTo(leftUpdatedAt);
              });
            return matches.isEmpty ? <String, dynamic>{} : matches.first;
          })();
    if (deliveryRow.isEmpty) {
      return null;
    }
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) =>
          row['id'] == deliveryRow['candidateModelPackageId'],
      orElse: () => <String, dynamic>{},
    );
    if (packageRow.isEmpty) {
      return null;
    }
    final DateTime now = DateTime(2026, 3, 14, 20, 30);
    final DateTime? expiresAt = deliveryRow['expiresAt'] as DateTime?;
    final DateTime? supersededAt = deliveryRow['supersededAt'] as DateTime?;
    final String supersededBy =
        (deliveryRow['supersededBy'] as String? ?? '').trim();
    final String supersededByDeliveryRecordId =
        (deliveryRow['supersededByDeliveryRecordId'] as String? ?? '').trim();
    final String supersededByCandidateModelPackageId =
        (deliveryRow['supersededByCandidateModelPackageId'] as String? ?? '')
            .trim();
    final String supersessionReason =
        (deliveryRow['supersessionReason'] as String? ?? '').trim();
    final DateTime? revokedAt = deliveryRow['revokedAt'] as DateTime?;
    final String status = (deliveryRow['status'] as String? ?? '').trim();
    final Map<String, dynamic> controlRow =
        _runtimeRolloutControlRecords.firstWhere(
      (Map<String, dynamic> row) =>
          row['deliveryRecordId'] == (deliveryRow['id'] ?? ''),
      orElse: () => <String, dynamic>{},
    );
    String resolutionStatus = status == 'revoked' || revokedAt != null
        ? 'revoked'
        : (status == 'superseded' || supersededAt != null)
            ? 'superseded'
            : (expiresAt != null && !expiresAt.isAfter(now))
                ? 'expired'
                : 'resolved';
    final String controlMode = (controlRow['mode'] as String? ?? '').trim();
    final String controlReason = (controlRow['reason'] as String? ?? '').trim();
    final DateTime? controlReviewByAt = controlRow['reviewByAt'] as DateTime?;
    if (resolutionStatus == 'resolved' && controlMode == 'paused') {
      resolutionStatus = 'paused';
    }
    if (resolutionStatus == 'resolved' && controlMode == 'restricted') {
      final Map<String, dynamic> activationRow =
          _runtimeActivationRecords.firstWhere(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRow['id'] &&
            row['siteId'] == resolvedSiteId,
        orElse: () => <String, dynamic>{},
      );
      final String activationStatus =
          (activationRow['status'] as String? ?? '').trim();
      if (activationStatus != 'resolved') {
        resolutionStatus = 'restricted';
      }
    }
    return <String, dynamic>{
      'packageId': packageRow['id'] ?? '',
      'deliveryRecordId': deliveryRow['id'] ?? '',
      'experimentId': deliveryRow['experimentId'] ?? '',
      'candidateModelPackageId': packageRow['id'] ?? '',
      'siteId': resolvedSiteId,
      'runtimeTarget': deliveryRow['runtimeTarget'] ?? 'flutter_mobile',
      'packageDigest': packageRow['packageDigest'] ?? '',
      'manifestDigest': deliveryRow['manifestDigest'] ?? '',
      'resolutionStatus': resolutionStatus,
      'modelVersion': packageRow['modelVersion'] ?? 'fl_runtime_model_v1',
      'runtimeVectorLength': resolutionStatus == 'resolved'
          ? (packageRow['runtimeVectorLength'] ?? 0)
          : 0,
      'runtimeVector': resolutionStatus == 'resolved'
          ? List<double>.from(
              packageRow['runtimeVector'] as List<dynamic>? ?? const <double>[])
          : const <double>[],
      'runtimeVectorDigest': packageRow['runtimeVectorDigest'] ?? '',
      'rolloutStatus': packageRow['rolloutStatus'] ?? 'not_distributed',
      'expiresAt': deliveryRow['expiresAt'],
      'supersededAt': supersededAt,
      'supersededBy': supersededBy.isEmpty ? null : supersededBy,
      'supersededByDeliveryRecordId': supersededByDeliveryRecordId.isEmpty
          ? null
          : supersededByDeliveryRecordId,
      'supersededByCandidateModelPackageId':
          supersededByCandidateModelPackageId.isEmpty
              ? null
              : supersededByCandidateModelPackageId,
      'supersessionReason':
          supersessionReason.isEmpty ? null : supersessionReason,
      'revokedAt': deliveryRow['revokedAt'],
      'revokedBy': deliveryRow['revokedBy'],
      'revocationReason': deliveryRow['revocationReason'],
      'rolloutControlMode': controlMode.isEmpty ? null : controlMode,
      'rolloutControlReason': controlReason.isEmpty ? null : controlReason,
      'rolloutControlReviewByAt': controlReviewByAt,
      'resolvedAt': DateTime(2026, 3, 14, 20),
    };
  }

  @override
  Future<String?> upsertFederatedLearningCandidatePromotionRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final String status = (data['status'] as String? ?? '').trim();
    final String rawTarget =
        (data['target'] as String? ?? 'sandbox_eval').trim();
    final String target = rawTarget.isEmpty ? 'sandbox_eval' : rawTarget;
    final String rationale = (data['rationale'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String promotionId = 'fl_prom_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': promotionId,
      'experimentId': packageRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'packageDigest': packageRow['packageDigest'] ?? '',
      'boundedDigest': packageRow['boundedDigest'] ?? '',
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
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
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
      'packageDigest':
          promotionRow['packageDigest'] ?? packageRow['packageDigest'] ?? '',
      'boundedDigest':
          promotionRow['boundedDigest'] ?? packageRow['boundedDigest'] ?? '',
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
  Future<String?> upsertFederatedLearningPilotEvidenceRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String evidenceId = 'fl_pilot_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': evidenceId,
      'experimentId': packageRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'status': (data['status'] as String? ?? 'pending').trim(),
      'sandboxEvalComplete': data['sandboxEvalComplete'] == true,
      'metricsSnapshotComplete': data['metricsSnapshotComplete'] == true,
      'rollbackPlanVerified': data['rollbackPlanVerified'] == true,
      'notes': (data['notes'] as String? ?? '').trim(),
      'reviewedBy': 'hq-1',
      'reviewedAt': DateTime(2026, 3, 14, 16),
      'createdAt': DateTime(2026, 3, 14, 16),
      'updatedAt': DateTime(2026, 3, 14, 16),
    };
    _pilotEvidenceRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == evidenceId,
    );
    _pilotEvidenceRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestPilotEvidenceRecordId': evidenceId,
        'latestPilotEvidenceStatus': record['status'],
      };
    }
    recordedPilotEvidenceSaves.add(<String, dynamic>{...record});
    return evidenceId;
  }

  @override
  Future<String?> upsertFederatedLearningPilotApprovalRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String approvalId =
        'fl_pilot_approval_${packageId.replaceAll('fl_pkg_', '')}';
    final String experimentId =
        (packageRow['experimentId'] as String? ?? '').trim();
    final Map<String, dynamic> record = <String, dynamic>{
      'id': approvalId,
      'experimentId': experimentId,
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'experimentReviewRecordId':
          'fl_review_${experimentId.replaceAll('fl_exp_', '')}',
      'pilotEvidenceRecordId':
          'fl_pilot_${packageId.replaceAll('fl_pkg_', '')}',
      'candidatePromotionRecordId':
          'fl_prom_${packageId.replaceAll('fl_pkg_', '')}',
      'promotionTarget': 'sandbox_eval',
      'status': (data['status'] as String? ?? 'pending').trim(),
      'notes': (data['notes'] as String? ?? '').trim(),
      'approvedBy': 'hq-1',
      'approvedAt': DateTime(2026, 3, 14, 17),
      'createdAt': DateTime(2026, 3, 14, 17),
      'updatedAt': DateTime(2026, 3, 14, 17),
    };
    _pilotApprovalRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == approvalId,
    );
    _pilotApprovalRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestPilotApprovalRecordId': approvalId,
        'latestPilotApprovalStatus': record['status'],
      };
    }
    recordedPilotApprovalSaves.add(<String, dynamic>{...record});
    return approvalId;
  }

  @override
  Future<String?> upsertFederatedLearningPilotExecutionRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String executionId =
        'fl_pilot_execution_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': executionId,
      'experimentId': packageRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'pilotApprovalRecordId':
          'fl_pilot_approval_${packageId.replaceAll('fl_pkg_', '')}',
      'status': (data['status'] as String? ?? 'planned').trim(),
      'launchedSiteIds': List<String>.from(
        data['launchedSiteIds'] as List<dynamic>? ?? <dynamic>[],
      ),
      'sessionCount': data['sessionCount'] as int? ?? 0,
      'learnerCount': data['learnerCount'] as int? ?? 0,
      'notes': (data['notes'] as String? ?? '').trim(),
      'recordedBy': 'hq-1',
      'recordedAt': DateTime(2026, 3, 14, 18),
      'createdAt': DateTime(2026, 3, 14, 18),
      'updatedAt': DateTime(2026, 3, 14, 18),
    };
    _pilotExecutionRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == executionId,
    );
    _pilotExecutionRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestPilotExecutionRecordId': executionId,
        'latestPilotExecutionStatus': record['status'],
      };
    }
    recordedPilotExecutionSaves.add(<String, dynamic>{...record});
    return executionId;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeDeliveryRecord(
    Map<String, dynamic> data,
  ) async {
    final String packageId =
        (data['candidateModelPackageId'] as String? ?? '').trim();
    final Map<String, dynamic> packageRow = _candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
      orElse: () => <String, dynamic>{},
    );
    final String deliveryId =
        'fl_delivery_${packageId.replaceAll('fl_pkg_', '')}';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': deliveryId,
      'experimentId': packageRow['experimentId'] ?? '',
      'candidateModelPackageId': packageId,
      'aggregationRunId': packageRow['aggregationRunId'] ?? '',
      'mergeArtifactId': packageRow['mergeArtifactId'] ?? '',
      'pilotExecutionRecordId':
          'fl_pilot_execution_${packageId.replaceAll('fl_pkg_', '')}',
      'runtimeTarget': 'flutter_mobile',
      'targetSiteIds': List<String>.from(
        data['targetSiteIds'] as List<dynamic>? ?? <dynamic>[],
      ),
      'status': (data['status'] as String? ?? 'prepared').trim(),
      'packageDigest': packageRow['packageDigest'] ?? '',
      'manifestDigest':
          'sha256:delivery-${packageId.replaceAll('fl_pkg_', '')}',
      'expiresAt': data['expiresAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              data['expiresAt'] as int,
              isUtc: true,
            ),
      'supersededAt': null,
      'supersededBy': null,
      'supersededByDeliveryRecordId': null,
      'supersededByCandidateModelPackageId': null,
      'supersessionReason': null,
      'revokedAt': (data['status'] as String? ?? '').trim() == 'revoked'
          ? DateTime(2026, 3, 14, 20, 45)
          : null,
      'revokedBy':
          (data['status'] as String? ?? '').trim() == 'revoked' ? 'hq-1' : null,
      'revocationReason': (data['revocationReason'] as String? ?? '').trim(),
      'notes': (data['notes'] as String? ?? '').trim(),
      'assignedBy': 'hq-1',
      'assignedAt': DateTime(2026, 3, 14, 19),
      'createdAt': DateTime(2026, 3, 14, 19),
      'updatedAt': DateTime(2026, 3, 14, 19),
    };
    final String nextStatus = (record['status'] as String? ?? '').trim();
    if (nextStatus == 'assigned' || nextStatus == 'active') {
      final List<String> nextTargetSiteIds = List<String>.from(
        record['targetSiteIds'] as List<dynamic>? ?? <dynamic>[],
      );
      for (int index = 0; index < _runtimeDeliveryRecords.length; index += 1) {
        final Map<String, dynamic> existing = _runtimeDeliveryRecords[index];
        if ((existing['id'] as String? ?? '') == deliveryId) {
          continue;
        }
        final String existingStatus =
            (existing['status'] as String? ?? '').trim();
        final String existingExperimentId =
            (existing['experimentId'] as String? ?? '').trim();
        final String existingRuntimeTarget =
            (existing['runtimeTarget'] as String? ?? '').trim();
        final List<String> existingTargetSiteIds = List<String>.from(
          existing['targetSiteIds'] as List<dynamic>? ?? <dynamic>[],
        );
        final bool overlaps =
            existingTargetSiteIds.any(nextTargetSiteIds.contains);
        if (!(existingStatus == 'assigned' || existingStatus == 'active') ||
            existingExperimentId != (packageRow['experimentId'] ?? '') ||
            existingRuntimeTarget != 'flutter_mobile' ||
            !overlaps) {
          continue;
        }
        _runtimeDeliveryRecords[index] = <String, dynamic>{
          ...existing,
          'status': 'superseded',
          'supersededAt': DateTime(2026, 3, 14, 20, 15),
          'supersededBy': 'hq-1',
          'supersededByDeliveryRecordId': deliveryId,
          'supersededByCandidateModelPackageId': packageId,
          'supersessionReason':
              'Superseded by $deliveryId for overlapping site cohort.',
          'revokedAt': null,
          'revokedBy': null,
          'revocationReason': null,
          'updatedAt': DateTime(2026, 3, 14, 20, 15),
        };
        final int supersededPackageIndex = _candidatePackages.indexWhere(
          (Map<String, dynamic> row) =>
              row['id'] == existing['candidateModelPackageId'],
        );
        if (supersededPackageIndex >= 0) {
          _candidatePackages[supersededPackageIndex] = <String, dynamic>{
            ..._candidatePackages[supersededPackageIndex],
            'latestRuntimeDeliveryRecordId': existing['id'],
            'latestRuntimeDeliveryStatus': 'superseded',
            'rolloutStatus': 'retired',
          };
        }
      }
    }
    _runtimeDeliveryRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == deliveryId,
    );
    _runtimeDeliveryRecords.insert(0, record);
    final int packageIndex = _candidatePackages.indexWhere(
      (Map<String, dynamic> row) => row['id'] == packageId,
    );
    if (packageIndex >= 0) {
      _candidatePackages[packageIndex] = <String, dynamic>{
        ..._candidatePackages[packageIndex],
        'latestRuntimeDeliveryRecordId': deliveryId,
        'latestRuntimeDeliveryStatus': record['status'],
        'rolloutStatus': nextStatus == 'assigned' || nextStatus == 'active'
            ? 'distributed'
            : (nextStatus == 'superseded' || nextStatus == 'revoked')
                ? 'retired'
                : 'not_distributed',
      };
    }
    recordedRuntimeDeliverySaves.add(<String, dynamic>{...record});
    return deliveryId;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeActivationRecord(
    Map<String, dynamic> data,
  ) async {
    final String deliveryRecordId =
        (data['deliveryRecordId'] as String? ?? '').trim();
    final Map<String, dynamic> deliveryRow = _runtimeDeliveryRecords.firstWhere(
      (Map<String, dynamic> row) => row['id'] == deliveryRecordId,
      orElse: () => <String, dynamic>{},
    );
    final String siteId = (data['siteId'] as String? ?? '').trim();
    final String activationId =
        'fl_runtime_activation_${deliveryRecordId.replaceAll('fl_delivery_', '')}_$siteId';
    final Map<String, dynamic> record = <String, dynamic>{
      'id': activationId,
      'deliveryRecordId': deliveryRecordId,
      'experimentId': deliveryRow['experimentId'] ?? '',
      'candidateModelPackageId': deliveryRow['candidateModelPackageId'] ?? '',
      'siteId': siteId,
      'runtimeTarget': deliveryRow['runtimeTarget'] ?? 'flutter_mobile',
      'manifestDigest': deliveryRow['manifestDigest'] ?? '',
      'status': (data['status'] as String? ?? 'resolved').trim(),
      'traceId': (data['traceId'] as String? ?? '').trim(),
      'notes': (data['notes'] as String? ?? '').trim(),
      'reportedBy': 'site-admin-1',
      'reportedAt': DateTime(2026, 3, 14, 20),
      'createdAt': DateTime(2026, 3, 14, 20),
      'updatedAt': DateTime(2026, 3, 14, 20),
    };
    _runtimeActivationRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == activationId,
    );
    _runtimeActivationRecords.insert(0, record);
    recordedRuntimeActivationSaves.add(<String, dynamic>{...record});
    return activationId;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeRolloutAlertRecord(
    Map<String, dynamic> data,
  ) async {
    final String deliveryRecordId =
        (data['deliveryRecordId'] as String? ?? '').trim();
    final Map<String, dynamic> deliveryRow = _runtimeDeliveryRecords.firstWhere(
      (Map<String, dynamic> row) => row['id'] == deliveryRecordId,
      orElse: () => <String, dynamic>{},
    );
    final List<dynamic> targetSiteIds =
        deliveryRow['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
    int fallbackCount = 0;
    int pendingCount = 0;
    for (final dynamic siteEntry in targetSiteIds) {
      final String siteId = '$siteEntry';
      final Map<String, dynamic> activationRow =
          _runtimeActivationRecords.firstWhere(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId &&
            row['siteId'] == siteId,
        orElse: () => <String, dynamic>{},
      );
      final String activationStatus =
          (activationRow['status'] as String? ?? '').trim();
      if (activationStatus == 'fallback') {
        fallbackCount += 1;
      } else if (activationStatus.isEmpty) {
        pendingCount += 1;
      }
    }

    final String alertId =
        'fl_rollout_alert_${deliveryRecordId.replaceAll('fl_delivery_', '')}';
    final DateTime now = DateTime(2026, 3, 15, 10, 0);
    final DateTime? expiresAt = deliveryRow['expiresAt'] as DateTime?;
    final String deliveryStatus =
        (deliveryRow['status'] as String? ?? '').trim();
    final String terminalLifecycleStatus = deliveryStatus == 'revoked'
        ? 'revoked'
        : deliveryStatus == 'superseded'
            ? 'superseded'
            : (expiresAt != null && !expiresAt.isAfter(now))
                ? 'expired'
                : '';
    final String requestedStatus =
        (data['status'] as String? ?? 'active').trim();
    final String status = terminalLifecycleStatus.isNotEmpty ||
            (fallbackCount == 0 && pendingCount == 0)
        ? 'acknowledged'
        : requestedStatus;
    final Map<String, dynamic> record = <String, dynamic>{
      'id': alertId,
      'experimentId': deliveryRow['experimentId'] ?? '',
      'candidateModelPackageId': deliveryRow['candidateModelPackageId'] ?? '',
      'deliveryRecordId': deliveryRecordId,
      'status': status,
      'fallbackCount': fallbackCount,
      'pendingCount': pendingCount,
      'notes': (data['notes'] as String? ?? '').trim(),
      'acknowledgedBy': status == 'acknowledged' ? 'hq-1' : null,
      'acknowledgedAt': status == 'acknowledged' ? now : null,
      'createdAt': DateTime(2026, 3, 14, 21),
      'updatedAt': now,
    };
    _runtimeRolloutAlertRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == alertId,
    );
    _runtimeRolloutAlertRecords.insert(0, record);
    recordedRuntimeRolloutAlertSaves.add(<String, dynamic>{...record});
    return alertId;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeRolloutEscalationRecord(
    Map<String, dynamic> data,
  ) async {
    final String deliveryRecordId =
        (data['deliveryRecordId'] as String? ?? '').trim();
    final Map<String, dynamic> deliveryRow = _runtimeDeliveryRecords.firstWhere(
      (Map<String, dynamic> row) => row['id'] == deliveryRecordId,
      orElse: () => <String, dynamic>{},
    );
    final List<dynamic> targetSiteIds =
        deliveryRow['targetSiteIds'] as List<dynamic>? ?? <dynamic>[];
    int fallbackCount = 0;
    int pendingCount = 0;
    for (final dynamic siteEntry in targetSiteIds) {
      final String siteId = '$siteEntry';
      final Map<String, dynamic> activationRow =
          _runtimeActivationRecords.firstWhere(
        (Map<String, dynamic> row) =>
            row['deliveryRecordId'] == deliveryRecordId &&
            row['siteId'] == siteId,
        orElse: () => <String, dynamic>{},
      );
      final String activationStatus =
          (activationRow['status'] as String? ?? '').trim();
      if (activationStatus == 'fallback') {
        fallbackCount += 1;
      } else if (activationStatus.isEmpty) {
        pendingCount += 1;
      }
    }

    final String escalationId =
        'fl_rollout_escalation_${deliveryRecordId.replaceAll('fl_delivery_', '')}';
    final Map<String, dynamic> existingEscalation =
        _runtimeRolloutEscalationRecords.firstWhere(
      (Map<String, dynamic> row) => row['id'] == escalationId,
      orElse: () => <String, dynamic>{},
    );
    final DateTime now = DateTime(2026, 3, 15, 10, 0);
    final DateTime? expiresAt = deliveryRow['expiresAt'] as DateTime?;
    final String deliveryStatus =
        (deliveryRow['status'] as String? ?? '').trim();
    final String terminalLifecycleStatus = deliveryStatus == 'revoked'
        ? 'revoked'
        : deliveryStatus == 'superseded'
            ? 'superseded'
            : (expiresAt != null && !expiresAt.isAfter(now))
                ? 'expired'
                : '';
    final String requestedStatus = (data['status'] as String? ?? 'open').trim();
    final bool currentIssueActive = fallbackCount > 0 || pendingCount > 0;
    final String existingStatus =
        (existingEscalation['status'] as String? ?? '').trim();
    final String reopenedStatus =
        existingStatus.isNotEmpty && existingStatus != 'resolved'
            ? existingStatus
            : 'open';
    final String status =
        terminalLifecycleStatus.isNotEmpty || !currentIssueActive
            ? 'resolved'
            : requestedStatus == 'resolved'
                ? reopenedStatus
                : requestedStatus;
    final DateTime openedAt = DateTime(2026, 3, 15, 6, 0);
    final DateTime? dueAt = status == 'resolved'
        ? null
        : (fallbackCount > 0
            ? openedAt.add(Duration(hours: status == 'investigating' ? 8 : 4))
            : openedAt
                .add(Duration(hours: status == 'investigating' ? 48 : 24)));
    final Map<String, dynamic> record = <String, dynamic>{
      'id': escalationId,
      'experimentId': deliveryRow['experimentId'] ?? '',
      'candidateModelPackageId': deliveryRow['candidateModelPackageId'] ?? '',
      'deliveryRecordId': deliveryRecordId,
      'status': status,
      'fallbackCount': fallbackCount,
      'pendingCount': pendingCount,
      'openedAt': status == 'resolved' ? null : openedAt,
      'dueAt': dueAt,
      'ownerUserId': (data['ownerUserId'] as String? ?? '').trim(),
      'notes': (data['notes'] as String? ?? '').trim(),
      'resolvedBy': status == 'resolved' ? 'hq-1' : null,
      'resolvedAt': status == 'resolved' ? now : null,
      'createdAt': DateTime(2026, 3, 14, 21, 30),
      'updatedAt': now,
    };
    _runtimeRolloutEscalationRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == escalationId,
    );
    _runtimeRolloutEscalationRecords.insert(0, record);
    _runtimeRolloutEscalationHistoryRecords.insert(0, <String, dynamic>{
      'id': 'history-${_runtimeRolloutEscalationHistoryRecords.length + 1}',
      'escalationRecordId': escalationId,
      'experimentId': record['experimentId'],
      'candidateModelPackageId': record['candidateModelPackageId'],
      'deliveryRecordId': deliveryRecordId,
      'status': status,
      'fallbackCount': fallbackCount,
      'pendingCount': pendingCount,
      'openedAt': record['openedAt'],
      'dueAt': dueAt,
      'ownerUserId': record['ownerUserId'],
      'notes': record['notes'],
      'resolvedBy': record['resolvedBy'],
      'resolvedAt': record['resolvedAt'],
      'recordedBy': 'hq-1',
      'recordedAt': now,
    });
    recordedRuntimeRolloutEscalationSaves.add(<String, dynamic>{...record});
    return escalationId;
  }

  @override
  Future<String?> upsertFederatedLearningRuntimeRolloutControlRecord(
    Map<String, dynamic> data,
  ) async {
    final String deliveryRecordId =
        (data['deliveryRecordId'] as String? ?? '').trim();
    final Map<String, dynamic> deliveryRow = _runtimeDeliveryRecords.firstWhere(
      (Map<String, dynamic> row) => row['id'] == deliveryRecordId,
      orElse: () => <String, dynamic>{},
    );
    final String controlId =
        'fl_rollout_control_${deliveryRecordId.replaceAll('fl_delivery_', '')}';
    final DateTime now = DateTime(2026, 3, 15, 10, 0);
    final DateTime? expiresAt = deliveryRow['expiresAt'] as DateTime?;
    final String deliveryStatus =
        (deliveryRow['status'] as String? ?? '').trim();
    final String terminalLifecycleStatus = deliveryStatus == 'revoked'
        ? 'revoked'
        : deliveryStatus == 'superseded'
            ? 'superseded'
            : (expiresAt != null && !expiresAt.isAfter(now))
                ? 'expired'
                : '';
    final String requestedMode = (data['mode'] as String? ?? 'monitor').trim();
    final String mode =
        terminalLifecycleStatus.isNotEmpty ? 'monitor' : requestedMode;
    final Map<String, dynamic> record = <String, dynamic>{
      'id': controlId,
      'experimentId': deliveryRow['experimentId'] ?? '',
      'candidateModelPackageId': deliveryRow['candidateModelPackageId'] ?? '',
      'deliveryRecordId': deliveryRecordId,
      'mode': mode,
      'ownerUserId': terminalLifecycleStatus.isNotEmpty
          ? null
          : (data['ownerUserId'] as String? ?? '').trim(),
      'reason':
          mode == 'monitor' ? null : (data['reason'] as String? ?? '').trim(),
      'releasedBy': mode == 'monitor' ? 'hq-1' : null,
      'releasedAt': mode == 'monitor' ? now : null,
      'createdAt': DateTime(2026, 3, 15, 10, 0),
      'updatedAt': DateTime(2026, 3, 15, 10, 0),
    };
    _runtimeRolloutControlRecords.removeWhere(
      (Map<String, dynamic> row) => row['id'] == controlId,
    );
    _runtimeRolloutControlRecords.insert(0, record);
    recordedRuntimeRolloutControlSaves.add(<String, dynamic>{...record});
    return controlId;
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
  String triggerSummaryId = 'update-2',
  List<String> summaryIds = const <String>['update-1', 'update-2'],
  double normCap = 2.4,
  double effectiveTotalWeight = 17.6,
  List<String> contributingSiteIds = const <String>['site-1', 'site-2'],
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
        mergeArtifactId.isEmpty ? '' : 'runtime_vector_v1',
    'payloadFormat': 'runtime_vector_v1',
    'modelVersion': 'fl_runtime_model_v1',
    'runtimeVectorLength': 8,
    'runtimeVectorDigest': 'sha256:runtime-digest-1',
    'mergeStrategy': 'norm_capped_weighted_runtime_vector_average_v2',
    'normCap': normCap,
    'effectiveTotalWeight': effectiveTotalWeight,
    'boundedDigest': boundedDigest,
    'triggerSummaryId': triggerSummaryId,
    'summaryIds': summaryIds,
    'summaryCount': summaryCount,
    'distinctSiteCount': distinctSiteCount,
    'contributingSiteIds': contributingSiteIds,
    'totalSampleCount': totalSampleCount,
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
    'runtimeVector': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
    'contributionDetails': _contributionDetailRows(),
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
  String rolloutStatus = 'not_distributed',
  String boundedDigest = 'sha256:digest-1',
  int sampleCount = 24,
  int summaryCount = 2,
  int distinctSiteCount = 2,
  double normCap = 2.4,
  double effectiveTotalWeight = 17.6,
  String triggerSummaryId = 'update-2',
  List<String> summaryIds = const <String>['update-1', 'update-2'],
  List<String> contributingSiteIds = const <String>['site-1', 'site-2'],
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'status': 'staged',
    'mergeStrategy': 'norm_capped_weighted_runtime_vector_average_v2',
    'triggerSummaryId': triggerSummaryId,
    'summaryIds': summaryIds,
    'packageFormat': 'runtime_vector_v1',
    'rolloutStatus': rolloutStatus,
    'modelVersion': 'fl_runtime_model_v1',
    'latestPromotionRecordId': '',
    'latestPromotionStatus': '',
    'latestPromotionRevocationRecordId': '',
    'latestPilotEvidenceRecordId': '',
    'latestPilotEvidenceStatus': '',
    'latestPilotApprovalRecordId': '',
    'latestPilotApprovalStatus': '',
    'latestPilotExecutionRecordId': '',
    'latestPilotExecutionStatus': '',
    'latestRuntimeDeliveryRecordId': '',
    'latestRuntimeDeliveryStatus': '',
    'packageDigest': 'sha256:pkg-${id.replaceAll('fl_pkg_', '')}',
    'boundedDigest': boundedDigest,
    'normCap': normCap,
    'effectiveTotalWeight': effectiveTotalWeight,
    'runtimeVectorLength': 8,
    'runtimeVector': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
    'runtimeVectorDigest':
        'sha256:runtime-digest-${id.replaceAll('fl_pkg_', '')}',
    'sampleCount': sampleCount,
    'summaryCount': summaryCount,
    'distinctSiteCount': distinctSiteCount,
    'contributionDetails': _contributionDetailRows(),
    'contributingSiteIds': contributingSiteIds,
    'schemaVersions': <String>['v1'],
    'runtimeTargets': <String>['flutter_mobile'],
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
  };
}

Map<String, dynamic> _pilotApprovalRecordRow({
  String id = 'fl_pilot_approval_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String status = 'pending',
  String notes = 'Awaiting bounded HQ pilot approval sign-off.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'experimentReviewRecordId':
        'fl_review_${experimentId.replaceAll('fl_exp_', '')}',
    'pilotEvidenceRecordId':
        'fl_pilot_${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'candidatePromotionRecordId':
        'fl_prom_${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'promotionTarget': 'sandbox_eval',
    'status': status,
    'notes': notes,
    'approvedBy': 'hq-1',
    'approvedAt': DateTime(2026, 3, 14, 16),
    'createdAt': DateTime(2026, 3, 14, 16),
    'updatedAt': DateTime(2026, 3, 14, 16),
  };
}

Map<String, dynamic> _pilotExecutionRecordRow({
  String id = 'fl_pilot_execution_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String status = 'planned',
  List<String> launchedSiteIds = const <String>['site1'],
  int sessionCount = 0,
  int learnerCount = 0,
  String notes =
      'Bounded pilot execution planning captured for the approved package.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'pilotApprovalRecordId':
        'fl_pilot_approval_${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'status': status,
    'launchedSiteIds': launchedSiteIds,
    'sessionCount': sessionCount,
    'learnerCount': learnerCount,
    'notes': notes,
    'recordedBy': 'hq-1',
    'recordedAt': DateTime(2026, 3, 14, 18),
    'createdAt': DateTime(2026, 3, 14, 18),
    'updatedAt': DateTime(2026, 3, 14, 18),
  };
}

Map<String, dynamic> _runtimeDeliveryRecordRow({
  String id = 'fl_delivery_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String status = 'assigned',
  String boundedDigest = 'sha256:digest-1',
  String triggerSummaryId = 'update-2',
  List<String> summaryIds = const <String>['update-1', 'update-2'],
  List<String> targetSiteIds = const <String>['site-1'],
  DateTime? expiresAt,
  DateTime? supersededAt,
  String? supersededBy,
  String? supersededByDeliveryRecordId,
  String? supersededByCandidateModelPackageId,
  String? supersessionReason,
  DateTime? revokedAt,
  String? revokedBy,
  String? revocationReason,
  String notes =
      'Bounded runtime-delivery manifest assigned to the approved pilot site.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'pilotExecutionRecordId':
        'fl_pilot_execution_${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'runtimeTarget': 'flutter_mobile',
    'targetSiteIds': targetSiteIds,
    'status': status,
    'packageDigest':
        'sha256:pkg-${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'boundedDigest': boundedDigest,
    'triggerSummaryId': triggerSummaryId,
    'summaryIds': summaryIds,
    'manifestDigest':
        'sha256:delivery-${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'expiresAt': expiresAt ?? DateTime(2026, 3, 21, 19),
    'supersededAt': supersededAt,
    'supersededBy': supersededBy,
    'supersededByDeliveryRecordId': supersededByDeliveryRecordId,
    'supersededByCandidateModelPackageId': supersededByCandidateModelPackageId,
    'supersessionReason': supersessionReason,
    'revokedAt': revokedAt,
    'revokedBy': revokedBy,
    'revocationReason': revocationReason,
    'notes': notes,
    'assignedBy': 'hq-1',
    'assignedAt': DateTime(2026, 3, 14, 19),
    'createdAt': DateTime(2026, 3, 14, 19),
    'updatedAt': DateTime(2026, 3, 14, 19),
  };
}

Map<String, dynamic> _runtimeActivationRecordRow({
  String id = 'fl_runtime_activation_1_site-1',
  String deliveryRecordId = 'fl_delivery_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String siteId = 'site-1',
  String status = 'resolved',
  String traceId = 'activation-trace-1',
  String notes = 'Site runtime resolved the bounded manifest assignment.',
}) {
  return <String, dynamic>{
    'id': id,
    'deliveryRecordId': deliveryRecordId,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'siteId': siteId,
    'runtimeTarget': 'flutter_mobile',
    'manifestDigest':
        'sha256:delivery-${candidateModelPackageId.replaceAll('fl_pkg_', '')}',
    'status': status,
    'traceId': traceId,
    'notes': notes,
    'reportedBy': 'site-admin-1',
    'reportedAt': DateTime(2026, 3, 14, 20),
    'createdAt': DateTime(2026, 3, 14, 20),
    'updatedAt': DateTime(2026, 3, 14, 20),
  };
}

Map<String, dynamic> _runtimeRolloutAlertRecordRow({
  String id = 'fl_rollout_alert_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String deliveryRecordId = 'fl_delivery_1',
  String status = 'active',
  int fallbackCount = 1,
  int pendingCount = 0,
  String notes = '',
  String? acknowledgedBy,
  DateTime? acknowledgedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'deliveryRecordId': deliveryRecordId,
    'status': status,
    'fallbackCount': fallbackCount,
    'pendingCount': pendingCount,
    'notes': notes,
    'acknowledgedBy': acknowledgedBy,
    'acknowledgedAt': acknowledgedAt,
    'createdAt': createdAt ?? DateTime(2026, 3, 14, 21),
    'updatedAt': updatedAt ?? DateTime(2026, 3, 14, 21),
  };
}

Map<String, dynamic> _runtimeRolloutEscalationRecordRow({
  String id = 'fl_rollout_escalation_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String deliveryRecordId = 'fl_delivery_1',
  String status = 'open',
  int fallbackCount = 1,
  int pendingCount = 0,
  String ownerUserId = 'hq-ops-1',
  String notes = '',
  DateTime? openedAt,
  DateTime? dueAt,
  String? resolvedBy,
  DateTime? resolvedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'deliveryRecordId': deliveryRecordId,
    'status': status,
    'fallbackCount': fallbackCount,
    'pendingCount': pendingCount,
    'openedAt': openedAt,
    'dueAt': dueAt,
    'ownerUserId': ownerUserId,
    'notes': notes,
    'resolvedBy': resolvedBy,
    'resolvedAt': resolvedAt,
    'createdAt': createdAt ?? DateTime(2026, 3, 14, 21, 30),
    'updatedAt': updatedAt ?? DateTime(2026, 3, 14, 21, 30),
  };
}

Map<String, dynamic> _runtimeRolloutEscalationHistoryRecordRow({
  String id = 'fl_rollout_escalation_history_1',
  String escalationRecordId = 'fl_rollout_escalation_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String deliveryRecordId = 'fl_delivery_1',
  String status = 'open',
  int fallbackCount = 1,
  int pendingCount = 0,
  String ownerUserId = 'hq-ops-1',
  String notes = '',
  DateTime? openedAt,
  DateTime? dueAt,
  String recordedBy = 'hq-1',
  DateTime? recordedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'escalationRecordId': escalationRecordId,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'deliveryRecordId': deliveryRecordId,
    'status': status,
    'fallbackCount': fallbackCount,
    'pendingCount': pendingCount,
    'openedAt': openedAt,
    'dueAt': dueAt,
    'ownerUserId': ownerUserId,
    'notes': notes,
    'recordedBy': recordedBy,
    'recordedAt': recordedAt ?? DateTime(2026, 3, 15, 10),
  };
}

Map<String, dynamic> _runtimeRolloutControlRecordRow({
  String id = 'fl_rollout_control_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String deliveryRecordId = 'fl_delivery_1',
  String mode = 'paused',
  String ownerUserId = 'hq-ops-3',
  String reason = 'Paused pending bounded verification.',
  DateTime? reviewByAt,
  String? releasedBy,
  DateTime? releasedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'deliveryRecordId': deliveryRecordId,
    'mode': mode,
    'ownerUserId': ownerUserId,
    'reason': reason,
    'reviewByAt': reviewByAt,
    'releasedBy': releasedBy,
    'releasedAt': releasedAt,
    'createdAt': createdAt ?? DateTime(2026, 3, 15, 10),
    'updatedAt': updatedAt ?? DateTime(2026, 3, 15, 10),
  };
}

Map<String, dynamic> _runtimeRolloutAuditEventRow({
  String id = 'audit-1',
  String action = 'federated_learning.runtime_rollout_alert_record.upsert',
  String collection = 'federatedLearningRuntimeRolloutAlertRecords',
  String documentId = 'fl_rollout_alert_1',
  int timestamp = 1773522000000,
  String userId = 'hq-1',
  Map<String, dynamic>? details,
}) {
  return <String, dynamic>{
    'id': id,
    'action': action,
    'collection': collection,
    'documentId': documentId,
    'timestamp': timestamp,
    'userId': userId,
    'details': details ??
        <String, dynamic>{
          'experimentId': 'fl_exp_literacy_pilot',
          'candidateModelPackageId': 'fl_pkg_1',
          'deliveryRecordId': 'fl_delivery_1',
          'status': 'acknowledged',
          'fallbackCount': 1,
          'pendingCount': 0,
        },
  };
}

Map<String, dynamic> _pilotEvidenceRecordRow({
  String id = 'fl_pilot_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String status = 'pending',
  bool sandboxEvalComplete = true,
  bool metricsSnapshotComplete = false,
  bool rollbackPlanVerified = true,
  String notes = 'Awaiting metrics snapshot review.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'status': status,
    'sandboxEvalComplete': sandboxEvalComplete,
    'metricsSnapshotComplete': metricsSnapshotComplete,
    'rollbackPlanVerified': rollbackPlanVerified,
    'notes': notes,
    'reviewedBy': 'hq-1',
    'reviewedAt': DateTime(2026, 3, 14, 15),
    'createdAt': DateTime(2026, 3, 14, 15),
    'updatedAt': DateTime(2026, 3, 14, 15),
  };
}

Map<String, dynamic> _promotionRecordRow({
  String id = 'fl_prom_1',
  String experimentId = 'fl_exp_literacy_pilot',
  String candidateModelPackageId = 'fl_pkg_1',
  String aggregationRunId = 'fl_agg_1',
  String mergeArtifactId = 'fl_merge_1',
  String packageDigest = 'sha256:pkg-1',
  String boundedDigest = 'sha256:digest-1',
  String status = 'approved_for_eval',
  String rationale = 'Ready for bounded sandbox evaluation.',
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'candidateModelPackageId': candidateModelPackageId,
    'aggregationRunId': aggregationRunId,
    'mergeArtifactId': mergeArtifactId,
    'packageDigest': packageDigest,
    'boundedDigest': boundedDigest,
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
  double normCap = 2.4,
  double effectiveTotalWeight = 17.6,
  String triggerSummaryId = 'update-2',
  List<String> summaryIds = const <String>['update-1', 'update-2'],
  List<String> contributingSiteIds = const <String>['site-1', 'site-2'],
}) {
  return <String, dynamic>{
    'id': id,
    'experimentId': experimentId,
    'aggregationRunId': aggregationRunId,
    'status': 'generated',
    'mergeStrategy': 'norm_capped_weighted_runtime_vector_average_v2',
    'normCap': normCap,
    'effectiveTotalWeight': effectiveTotalWeight,
    'triggerSummaryId': triggerSummaryId,
    'summaryIds': summaryIds,
    'boundedDigest': boundedDigest,
    'payloadFormat': 'runtime_vector_v1',
    'modelVersion': 'fl_runtime_model_v1',
    'runtimeVectorLength': 8,
    'runtimeVector': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
    'runtimeVectorDigest':
        'sha256:runtime-digest-${id.replaceAll('fl_merge_', '')}',
    'sampleCount': 24,
    'summaryCount': 2,
    'distinctSiteCount': 2,
    'contributionDetails': _contributionDetailRows(),
    'contributingSiteIds': contributingSiteIds,
    'schemaVersions': <String>['v1'],
    'runtimeTargets': <String>['flutter_mobile'],
    'maxVectorLength': 128,
    'totalPayloadBytes': 1792,
    'averageUpdateNorm': 1.35,
  };
}

List<Map<String, dynamic>> _contributionDetailRows() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'summaryId': 'update-1',
      'siteId': 'site-1',
      'sampleCount': 13,
      'payloadBytes': 896,
      'vectorLength': 8,
      'updateNorm': 1.1,
      'schemaVersion': 'v1',
      'runtimeTarget': 'flutter_mobile',
      'traceId': 'trace-1',
      'payloadDigest': 'sha256:update-1',
      'rawWeight': 13.0,
      'normScale': 1.0,
      'effectiveWeight': 13.0,
    },
    <String, dynamic>{
      'summaryId': 'update-2',
      'siteId': 'site-2',
      'sampleCount': 11,
      'payloadBytes': 896,
      'vectorLength': 8,
      'updateNorm': 2.8,
      'schemaVersion': 'v1',
      'runtimeTarget': 'flutter_mobile',
      'traceId': 'trace-2',
      'payloadDigest': 'sha256:update-2',
      'rawWeight': 11.0,
      'normScale': 0.857143,
      'effectiveWeight': 9.428573,
    },
  ];
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
      'candidateModelPackageId': 'fl_pkg_1',
      'candidateModelPackageStatus': 'staged',
      'candidateModelPackageFormat': 'runtime_vector_v1',
      'payloadFormat': 'runtime_vector_v1',
      'modelVersion': 'fl_runtime_model_v1',
      'runtimeVectorLength': 8,
      'runtimeVectorDigest': 'sha256:runtime-digest-1',
      'mergeStrategy': 'norm_capped_weighted_runtime_vector_average_v2',
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
      'mergeStrategy': 'norm_capped_weighted_runtime_vector_average_v2',
      'boundedDigest': 'sha256:digest-1',
      'payloadFormat': 'runtime_vector_v1',
      'modelVersion': 'fl_runtime_model_v1',
      'runtimeVectorLength': 8,
      'runtimeVector': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
      'runtimeVectorDigest': 'sha256:runtime-digest-1',
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
      'packageFormat': 'runtime_vector_v1',
      'rolloutStatus': 'not_distributed',
      'modelVersion': 'fl_runtime_model_v1',
      'packageDigest': 'sha256:pkg-1',
      'boundedDigest': 'sha256:digest-1',
      'runtimeVectorLength': 8,
      'runtimeVector': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
      'runtimeVectorDigest': 'sha256:runtime-digest-1',
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
    final FederatedLearningCandidatePromotionRecordRepository
        promotionRepository =
        FederatedLearningCandidatePromotionRecordRepository(
            firestore: firestore);
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
      'vectorSketch': <double>[1.0, 0.4, 0.8, 0.2, 0.1, 0.6, 0.3, 0.05],
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
      vectorLength: 8,
      vectorSketch: <double>[1.0, 0.3, 0.8, 0.2, 0.1, 0.4, 0.2, 0.05],
      payloadBytes: 768,
      updateNorm: 1.7,
      payloadDigest: 'digest-42',
      optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
      localEpochCount: 1,
      localStepCount: 12,
      trainingWindowSeconds: 45,
      warmStartPackageId: 'fl_pkg_1',
      warmStartDeliveryRecordId: 'fl_delivery_1',
      warmStartModelVersion: 'fl_runtime_model_v1',
      batteryState: 'charging',
      networkType: 'wifi',
    );

    expect(updateId, 'update-1');
    expect(bridge.recordedUpdates, hasLength(1));
    expect(bridge.recordedUpdates.single['siteId'], 'site-1');
    expect(
        bridge.recordedUpdates.single['experimentId'], 'fl_exp_literacy_pilot');
    expect(bridge.recordedUpdates.single['vectorSketch'], hasLength(8));
    expect(
      bridge.recordedUpdates.single['optimizerStrategy'],
      'bounded_runtime_vector_local_finetune_v1',
    );
  });

  test(
      'runtime package resolver resolves delivered payload and records activation',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNotNull);
    expect(package!.candidateModelPackageId, 'fl_pkg_1');
    expect(package.resolutionStatus, 'resolved');
    expect(package.runtimeVectorLength, 8);
    expect(package.runtimeVector, hasLength(8));
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'resolved');
  });

  test('runtime package resolver falls back when delivery is revoked',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'revoked',
          targetSiteIds: <String>['site-1'],
          revokedAt: DateTime(2026, 3, 14, 20, 45),
          revokedBy: 'hq-1',
          revocationReason: 'Rollback after bounded pilot regression.',
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNull);
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'fallback');
    expect(
      bridge.recordedRuntimeActivationSaves.single['deliveryRecordId'],
      'fl_delivery_1',
    );
  });

  test('runtime package resolver falls back when delivery is superseded',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'superseded',
          targetSiteIds: <String>['site-1'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededBy: 'hq-1',
          supersededByDeliveryRecordId: 'fl_delivery_2',
          supersededByCandidateModelPackageId: 'fl_pkg_2',
          supersessionReason:
              'Superseded by fl_delivery_2 for overlapping site cohort.',
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(rolloutStatus: 'retired'),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNull);
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'fallback');
    expect(
      bridge.recordedRuntimeActivationSaves.single['notes'],
      contains(
        'is superseded: Superseded by fl_delivery_2 for overlapping site cohort.',
      ),
    );
  });

  test('runtime package resolver falls back when rollout control is paused',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
      runtimeRolloutControlRecords: <Map<String, dynamic>>[
        _runtimeRolloutControlRecordRow(
          mode: 'paused',
          reason: 'Paused pending bounded verification.',
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNull);
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'fallback');
    expect(
      bridge.recordedRuntimeActivationSaves.single['notes'],
      contains('is paused: Paused pending bounded verification.'),
    );
  });

  test(
      'runtime package resolver falls back for unresolved site under restricted rollout control',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
      runtimeRolloutControlRecords: <Map<String, dynamic>>[
        _runtimeRolloutControlRecordRow(
          mode: 'restricted',
          reason: 'Restricted to previously activated pilot sites.',
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNull);
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'fallback');
    expect(
      bridge.recordedRuntimeActivationSaves.single['notes'],
      contains(
          'is restricted: Restricted to previously activated pilot sites.'),
    );
  });

  test(
      'runtime package resolver still resolves for previously activated site under restricted rollout control',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
      runtimeRolloutControlRecords: <Map<String, dynamic>>[
        _runtimeRolloutControlRecordRow(
          mode: 'restricted',
          reason: 'Restricted to previously activated pilot sites.',
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
    );
    final FederatedLearningRuntimePackageResolver resolver =
        FederatedLearningRuntimePackageResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      activationReporter: FederatedLearningRuntimeActivationReporter(
        appState: _buildSiteState(),
        workflowBridge: bridge,
      ),
    );

    final FederatedLearningResolvedRuntimePackageModel? package =
        await resolver.resolveActivePackage(
      runtimeTarget: 'flutter_mobile',
    );

    expect(package, isNotNull);
    expect(package!.resolutionStatus, 'resolved');
    expect(package.rolloutControlMode, 'restricted');
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'resolved');
  });

  test('runtime delivery resolver lists site-scoped bounded manifests',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_expired',
          status: 'active',
          targetSiteIds: <String>['site-1'],
          expiresAt: DateTime(2024, 3, 14, 19),
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_revoked_marker',
          status: 'active',
          targetSiteIds: <String>['site-1'],
          revokedAt: DateTime(2026, 3, 14, 20, 45),
          revokedBy: 'hq-1',
        ),
        _runtimeDeliveryRecordRow(
            status: 'active', targetSiteIds: <String>['site-1']),
      ],
    );
    final FederatedLearningRuntimeDeliveryResolver resolver =
        FederatedLearningRuntimeDeliveryResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
    );

    final List<FederatedLearningRuntimeDeliveryRecordModel> assignments =
        await resolver.listAssignments();
    final FederatedLearningRuntimeDeliveryRecordModel? latest =
        await resolver.resolveLatestAssignment(
      runtimeTarget: 'flutter_mobile',
    );

    expect(assignments, hasLength(1));
    expect(assignments.single.status, 'active');
    expect(assignments.single.targetSiteIds, <String>['site-1']);
    expect(latest, isNotNull);
    expect(latest!.candidateModelPackageId, 'fl_pkg_1');
  });

  test('site runtime delivery listing omits terminal manifests', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_expired',
          status: 'active',
          targetSiteIds: <String>['site-1'],
          expiresAt: DateTime(2024, 3, 14, 19),
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_revoked',
          status: 'active',
          targetSiteIds: <String>['site-1'],
          revokedAt: DateTime(2026, 3, 14, 20, 45),
          revokedBy: 'hq-1',
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_superseded',
          status: 'superseded',
          targetSiteIds: <String>['site-1'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_current',
          status: 'assigned',
          targetSiteIds: <String>['site-1'],
        ),
      ],
    );

    final List<Map<String, dynamic>> assignments =
        await bridge.listSiteFederatedLearningRuntimeDeliveryRecords(
      siteId: 'site-1',
    );

    expect(assignments, hasLength(1));
    expect(assignments.single['id'], 'fl_delivery_current');
  });

  test('runtime delivery save supersedes overlapping active delivery',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
        _candidatePackageRow(
          id: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
        ),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_1',
          candidateModelPackageId: 'fl_pkg_1',
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
    );

    final String? deliveryId =
        await bridge.upsertFederatedLearningRuntimeDeliveryRecord(
      <String, dynamic>{
        'candidateModelPackageId': 'fl_pkg_2',
        'status': 'active',
        'targetSiteIds': <String>['site-2', 'site-3'],
        'notes': 'Advance the bounded rollout to the next pilot cohort.',
      },
    );

    expect(deliveryId, 'fl_delivery_2');
    final List<Map<String, dynamic>> records =
        await bridge.listFederatedLearningRuntimeDeliveryRecords(
      experimentId: 'fl_exp_literacy_pilot',
    );
    final Map<String, dynamic> latest = records.firstWhere(
      (Map<String, dynamic> row) => row['id'] == 'fl_delivery_2',
    );
    final Map<String, dynamic> superseded = records.firstWhere(
      (Map<String, dynamic> row) => row['id'] == 'fl_delivery_1',
    );
    expect(latest['status'], 'active');
    expect(superseded['status'], 'superseded');
    expect(superseded['supersededByDeliveryRecordId'], 'fl_delivery_2');
    expect(
      superseded['supersessionReason'],
      'Superseded by fl_delivery_2 for overlapping site cohort.',
    );
    final Map<String, dynamic> supersededPackage = bridge._candidatePackages
        .firstWhere((Map<String, dynamic> row) => row['id'] == 'fl_pkg_1');
    final Map<String, dynamic> latestPackage = bridge._candidatePackages
        .firstWhere((Map<String, dynamic> row) => row['id'] == 'fl_pkg_2');
    expect(supersededPackage['rolloutStatus'], 'retired');
    expect(latestPackage['rolloutStatus'], 'distributed');

    final List<Map<String, dynamic>> siteAssignments =
        await bridge.listSiteFederatedLearningRuntimeDeliveryRecords(
      siteId: 'site-2',
    );
    expect(siteAssignments, hasLength(1));
    expect(siteAssignments.single['id'], 'fl_delivery_2');
  });

  test('runtime delivery revocation retires the candidate package', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeDeliveryRecord(
      <String, dynamic>{
        'candidateModelPackageId': 'fl_pkg_1',
        'status': 'revoked',
        'targetSiteIds': <String>['site-1'],
        'revocationReason': 'Rollback after bounded pilot regression.',
      },
    );

    final Map<String, dynamic> package = bridge._candidatePackages.firstWhere(
      (Map<String, dynamic> row) => row['id'] == 'fl_pkg_1',
    );
    expect(package['latestRuntimeDeliveryStatus'], 'revoked');
    expect(package['rolloutStatus'], 'retired');
  });

  test('runtime rollout escalation auto-resolves for terminal delivery',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'superseded',
          targetSiteIds: <String>['site-1', 'site-2'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
          supersededByCandidateModelPackageId: 'fl_pkg_2',
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeRolloutEscalationRecord(
      <String, dynamic>{
        'deliveryRecordId': 'fl_delivery_1',
        'status': 'investigating',
        'ownerUserId': 'hq-ops-9',
        'notes': 'Investigating stale rollout drift.',
      },
    );

    expect(bridge.recordedRuntimeRolloutEscalationSaves, isNotEmpty);
    final Map<String, dynamic> escalation =
        bridge.recordedRuntimeRolloutEscalationSaves.last;
    expect(escalation['status'], 'resolved');
    expect(escalation['fallbackCount'], 0);
    expect(escalation['pendingCount'], 1);
    expect(escalation['openedAt'], isNull);
    expect(escalation['dueAt'], isNull);
    expect(escalation['resolvedBy'], 'hq-1');
    expect(bridge._runtimeRolloutEscalationHistoryRecords.first['status'],
        'resolved');
  });

  test('runtime rollout escalation cannot remain resolved while issue is live',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
      runtimeRolloutEscalationRecords: <Map<String, dynamic>>[
        _runtimeRolloutEscalationRecordRow(
          status: 'investigating',
          ownerUserId: 'hq-ops-2',
          notes: 'Investigating site runtime mismatch.',
        ),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeRolloutEscalationRecord(
      <String, dynamic>{
        'deliveryRecordId': 'fl_delivery_1',
        'status': 'resolved',
        'ownerUserId': 'hq-ops-2',
        'notes': 'Attempted early closure.',
      },
    );

    expect(bridge.recordedRuntimeRolloutEscalationSaves, isNotEmpty);
    final Map<String, dynamic> escalation =
        bridge.recordedRuntimeRolloutEscalationSaves.last;
    expect(escalation['status'], 'investigating');
    expect(escalation['resolvedBy'], isNull);
    expect(escalation['resolvedAt'], isNull);
    expect(escalation['fallbackCount'], 1);
    expect(bridge._runtimeRolloutEscalationHistoryRecords.first['status'],
        'investigating');
  });

  test('runtime rollout control auto-releases for terminal delivery', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'revoked',
          targetSiteIds: <String>['site-1'],
          revokedAt: DateTime(2026, 3, 14, 20, 45),
          revokedBy: 'hq-1',
          revocationReason: 'Rollback after bounded pilot regression.',
        ),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeRolloutControlRecord(
      <String, dynamic>{
        'deliveryRecordId': 'fl_delivery_1',
        'mode': 'paused',
        'ownerUserId': 'hq-ops-3',
        'reason': 'Pause while delivery is rolled back.',
      },
    );

    expect(bridge.recordedRuntimeRolloutControlSaves, isNotEmpty);
    final Map<String, dynamic> control =
        bridge.recordedRuntimeRolloutControlSaves.last;
    expect(control['mode'], 'monitor');
    expect(control['ownerUserId'], isNull);
    expect(control['reason'], isNull);
    expect(control['releasedBy'], 'hq-1');
    expect(control['releasedAt'], isNotNull);
  });

  test('runtime rollout alert auto-acknowledges when issue clears', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeRolloutAlertRecord(
      <String, dynamic>{
        'deliveryRecordId': 'fl_delivery_1',
        'status': 'active',
        'notes': 'Healthy rollout snapshot.',
      },
    );

    expect(bridge.recordedRuntimeRolloutAlertSaves, isNotEmpty);
    final Map<String, dynamic> alert =
        bridge.recordedRuntimeRolloutAlertSaves.last;
    expect(alert['status'], 'acknowledged');
    expect(alert['fallbackCount'], 0);
    expect(alert['pendingCount'], 0);
    expect(alert['acknowledgedBy'], 'hq-1');
    expect(alert['acknowledgedAt'], isNotNull);
  });

  test('runtime rollout alert auto-acknowledges for terminal delivery',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'superseded',
          targetSiteIds: <String>['site-1', 'site-2'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
      ],
    );

    await bridge.upsertFederatedLearningRuntimeRolloutAlertRecord(
      <String, dynamic>{
        'deliveryRecordId': 'fl_delivery_1',
        'status': 'active',
        'notes': 'Stale alert should settle after supersession.',
      },
    );

    expect(bridge.recordedRuntimeRolloutAlertSaves, isNotEmpty);
    final Map<String, dynamic> alert =
        bridge.recordedRuntimeRolloutAlertSaves.last;
    expect(alert['status'], 'acknowledged');
    expect(alert['fallbackCount'], 0);
    expect(alert['pendingCount'], 1);
    expect(alert['acknowledgedBy'], 'hq-1');
  });

  test('runtime activation reporter records bounded site evidence', () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(),
      ],
    );
    final FederatedLearningRuntimeDeliveryResolver resolver =
        FederatedLearningRuntimeDeliveryResolver(
      appState: _buildSiteState(),
      workflowBridge: bridge,
    );
    final FederatedLearningRuntimeActivationReporter reporter =
        FederatedLearningRuntimeActivationReporter(
      appState: _buildSiteState(),
      workflowBridge: bridge,
      deliveryResolver: resolver,
    );

    final List<FederatedLearningRuntimeActivationRecordModel> existing =
        await reporter.listReports();
    final String? activationId =
        await reporter.reportLatestAssignmentActivation(
      runtimeTarget: 'flutter_mobile',
      status: 'staged',
      traceId: 'trace-99',
      notes: 'Prepared bounded runtime activation evidence.',
    );

    expect(existing, hasLength(1));
    expect(existing.single.status, 'resolved');
    expect(activationId, 'fl_runtime_activation_1_site-1');
    expect(bridge.recordedRuntimeActivationSaves, hasLength(1));
    expect(
      bridge.recordedRuntimeActivationSaves.single['deliveryRecordId'],
      'fl_delivery_1',
    );
    expect(bridge.recordedRuntimeActivationSaves.single['status'], 'staged');
    expect(bridge.recordedRuntimeActivationSaves.single['siteId'], 'site-1');
  });

  test('runtime adapter uploads bounded BOS summaries on real triggers',
      () async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[_experimentRow(status: 'active')],
      candidatePackages: <Map<String, dynamic>>[_candidatePackageRow()],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
      ],
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
    expect(
      bridge.recordedUpdates.single['optimizerStrategy'],
      'bounded_runtime_vector_local_finetune_v1',
    );
    expect(bridge.recordedUpdates.single['localEpochCount'], 1);
    expect(bridge.recordedUpdates.single['localStepCount'], 2);
    expect(
      bridge.recordedUpdates.single['warmStartPackageId'],
      'fl_pkg_1',
    );
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
          triggerSummaryId: 'update-4',
          summaryIds: <String>['update-3', 'update-4'],
          contributingSiteIds: <String>['site-3'],
          createdAt: DateTime(2026, 3, 13, 12),
        ),
        _aggregationRunRow(
          id: 'fl_agg_3',
          totalSampleCount: 18,
          summaryCount: 1,
          distinctSiteCount: 1,
          mergeArtifactId: '',
          boundedDigest: 'sha256:digest-3',
          triggerSummaryId: 'update-5',
          summaryIds: <String>['update-5'],
          createdAt: DateTime(2026, 3, 12, 12),
        ),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
        _mergeArtifactRow(
          id: 'fl_merge_2',
          aggregationRunId: 'fl_agg_2',
          boundedDigest: 'sha256:digest-2',
          triggerSummaryId: 'update-4',
          summaryIds: <String>['update-3', 'update-4'],
          contributingSiteIds: <String>['site-3'],
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
          triggerSummaryId: 'update-4',
          summaryIds: <String>['update-3', 'update-4'],
          contributingSiteIds: <String>['site-3'],
        ),
      ],
      pilotEvidenceRecords: <Map<String, dynamic>>[
        _pilotEvidenceRecordRow(),
      ],
      pilotApprovalRecords: <Map<String, dynamic>>[
        _pilotApprovalRecordRow(),
      ],
      pilotExecutionRecords: <Map<String, dynamic>>[
        _pilotExecutionRecordRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(status: 'assigned'),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(status: 'resolved'),
      ],
      promotionRecords: <Map<String, dynamic>>[
        _promotionRecordRow(),
      ],
    );
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    final FederatedLearningUpdateSummaryRepository summaryRepository =
        FederatedLearningUpdateSummaryRepository(firestore: firestore);
    await firestore
        .collection('federatedLearningUpdateSummaries')
        .doc('update-1')
        .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'siteId': 'site-1',
      'traceId': 'trace-1',
      'schemaVersion': 'v1',
      'sampleCount': 13,
      'vectorLength': 128,
      'payloadBytes': 920,
      'updateNorm': 2.1,
      'payloadDigest': 'sha256:update-1',
      'optimizerStrategy': 'bounded_runtime_vector_local_finetune_v1',
      'localEpochCount': 1,
      'localStepCount': 13,
      'trainingWindowSeconds': 75,
      'warmStartPackageId': 'fl_pkg_1',
      'warmStartDeliveryRecordId': 'fl_delivery_1',
      'warmStartModelVersion': 'fl_runtime_model_v1',
      'batteryState': 'charging',
      'networkType': 'wifi',
      'createdAt': DateTime(2026, 3, 14, 10),
    });
    await firestore
        .collection('federatedLearningUpdateSummaries')
        .doc('update-2')
        .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'siteId': 'site-2',
      'traceId': 'trace-2',
      'schemaVersion': 'v1',
      'sampleCount': 11,
      'vectorLength': 128,
      'payloadBytes': 940,
      'updateNorm': 2.3,
      'payloadDigest': 'sha256:update-2',
      'optimizerStrategy': 'bounded_runtime_vector_local_finetune_v1',
      'localEpochCount': 1,
      'localStepCount': 11,
      'trainingWindowSeconds': 60,
      'warmStartPackageId': 'fl_pkg_1',
      'warmStartDeliveryRecordId': 'fl_delivery_1',
      'warmStartModelVersion': 'fl_runtime_model_v1',
      'batteryState': 'battery',
      'networkType': 'cellular',
      'createdAt': DateTime(2026, 3, 14, 11),
    });
    await firestore
        .collection('federatedLearningUpdateSummaries')
        .doc('update-3')
        .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'siteId': 'site-3',
      'traceId': 'trace-3',
      'schemaVersion': 'v1',
      'sampleCount': 9,
      'vectorLength': 128,
      'payloadBytes': 880,
      'updateNorm': 2.2,
      'payloadDigest': 'sha256:update-3',
      'batteryState': 'charging',
      'networkType': 'wifi',
      'createdAt': DateTime(2026, 3, 13, 10),
    });
    await firestore
        .collection('federatedLearningUpdateSummaries')
        .doc('update-4')
        .set(<String, dynamic>{
      'experimentId': 'fl_exp_literacy_pilot',
      'siteId': 'site-4',
      'traceId': 'trace-4',
      'schemaVersion': 'v1',
      'sampleCount': 11,
      'vectorLength': 128,
      'payloadBytes': 910,
      'updateNorm': 2.5,
      'payloadDigest': 'sha256:update-4',
      'batteryState': 'charging',
      'networkType': 'wifi',
      'createdAt': DateTime(2026, 3, 13, 11),
    });

    await tester.pumpWidget(
      _wrapWithMaterial(
        HqFeatureFlagsPage(
          workflowBridge: bridge,
          updateSummaryRepository: summaryRepository,
        ),
      ),
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
    expect(
      find.text('Latest aggregation contributors: site-1, site-2'),
      findsOneWidget,
    );
    expect(find.text('Recent aggregation runs'), findsOneWidget);
    expect(find.textContaining('Runtime activation: resolved'), findsOneWidget);
    expect(
        find.textContaining('Runtime lifecycle: live until'), findsOneWidget);
    expect(
      find.text('Site rollout: 1 resolved · 0 staged · 0 fallback · 0 pending'),
      findsOneWidget,
    );
    expect(
      find.text('Artifact generated: fl_merge_1'),
      findsWidgets,
    );
    expect(
      find.text('Latest candidate package: fl_pkg_1 (runtime_vector_v1)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Latest package merge: norm_capped_weighted_runtime_vector_average_v2 · norm cap 2.400 · effective weight 17.600',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Latest aggregation damping: Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Latest package damping: Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsOneWidget,
    );
    expect(
        find.text('Latest package rollout: not_distributed'), findsOneWidget);
    expect(
      find.text('Latest package promotion: approved_for_eval (sandbox_eval)'),
      findsOneWidget,
    );
    expect(find.text('Review status: pending'), findsOneWidget);
    expect(
      find.text(
        'Pilot evidence: pending · sandbox eval done · metrics open · rollback verified',
      ),
      findsOneWidget,
    );
    expect(find.text('Pilot approval: pending (sandbox_eval)'), findsOneWidget);
    expect(
        find.text(
            'Pilot execution: planned · 1 sites · 0 sessions · 0 learners'),
        findsOneWidget);
    expect(find.text('Runtime delivery: assigned · 1 sites · flutter_mobile'),
        findsOneWidget);
    expect(
        find.text(
            'Runtime activation: resolved · 1 site reports · flutter_mobile'),
        findsOneWidget);

    final Finder activationHistoryButton = find.widgetWithText(
      TextButton,
      'Activation history',
    );
    await tester.ensureVisible(activationHistoryButton.first);
    final TextButton activationHistoryControl = tester.widget<TextButton>(
      activationHistoryButton.first,
    );
    activationHistoryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime activation history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.text('Summary: 1 resolved · 0 staged · 0 fallback'),
      findsOneWidget,
    );
    expect(find.text('site-1 · resolved · flutter_mobile'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    final Finder reviewChecklistButton = find.widgetWithText(
      TextButton,
      'Review checklist',
    );
    await tester.ensureVisible(reviewChecklistButton.first);
    final TextButton reviewChecklistControl = tester.widget<TextButton>(
      reviewChecklistButton.first,
    );
    reviewChecklistControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Experiment review checklist'), findsOneWidget);
    final Finder reviewStatusDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Review status',
    );
    await tester.tap(reviewStatusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('approved').last);
    await tester.pumpAndSettle();

    final CheckboxListTile privacyReviewTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Privacy review complete'),
    );
    privacyReviewTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    final CheckboxListTile signoffChecklistTile =
        tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Sign-off checklist complete'),
    );
    signoffChecklistTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    final CheckboxListTile rolloutRiskTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Rollout risk acknowledged'),
    );
    rolloutRiskTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Review notes'),
      'Privacy review and sign-off checklist complete for bounded pilot gating.',
    );
    final Finder saveReviewButton = find.widgetWithText(
      FilledButton,
      'Save review',
    );
    final FilledButton saveReviewControl = tester.widget<FilledButton>(
      saveReviewButton,
    );
    saveReviewControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedExperimentReviewSaves, hasLength(1));
    expect(
      bridge.recordedExperimentReviewSaves.single['experimentId'],
      'fl_exp_literacy_pilot',
    );
    expect(
      bridge.recordedExperimentReviewSaves.single['status'],
      'approved',
    );
    expect(find.text('Review status: approved'), findsOneWidget);
    expect(
      find.text(
        'Checklist: privacy done · sign-off done · rollout risk acknowledged',
      ),
      findsOneWidget,
    );

    final Finder pilotEvidenceButton = find.widgetWithText(
      TextButton,
      'Pilot evidence',
    );
    await tester.ensureVisible(pilotEvidenceButton.first);
    final TextButton pilotEvidenceControl = tester.widget<TextButton>(
      pilotEvidenceButton.first,
    );
    pilotEvidenceControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Pilot evidence checklist'), findsOneWidget);
    final Finder pilotEvidenceDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Evidence status',
    );
    await tester.tap(pilotEvidenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ready_for_pilot').last);
    await tester.pumpAndSettle();

    final CheckboxListTile sandboxEvalTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Sandbox eval complete'),
    );
    sandboxEvalTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    final CheckboxListTile metricsSnapshotTile =
        tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Metrics snapshot reviewed'),
    );
    metricsSnapshotTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    final CheckboxListTile rollbackPlanTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Rollback plan verified'),
    );
    rollbackPlanTile.onChanged?.call(true);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pilot evidence notes'),
      'Sandbox eval metrics and rollback readiness reviewed for bounded pilot evidence.',
    );
    final Finder saveEvidenceButton = find.widgetWithText(
      FilledButton,
      'Save evidence',
    );
    final FilledButton saveEvidenceControl = tester.widget<FilledButton>(
      saveEvidenceButton,
    );
    saveEvidenceControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedPilotEvidenceSaves, hasLength(1));
    expect(
      bridge.recordedPilotEvidenceSaves.single['candidateModelPackageId'],
      'fl_pkg_1',
    );
    expect(
      bridge.recordedPilotEvidenceSaves.single['status'],
      'ready_for_pilot',
    );
    expect(
      find.text(
        'Pilot evidence: ready_for_pilot · sandbox eval done · metrics done · rollback verified',
      ),
      findsOneWidget,
    );

    final Finder pilotApprovalButton = find.widgetWithText(
      TextButton,
      'Pilot approval',
    );
    await tester.ensureVisible(pilotApprovalButton.first);
    final TextButton pilotApprovalControl = tester.widget<TextButton>(
      pilotApprovalButton.first,
    );
    pilotApprovalControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Pilot approval record'), findsOneWidget);
    final Finder approvalStatusDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Approval status',
    );
    await tester.tap(approvalStatusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('approved').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pilot approval notes'),
      'Approved for the bounded HQ pilot gate after review, evidence, and eval checks aligned.',
    );
    final Finder saveApprovalButton = find.widgetWithText(
      FilledButton,
      'Save approval',
    );
    final FilledButton saveApprovalControl = tester.widget<FilledButton>(
      saveApprovalButton,
    );
    saveApprovalControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedPilotApprovalSaves, hasLength(1));
    expect(
      bridge.recordedPilotApprovalSaves.single['candidateModelPackageId'],
      'fl_pkg_1',
    );
    expect(
      bridge.recordedPilotApprovalSaves.single['status'],
      'approved',
    );
    expect(
        find.text('Pilot approval: approved (sandbox_eval)'), findsOneWidget);

    final Finder pilotExecutionButton = find.widgetWithText(
      TextButton,
      'Pilot execution',
    );
    await tester.ensureVisible(pilotExecutionButton.first);
    final TextButton pilotExecutionControl = tester.widget<TextButton>(
      pilotExecutionButton.first,
    );
    pilotExecutionControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Pilot execution record'), findsOneWidget);
    final Finder executionStatusDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Execution status',
    );
    await tester.tap(executionStatusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('observed').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Launched site IDs'),
      'site1, site2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Session count'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Learner count'),
      '42',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pilot execution notes'),
      'Observed bounded pilot execution across both approved literacy sites.',
    );
    final Finder saveExecutionButton = find.widgetWithText(
      FilledButton,
      'Save execution',
    );
    final FilledButton saveExecutionControl = tester.widget<FilledButton>(
      saveExecutionButton,
    );
    saveExecutionControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedPilotExecutionSaves, hasLength(1));
    expect(
      bridge.recordedPilotExecutionSaves.single['candidateModelPackageId'],
      'fl_pkg_1',
    );
    expect(
      bridge.recordedPilotExecutionSaves.single['status'],
      'observed',
    );
    expect(
      bridge.recordedPilotExecutionSaves.single['launchedSiteIds'],
      <String>['site1', 'site2'],
    );
    expect(
      find.text(
          'Pilot execution: observed · 2 sites · 6 sessions · 42 learners'),
      findsOneWidget,
    );

    final Finder runtimeDeliveryButton = find.widgetWithText(
      TextButton,
      'Runtime delivery',
    );
    await tester.ensureVisible(runtimeDeliveryButton.first);
    final TextButton runtimeDeliveryControl = tester.widget<TextButton>(
      runtimeDeliveryButton.first,
    );
    runtimeDeliveryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.text('Runtime delivery record'), findsOneWidget);
    final Finder runtimeDeliveryStatusDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Delivery status',
    );
    await tester.tap(runtimeDeliveryStatusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('active').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Target site IDs'),
      'site-1, site-2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Runtime delivery notes'),
      'Assigned the bounded runtime manifest to the approved literacy pilot cohort.',
    );
    final Finder saveDeliveryButton = find.widgetWithText(
      FilledButton,
      'Save delivery',
    );
    final FilledButton saveDeliveryControl = tester.widget<FilledButton>(
      saveDeliveryButton,
    );
    saveDeliveryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(bridge.recordedRuntimeDeliverySaves, hasLength(1));
    expect(
      bridge.recordedRuntimeDeliverySaves.single['candidateModelPackageId'],
      'fl_pkg_1',
    );
    expect(
      bridge.recordedRuntimeDeliverySaves.single['status'],
      'active',
    );
    expect(
      bridge.recordedRuntimeDeliverySaves.single['targetSiteIds'],
      <String>['site-1', 'site-2'],
    );
    expect(
      find.text('Runtime delivery: active · 2 sites · flutter_mobile'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Rollout alert: 1 pending site statuses need review. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );

    final Finder deliveryHistoryButton = find.widgetWithText(
      TextButton,
      'Delivery history',
    );
    await tester.ensureVisible(deliveryHistoryButton.first);
    final TextButton deliveryHistoryControl = tester.widget<TextButton>(
      deliveryHistoryButton.first,
    );
    deliveryHistoryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime delivery history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(find.textContaining('Lifecycle: live until'), findsOneWidget);
    expect(
      find.textContaining('Aggregation run: fl_agg_1'),
      findsOneWidget,
    );
    expect(
      find.text('Delivery digests: package sha256:pkg-1 · bounded sha256:digest-1'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsOneWidget,
    );
    expect(find.text('Trigger summary: update-2'), findsOneWidget);
    expect(find.text('Accepted summaries: update-1, update-2'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Open accepted summaries'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open trigger summary'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open contribution details'),
      findsOneWidget,
    );
    final Finder deliveryTraceButton = find.widgetWithText(
      OutlinedButton,
      'Open aggregation run',
    );
    await tester.ensureVisible(deliveryTraceButton.first);
    await tester.tap(deliveryTraceButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Aggregation history: Literacy Pilot'), findsOneWidget);
    expect(find.text('Artifact: fl_merge_1'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    final Finder deliverySummaryButton = find.widgetWithText(
      OutlinedButton,
      'Open accepted summaries',
    );
    await tester.ensureVisible(deliverySummaryButton.first);
    await tester.tap(deliverySummaryButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Requested summaries: update-1, update-2'), findsOneWidget);
    expect(find.text('Summary update-1 · site site-1 · 13 samples'),
        findsOneWidget);
    expect(
      find.text(
        'Local training: bounded_runtime_vector_local_finetune_v1 · epochs 1 · steps 13 · window 75s',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Warm start: package fl_pkg_1 · delivery fl_delivery_1 · model fl_runtime_model_v1',
      ),
      findsWidgets,
    );
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    final Finder deliveryTriggerButton = find.widgetWithText(
      OutlinedButton,
      'Open trigger summary',
    );
    await tester.ensureVisible(deliveryTriggerButton.first);
    await tester.tap(deliveryTriggerButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Requested summaries: update-2'), findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    final Finder deliveryContributionButton = find.widgetWithText(
      OutlinedButton,
      'Open contribution details',
    );
    await tester.ensureVisible(deliveryContributionButton.first);
    await tester.tap(deliveryContributionButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Contribution details: Literacy Pilot'), findsOneWidget);
    expect(find.text('Contribution rows: 2'), findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    expect(
      find.text('Trace: trace-2 · Digest: sha256:update-2'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    final Finder siteRolloutButton = find.widgetWithText(
      TextButton,
      'Site rollout',
    );
    await tester.ensureVisible(siteRolloutButton.first);
    final TextButton siteRolloutControl = tester.widget<TextButton>(
      siteRolloutButton.first,
    );
    siteRolloutControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime rollout health: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.text('Summary: 1 resolved · 0 staged · 0 fallback · 1 pending'),
      findsOneWidget,
    );
    expect(find.text('site-1 · resolved'), findsOneWidget);
    expect(find.text('site-2 · pending'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    final Finder viewHistoryButton = find.widgetWithText(
      TextButton,
      'View history',
    );
    await tester.ensureVisible(viewHistoryButton.first);
    final TextButton viewHistoryControl = tester.widget<TextButton>(
      viewHistoryButton.first,
    );
    viewHistoryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Aggregation history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        TextField,
        'Filter by run ID, summary ID, artifact ID, digest, or site ID',
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
      find.text('Strategy: norm_capped_weighted_runtime_vector_average_v2'),
      findsWidgets,
    );
    expect(
      find.text('Norm cap: 2.400 · Effective weight: 17.600'),
      findsWidgets,
    );
    expect(
      find.text(
        'Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsWidgets,
    );
    expect(find.text('Trigger summary: update-2'), findsWidgets);
    expect(find.text('Accepted summaries: update-1, update-2'), findsWidgets);
    expect(find.text('Contributor sites: site-1, site-2'), findsWidgets);
    expect(find.text('Digest: sha256:digest-1'), findsWidgets);
    expect(find.text('Artifact: fl_merge_1'), findsWidgets);
    expect(find.text('Package: fl_pkg_1'), findsWidgets);
    expect(
      find.widgetWithText(OutlinedButton, 'Open accepted summaries'),
      findsWidgets,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open contribution details'),
      findsWidgets,
    );
    expect(
      find.text('Package format: runtime_vector_v1'),
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

    final Finder aggregationSummaryButton = find.widgetWithText(
      OutlinedButton,
      'Open accepted summaries',
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open trigger summary'),
      findsWidgets,
    );
    final Finder aggregationTriggerButton = find.widgetWithText(
      OutlinedButton,
      'Open trigger summary',
    );
    await tester.ensureVisible(aggregationTriggerButton.first);
    await tester.tap(aggregationTriggerButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Requested summaries: update-2'), findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    expect(
        find.text('Trace: trace-2 · Digest: sha256:update-2'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    final Finder aggregationContributionButton = find.widgetWithText(
      OutlinedButton,
      'Open contribution details',
    );
    await tester.ensureVisible(aggregationContributionButton.first);
    await tester.tap(aggregationContributionButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Contribution details: Literacy Pilot'), findsOneWidget);
    expect(find.text('Contribution rows: 2'), findsOneWidget);
    expect(find.text('Summary update-1 · site site-1 · 13 samples'),
        findsOneWidget);
    expect(
      find.textContaining('Raw weight: 13 · Norm scale: 1 · Effective weight: 13'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(aggregationSummaryButton.first);
    await tester.tap(aggregationSummaryButton.first);
    await tester.pumpAndSettle();
    expect(
        find.text('Requested summaries: update-1, update-2'), findsOneWidget);
    expect(find.text('Summary update-1 · site site-1 · 13 samples'),
        findsOneWidget);
    expect(
      find.text(
        'Local training: bounded_runtime_vector_local_finetune_v1 · epochs 1 · steps 13 · window 75s',
      ),
      findsOneWidget,
    );
    expect(
        find.text('Trace: trace-1 · Digest: sha256:update-1'), findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    expect(
        find.text('Trace: trace-2 · Digest: sha256:update-2'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
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
        'Filter by package ID, artifact ID, trigger or summary ID, digest, or site ID',
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
    expect(
      find.text('Strategy: norm_capped_weighted_runtime_vector_average_v2'),
      findsWidgets,
    );
    expect(
      find.text('Norm cap: 2.400 · Effective weight: 17.600'),
      findsWidgets,
    );
    expect(
      find.text(
        'Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsWidgets,
    );
    expect(find.text('Contributor sites: site-1, site-2'), findsWidgets);
    expect(find.text('Trigger summary: update-2'), findsWidgets);
    expect(find.text('Accepted summaries: update-1, update-2'), findsWidgets);
    expect(find.text('Promotion: approved_for_eval (sandbox_eval)'),
        findsOneWidget);
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
    expect(
      bridge.recordedPromotionDecisions.single['packageDigest'],
      'sha256:pkg-2',
    );
    expect(
      bridge.recordedPromotionDecisions.single['boundedDigest'],
      'sha256:digest-2',
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
        'Filter by package ID, artifact ID, trigger or summary ID, digest, or site ID',
      ),
      'site-3',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Package fl_pkg_2 · 20 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, trigger or summary ID, digest, or site ID',
      ),
      '',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, trigger or summary ID, digest, or site ID',
      ),
      'sha256:update-2',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Package fl_pkg_1 · 24 samples · 2 summaries · 2 sites'),
      findsOneWidget,
    );
    expect(find.text('Showing 1-1 of 1'), findsOneWidget);
    expect(
      find.text(
          'Decision digests: package sha256:pkg-1 · bounded sha256:digest-1'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open accepted summaries'),
      findsWidgets,
    );
    final Finder packageTraceButton = find.widgetWithText(
      OutlinedButton,
      'Open aggregation run',
    );
    await tester.ensureVisible(packageTraceButton.first);
    await tester.tap(packageTraceButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Aggregation history: Literacy Pilot'), findsOneWidget);
    expect(find.text('Artifact: fl_merge_1'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    final Finder packageSummaryButton = find.widgetWithText(
      OutlinedButton,
      'Open accepted summaries',
    );
    await tester.ensureVisible(packageSummaryButton.first);
    await tester.tap(packageSummaryButton.first);
    await tester.pumpAndSettle();
    expect(
        find.text('Requested summaries: update-1, update-2'), findsOneWidget);
    expect(find.text('Summary update-1 · site site-1 · 13 samples'),
        findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

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
        'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, or site ID',
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
      find.text('Strategy: norm_capped_weighted_runtime_vector_average_v2'),
      findsWidgets,
    );
    expect(
      find.text('Norm cap: 2.400 · Effective weight: 17.600'),
      findsWidgets,
    );
    expect(
      find.text(
        'Damping: 1 of 2 summaries scaled · raw weight 24 · effective weight 22.429',
      ),
      findsWidgets,
    );
    expect(find.text('Contributor sites: site-1, site-2'), findsWidgets);
    expect(find.text('Trigger summary: update-2'), findsWidgets);
    expect(find.text('Accepted summaries: update-1, update-2'), findsWidgets);
    expect(
      find.text('Decision fl_prom_2 · hold (sandbox_eval)'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Decision digests: package sha256:pkg-1 · bounded sha256:digest-1'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Open accepted summaries'),
      findsWidgets,
    );

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, or site ID',
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
    final Finder promotionTraceButton = find.widgetWithText(
      OutlinedButton,
      'Open aggregation run',
    );
    await tester.ensureVisible(promotionTraceButton.first);
    await tester.tap(promotionTraceButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Aggregation history: Literacy Pilot'), findsOneWidget);
    expect(find.text('Artifact: fl_merge_1'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

    final Finder promotionSummaryButton = find.widgetWithText(
      OutlinedButton,
      'Open accepted summaries',
    );
    await tester.ensureVisible(promotionSummaryButton.first);
    await tester.tap(promotionSummaryButton.first);
    await tester.pumpAndSettle();
    expect(
        find.text('Requested summaries: update-1, update-2'), findsOneWidget);
    expect(find.text('Summary update-1 · site site-1 · 13 samples'),
        findsOneWidget);
    expect(find.text('Summary update-2 · site site-2 · 11 samples'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close').last);
    await tester.pumpAndSettle();

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
    expect(
      bridge.recordedPromotionRevocations.single['packageDigest'],
      'sha256:pkg-1',
    );
    expect(
      bridge.recordedPromotionRevocations.single['boundedDigest'],
      'sha256:digest-1',
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
      find.text(
          'Revocation: fl_prom_revoke_1 · revoked approved_for_eval · 2026-03-14T14:00:00.000'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Rollback rationale: Sandbox regression exceeded the bounded threshold.'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Revocation digests: package sha256:pkg-1 · bounded sha256:digest-1'),
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
        'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, or site ID',
      ),
      'site-3',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Decision fl_prom_2 · hold (sandbox_eval)'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, or site ID',
      ),
      '',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Filter by package ID, artifact ID, decision ID, trigger or summary ID, rationale, or site ID',
      ),
      'trace-2',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Decision fl_prom_1 · revoked (sandbox_eval)'),
      findsOneWidget,
    );
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

  testWidgets('HQ delivery history shows superseded lifecycle detail',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(
          id: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          createdAt: DateTime(2026, 3, 14, 13),
        ),
        _aggregationRunRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(
          id: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          rolloutStatus: 'distributed',
        ),
        _candidatePackageRow(rolloutStatus: 'retired'),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_2',
          candidateModelPackageId: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          status: 'active',
          targetSiteIds: <String>['site-2', 'site-3'],
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_1',
          status: 'superseded',
          targetSiteIds: <String>['site-1', 'site-2'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
          supersededByCandidateModelPackageId: 'fl_pkg_2',
          supersessionReason:
              'Superseded by fl_delivery_2 for overlapping site cohort.',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder deliveryHistoryButton = find.widgetWithText(
      TextButton,
      'Delivery history',
    );
    await tester.ensureVisible(deliveryHistoryButton.first);
    tester.widget<TextButton>(deliveryHistoryButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime delivery history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(find.text('Latest package rollout: distributed'), findsOneWidget);
    expect(
      find.textContaining('Lifecycle: superseded 2026-03-14T20:15:00.000'),
      findsOneWidget,
    );
    expect(find.textContaining('by fl_delivery_2'), findsOneWidget);
  });

  testWidgets('HQ delivery history shows expired lifecycle detail',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
          expiresAt: DateTime(2024, 3, 14, 20, 15),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Runtime lifecycle: expired 2024-03-14T20:15:00.000'),
      findsOneWidget,
    );
    expect(find.text('Runtime activation: pending'), findsNothing);
    expect(
      find.textContaining(
          'Runtime activation: none recorded · expired 2024-03-14T20:15:00.000'),
      findsOneWidget,
    );

    final Finder deliveryHistoryButton = find.widgetWithText(
      TextButton,
      'Delivery history',
    );
    await tester.ensureVisible(deliveryHistoryButton.first);
    tester.widget<TextButton>(deliveryHistoryButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Lifecycle: expired 2024-03-14T20:15:00.000'),
      findsOneWidget,
    );
  });

  testWidgets('HQ delivery history shows revoked lifecycle detail',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'revoked',
          targetSiteIds: <String>['site-1', 'site-2'],
          revokedAt: DateTime(2026, 3, 14, 20, 45),
          revokedBy: 'hq-1',
          revocationReason: 'Rollback after bounded pilot regression.',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Runtime lifecycle: revoked 2026-03-14T20:45:00.000'),
      findsOneWidget,
    );
    expect(find.textContaining('by hq-1'), findsWidgets);
    expect(
      find.textContaining('Rollback after bounded pilot regression.'),
      findsWidgets,
    );

    final Finder deliveryHistoryButton = find.widgetWithText(
      TextButton,
      'Delivery history',
    );
    await tester.ensureVisible(deliveryHistoryButton.first);
    tester.widget<TextButton>(deliveryHistoryButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Lifecycle: revoked 2026-03-14T20:45:00.000'),
      findsOneWidget,
    );
    expect(find.textContaining('by hq-1'), findsWidgets);
    expect(
      find.textContaining('Rollback after bounded pilot regression.'),
      findsWidgets,
    );
  });

  testWidgets('HQ page highlights runtime rollout fallback alerts',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
          traceId: 'fallback-trace-2',
          notes: 'Site requested fallback after bounded runtime mismatch.',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Rollout alert: 1 fallback site statuses need review. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Site rollout: 1 resolved · 0 staged · 1 fallback · 0 pending'),
      findsOneWidget,
    );

    final Finder siteRolloutButton = find.widgetWithText(
      TextButton,
      'Site rollout',
    );
    await tester.ensureVisible(siteRolloutButton.first);
    final TextButton siteRolloutControl = tester.widget<TextButton>(
      siteRolloutButton.first,
    );
    siteRolloutControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Summary: 1 resolved · 0 staged · 1 fallback · 0 pending'),
      findsOneWidget,
    );
    expect(find.text('site-2 · fallback'), findsOneWidget);
    expect(find.text('Latest site report requested fallback.'), findsOneWidget);
  });

  testWidgets('HQ page suppresses active rollout alert for superseded delivery',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'superseded',
          targetSiteIds: <String>['site-1', 'site-2'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
          supersessionReason:
              'Superseded by fl_delivery_2 for overlapping site cohort.',
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(
          status: 'acknowledged',
          fallbackCount: 0,
          pendingCount: 1,
          notes: 'Legacy alert should not stay active on superseded delivery.',
          acknowledgedBy: 'hq-1',
          acknowledgedAt: DateTime(2026, 3, 14, 21),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Rollout alert: 1 fallback site statuses need review. Use Site rollout for detail.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Rollout alert acknowledged: 1 pending site statuses reviewed. Use Site rollout for detail.',
      ),
      findsNothing,
    );
    expect(
      find.text('Site rollout: 0 resolved · 0 staged · 2 fallback · 0 pending'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Acknowledge alert'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Update triage'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Escalate alert'), findsNothing);
    expect(
      find.textContaining(
          'Superseded by fl_delivery_2 for overlapping site cohort.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'HQ page does not show pending activation for superseded delivery without site reports',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'superseded',
          targetSiteIds: <String>['site-1', 'site-2'],
          supersededAt: DateTime(2026, 3, 14, 20, 15),
          supersededByDeliveryRecordId: 'fl_delivery_2',
          supersessionReason:
              'Superseded by fl_delivery_2 for overlapping site cohort.',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime activation: pending'), findsNothing);
    expect(
      find.textContaining('Runtime activation: none recorded · superseded'),
      findsOneWidget,
    );
    expect(
      find.text('Site rollout: 0 resolved · 0 staged · 2 fallback · 0 pending'),
      findsOneWidget,
    );
  });

  testWidgets('HQ page shows acknowledged rollout alert triage',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(
          id: 'fl_rollout_alert_1',
          deliveryRecordId: 'fl_delivery_1',
          status: 'acknowledged',
          notes: 'Reviewed with site ops and monitoring in place.',
          acknowledgedBy: 'hq-1',
          acknowledgedAt: DateTime(2026, 3, 14, 21),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Rollout alert acknowledged: 1 fallback site statuses reviewed. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('HQ notes: Reviewed with site ops and monitoring in place.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Update triage'), findsOneWidget);
  });

  testWidgets('HQ page shows runtime rollout alert history',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(
          status: 'acknowledged',
          notes: 'Reviewed with site ops and monitoring in place.',
          acknowledgedBy: 'hq-1',
          acknowledgedAt: DateTime(2026, 3, 14, 21),
        ),
      ],
      runtimeRolloutEscalationRecords: <Map<String, dynamic>>[
        _runtimeRolloutEscalationRecordRow(
          status: 'investigating',
          ownerUserId: 'hq-ops-1',
          notes: 'Investigating bounded runtime mismatch.',
          openedAt: DateTime(2020, 3, 15, 2),
          dueAt: DateTime(2020, 3, 15, 9),
        ),
      ],
      runtimeRolloutEscalationHistoryRecords: <Map<String, dynamic>>[
        _runtimeRolloutEscalationHistoryRecordRow(
          status: 'investigating',
          ownerUserId: 'hq-ops-1',
          notes: 'Investigating bounded runtime mismatch.',
          openedAt: DateTime(2020, 3, 15, 2),
          dueAt: DateTime(2020, 3, 15, 9),
        ),
        _runtimeRolloutEscalationHistoryRecordRow(
          id: 'fl_rollout_escalation_history_2',
          status: 'open',
          ownerUserId: 'hq-ops-1',
          notes: 'Fallback first detected.',
          openedAt: DateTime(2020, 3, 15, 1),
          dueAt: DateTime(2020, 3, 15, 5),
          recordedAt: DateTime(2020, 3, 15, 1, 15),
        ),
      ],
      runtimeRolloutControlRecords: <Map<String, dynamic>>[
        _runtimeRolloutControlRecordRow(),
      ],
      runtimeRolloutAuditEvents: <Map<String, dynamic>>[
        _runtimeRolloutAuditEventRow(
          id: 'audit-triage-1',
          timestamp: 1773522000000,
          details: <String, dynamic>{
            'experimentId': 'fl_exp_literacy_pilot',
            'candidateModelPackageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'status': 'acknowledged',
            'fallbackCount': 1,
            'pendingCount': 0,
            'notes': 'Reviewed with site ops.',
          },
        ),
        _runtimeRolloutAuditEventRow(
          id: 'audit-triage-2',
          timestamp: 1773521940000,
          details: <String, dynamic>{
            'experimentId': 'fl_exp_literacy_pilot',
            'candidateModelPackageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'status': 'active',
            'fallbackCount': 1,
            'pendingCount': 0,
            'notes': 'Initial fallback alert raised.',
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder alertHistoryButton = find.widgetWithText(
      TextButton,
      'Alert history',
    );
    await tester.ensureVisible(alertHistoryButton.first);
    final TextButton alertHistoryControl = tester.widget<TextButton>(
      alertHistoryButton.first,
    );
    alertHistoryControl.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime rollout alert history: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.text('fl_delivery_1 · acknowledged · 1 fallback · 0 pending'),
      findsOneWidget,
    );
    expect(
      find.text('HQ notes: Reviewed with site ops and monitoring in place.'),
      findsOneWidget,
    );
    expect(find.text('Triage history'), findsOneWidget);
    expect(
      find.textContaining('acknowledged by hq-1 · Reviewed with site ops.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Escalation: investigating · owner hq-ops-1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('overdue 2020-03-15T09:00:00.000'),
      findsWidgets,
    );
    expect(find.text('Escalation history'), findsOneWidget);
    expect(
      find.textContaining('investigating by hq-1 · owner hq-ops-1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Control: paused · owner hq-ops-3'),
      findsWidgets,
    );
    expect(find.widgetWithText(TextButton, 'View audit feed'), findsWidgets);
  });

  testWidgets('HQ page re-raises rollout alerts when acknowledged counts drift',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(
          id: 'fl_rollout_alert_1',
          deliveryRecordId: 'fl_delivery_1',
          status: 'acknowledged',
          fallbackCount: 0,
          pendingCount: 1,
          notes: 'Previously reviewed pending site.',
          acknowledgedBy: 'hq-1',
          acknowledgedAt: DateTime(2026, 3, 14, 21),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Rollout alert: 1 fallback site statuses need review. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );
    expect(
        find.widgetWithText(TextButton, 'Acknowledge alert'), findsOneWidget);
    expect(
      find.text('HQ notes: Previously reviewed pending site.'),
      findsNothing,
    );
  });

  testWidgets('HQ page saves rollout alert triage acknowledgements',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder acknowledgeAlertButton = find.widgetWithText(
      TextButton,
      'Acknowledge alert',
    );
    await tester.ensureVisible(acknowledgeAlertButton.first);
    final TextButton acknowledgeAlertControl = tester.widget<TextButton>(
      acknowledgeAlertButton.first,
    );
    acknowledgeAlertControl.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'HQ notes'),
      'Fallback reviewed with site ops.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(bridge.recordedRuntimeRolloutAlertSaves, isNotEmpty);
    expect(
      bridge.recordedRuntimeRolloutAlertSaves.last['deliveryRecordId'],
      'fl_delivery_1',
    );
    expect(
      bridge.recordedRuntimeRolloutAlertSaves.last['status'],
      'acknowledged',
    );
    expect(
      bridge.recordedRuntimeRolloutAlertSaves.last['fallbackCount'],
      1,
    );
    expect(
      find.text(
        'Rollout alert acknowledged: 1 fallback site statuses reviewed. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('HQ page shows runtime rollout audit feed',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(status: 'acknowledged'),
      ],
      runtimeRolloutAuditEvents: <Map<String, dynamic>>[
        _runtimeRolloutAuditEventRow(
          id: 'audit-alert',
          action: 'federated_learning.runtime_rollout_alert_record.upsert',
          collection: 'federatedLearningRuntimeRolloutAlertRecords',
          documentId: 'fl_rollout_alert_1',
          timestamp: 1773522000000,
        ),
        _runtimeRolloutAuditEventRow(
          id: 'audit-activation',
          action: 'federated_learning.runtime_activation_record.upsert',
          collection: 'federatedLearningRuntimeActivationRecords',
          documentId: 'fl_runtime_activation_1_site-2',
          timestamp: 1773521940000,
          details: <String, dynamic>{
            'experimentId': 'fl_exp_literacy_pilot',
            'candidateModelPackageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'siteId': 'site-2',
            'runtimeTarget': 'flutter_mobile',
            'status': 'fallback',
            'manifestDigest': 'sha256:delivery-1',
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder alertHistoryButton = find.widgetWithText(
      TextButton,
      'Alert history',
    );
    await tester.ensureVisible(alertHistoryButton.first);
    tester.widget<TextButton>(alertHistoryButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    final Finder auditFeedButton = find.widgetWithText(
      TextButton,
      'View rollout audit',
    );
    tester.widget<TextButton>(auditFeedButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Runtime rollout audit: Literacy Pilot'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Alert triage fl_delivery_1 · acknowledged'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Activation site-2 · fallback'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Delivery fl_delivery_1 · 1 fallback · 0 pending'),
      findsOneWidget,
    );
  });

  testWidgets('HQ page filters runtime rollout audit by package and site',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(id: 'fl_pkg_1'),
        _candidatePackageRow(
          id: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
        ),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_1',
          candidateModelPackageId: 'fl_pkg_1',
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_2',
          candidateModelPackageId: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          status: 'active',
          targetSiteIds: <String>['site-2'],
        ),
      ],
      runtimeRolloutAlertRecords: <Map<String, dynamic>>[
        _runtimeRolloutAlertRecordRow(
          deliveryRecordId: 'fl_delivery_1',
          candidateModelPackageId: 'fl_pkg_1',
        ),
      ],
      runtimeRolloutAuditEvents: <Map<String, dynamic>>[
        _runtimeRolloutAuditEventRow(
          id: 'audit-pkg-1',
          timestamp: 1773522000000,
          details: <String, dynamic>{
            'experimentId': 'fl_exp_literacy_pilot',
            'candidateModelPackageId': 'fl_pkg_1',
            'deliveryRecordId': 'fl_delivery_1',
            'status': 'acknowledged',
            'fallbackCount': 1,
            'pendingCount': 0,
            'targetSiteIds': <String>['site-1'],
          },
        ),
        _runtimeRolloutAuditEventRow(
          id: 'audit-pkg-2',
          action: 'federated_learning.runtime_activation_record.upsert',
          collection: 'federatedLearningRuntimeActivationRecords',
          documentId: 'fl_runtime_activation_2_site-2',
          timestamp: 1773521940000,
          details: <String, dynamic>{
            'experimentId': 'fl_exp_literacy_pilot',
            'candidateModelPackageId': 'fl_pkg_2',
            'deliveryRecordId': 'fl_delivery_2',
            'siteId': 'site-2',
            'runtimeTarget': 'flutter_mobile',
            'status': 'fallback',
            'manifestDigest': 'sha256:delivery-2',
            'targetSiteIds': <String>['site-2'],
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder alertHistoryButton = find.widgetWithText(
      TextButton,
      'Alert history',
    );
    await tester.ensureVisible(alertHistoryButton.first);
    tester.widget<TextButton>(alertHistoryButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    final Finder auditFeedButton = find.widgetWithText(
      TextButton,
      'View rollout audit',
    );
    tester.widget<TextButton>(auditFeedButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    final Finder packageFilter = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Package filter',
    );
    await tester.tap(packageFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('fl_pkg_2').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Alert triage fl_delivery_1'), findsNothing);
    expect(find.textContaining('Activation site-2 · fallback'), findsOneWidget);

    final Finder packageFilterReset = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Package filter',
    );
    await tester.tap(packageFilterReset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All packages').last);
    await tester.pumpAndSettle();

    final Finder siteFilter = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Site filter',
    );
    await tester.tap(siteFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('site-1').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Alert triage fl_delivery_1'), findsOneWidget);
    expect(find.textContaining('Activation site-2 · fallback'), findsNothing);
  });

  testWidgets('HQ page saves rollout escalation state',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder escalationButton = find.widgetWithText(
      TextButton,
      'Escalate alert',
    );
    await tester.ensureVisible(escalationButton.first);
    tester.widget<TextButton>(escalationButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    final Finder escalationStatusDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Escalation status',
    );
    await tester.tap(escalationStatusDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('investigating').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner user ID'),
      'hq-ops-2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Escalation notes'),
      'Investigating site runtime mismatch.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(bridge.recordedRuntimeRolloutEscalationSaves, isNotEmpty);
    expect(
      bridge.recordedRuntimeRolloutEscalationSaves.last['status'],
      'investigating',
    );
    expect(
      bridge.recordedRuntimeRolloutEscalationSaves.last['ownerUserId'],
      'hq-ops-2',
    );
    expect(
      bridge.recordedRuntimeRolloutEscalationSaves.last['fallbackCount'],
      1,
    );
    expect(
      find.textContaining('Escalation: investigating · owner hq-ops-2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Investigating site runtime mismatch.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'HQ page does not treat resolved escalation as current when issue persists',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
      runtimeRolloutEscalationRecords: <Map<String, dynamic>>[
        _runtimeRolloutEscalationRecordRow(
          status: 'resolved',
          ownerUserId: 'hq-ops-1',
          notes: 'Closed too early.',
          resolvedBy: 'hq-1',
          resolvedAt: DateTime(2026, 3, 15, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Escalate alert'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Update escalation'), findsNothing);
  });

  testWidgets('HQ page saves rollout control state',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(siteId: 'site-1', status: 'resolved'),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-2',
          siteId: 'site-2',
          status: 'fallback',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final Finder controlButton = find.widgetWithText(
      TextButton,
      'Rollout control',
    );
    await tester.ensureVisible(controlButton.first);
    tester.widget<TextButton>(controlButton.first).onPressed?.call();
    await tester.pumpAndSettle();

    final Finder controlModeDropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Control mode',
    );
    await tester.tap(controlModeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('paused').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner user ID'),
      'hq-ops-9',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Control reason'),
      'Paused pending bounded verification.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(bridge.recordedRuntimeRolloutControlSaves, isNotEmpty);
    expect(
      bridge.recordedRuntimeRolloutControlSaves.last['mode'],
      'paused',
    );
    expect(
      bridge.recordedRuntimeRolloutControlSaves.last['ownerUserId'],
      'hq-ops-9',
    );
    expect(
      find.textContaining(
          'Control: paused · owner hq-ops-9 · Paused pending bounded verification.'),
      findsOneWidget,
    );
  });

  testWidgets('HQ page orders rollout alerts ahead of healthy experiments',
      (WidgetTester tester) async {
    final _FakeWorkflowBridgeService bridge = _FakeWorkflowBridgeService(
      experiments: <Map<String, dynamic>>[
        _experimentRow(
          id: 'fl_exp_literacy_pilot',
          name: 'Literacy Pilot',
          allowedSiteIds: const <String>['site-1'],
        ),
        _experimentRow(
          id: 'fl_exp_numeracy_pilot',
          name: 'Numeracy Pilot',
          allowedSiteIds: const <String>['site-1', 'site-2'],
        ),
      ],
      aggregationRuns: <Map<String, dynamic>>[
        _aggregationRunRow(
          id: 'fl_agg_1',
          experimentId: 'fl_exp_literacy_pilot',
          mergeArtifactId: 'fl_merge_1',
          boundedDigest: 'sha256:digest-1',
        ),
        _aggregationRunRow(
          id: 'fl_agg_2',
          experimentId: 'fl_exp_numeracy_pilot',
          mergeArtifactId: 'fl_merge_2',
          boundedDigest: 'sha256:digest-2',
        ),
      ],
      mergeArtifacts: <Map<String, dynamic>>[
        _mergeArtifactRow(
          id: 'fl_merge_1',
          experimentId: 'fl_exp_literacy_pilot',
          aggregationRunId: 'fl_agg_1',
          boundedDigest: 'sha256:digest-1',
          summaryIds: const <String>['update-1', 'update-2'],
        ),
        _mergeArtifactRow(
          id: 'fl_merge_2',
          experimentId: 'fl_exp_numeracy_pilot',
          aggregationRunId: 'fl_agg_2',
          boundedDigest: 'sha256:digest-2',
          summaryIds: const <String>['update-3', 'update-4'],
        ),
      ],
      candidatePackages: <Map<String, dynamic>>[
        _candidatePackageRow(
          id: 'fl_pkg_1',
          experimentId: 'fl_exp_literacy_pilot',
          aggregationRunId: 'fl_agg_1',
          mergeArtifactId: 'fl_merge_1',
          boundedDigest: 'sha256:digest-1',
          summaryIds: const <String>['update-1', 'update-2'],
        ),
        _candidatePackageRow(
          id: 'fl_pkg_2',
          experimentId: 'fl_exp_numeracy_pilot',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          boundedDigest: 'sha256:digest-2',
          summaryIds: const <String>['update-3', 'update-4'],
        ),
      ],
      runtimeDeliveryRecords: <Map<String, dynamic>>[
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_1',
          experimentId: 'fl_exp_literacy_pilot',
          candidateModelPackageId: 'fl_pkg_1',
          aggregationRunId: 'fl_agg_1',
          mergeArtifactId: 'fl_merge_1',
          status: 'active',
          targetSiteIds: <String>['site-1'],
        ),
        _runtimeDeliveryRecordRow(
          id: 'fl_delivery_2',
          experimentId: 'fl_exp_numeracy_pilot',
          candidateModelPackageId: 'fl_pkg_2',
          aggregationRunId: 'fl_agg_2',
          mergeArtifactId: 'fl_merge_2',
          status: 'active',
          targetSiteIds: <String>['site-1', 'site-2'],
        ),
      ],
      runtimeActivationRecords: <Map<String, dynamic>>[
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_1_site-1',
          deliveryRecordId: 'fl_delivery_1',
          experimentId: 'fl_exp_literacy_pilot',
          candidateModelPackageId: 'fl_pkg_1',
          siteId: 'site-1',
          status: 'resolved',
        ),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_2_site-1',
          deliveryRecordId: 'fl_delivery_2',
          experimentId: 'fl_exp_numeracy_pilot',
          candidateModelPackageId: 'fl_pkg_2',
          siteId: 'site-1',
          status: 'resolved',
        ),
        _runtimeActivationRecordRow(
          id: 'fl_runtime_activation_2_site-2',
          deliveryRecordId: 'fl_delivery_2',
          experimentId: 'fl_exp_numeracy_pilot',
          candidateModelPackageId: 'fl_pkg_2',
          siteId: 'site-2',
          status: 'fallback',
          notes: 'Site requested fallback after bounded runtime mismatch.',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithMaterial(HqFeatureFlagsPage(workflowBridge: bridge)),
    );
    await tester.pumpAndSettle();

    final double numeracyY = tester.getTopLeft(find.text('Numeracy Pilot')).dy;
    final double literacyY = tester.getTopLeft(find.text('Literacy Pilot')).dy;

    expect(numeracyY, lessThan(literacyY));
    expect(
      find.text(
        'Rollout alert: 1 fallback site statuses need review. Use Site rollout for detail.',
      ),
      findsOneWidget,
    );
  });
}
