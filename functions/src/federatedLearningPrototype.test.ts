import {
  buildFederatedLearningAggregationRunDocId,
  buildFederatedLearningCandidateModelPackageDocId,
  buildFederatedLearningCandidatePromotionRecordDocId,
  buildFederatedLearningCandidatePromotionRevocationRecordDocId,
  buildFederatedLearningExperimentReviewRecordDocId,
  buildFederatedLearningPilotEvidenceRecordDocId,
  buildFederatedLearningPilotApprovalRecordDocId,
  buildFederatedLearningPilotExecutionRecordDocId,
  buildFederatedLearningRuntimeDeliveryRecordDocId,
  buildFederatedLearningRuntimeDeliveryManifestDigest,
  buildFederatedLearningRuntimeActivationRecordDocId,
  buildFederatedLearningRuntimeRolloutAlertRecordDocId,
  buildFederatedLearningRuntimeRolloutEscalationRecordDocId,
  buildFederatedLearningRuntimeRolloutControlRecordDocId,
  FEDERATED_LEARNING_MERGE_STRATEGY,
  FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY,
  buildFederatedLearningContributionDetails,
  buildFederatedLearningMergeWeightSummary,
  buildFederatedLearningMergedRuntimeVector,
  buildFederatedLearningCandidateModelPackageSummary,
  buildFederatedLearningMergeArtifactDocId,
  buildFederatedLearningMergeArtifactSummary,
  buildFederatedLearningExperimentDocId,
  buildFederatedLearningFeatureFlagId,
  buildFederatedLearningFeatureFlagPayload,
  federatedLearningAuditAction,
  normalizeFederatedLearningCandidatePromotionStatus,
  normalizeFederatedLearningCandidatePromotionTarget,
  normalizeFederatedLearningExperimentReviewStatus,
  normalizeFederatedLearningPilotEvidenceStatus,
  normalizeFederatedLearningPilotApprovalStatus,
  normalizeFederatedLearningPilotExecutionStatus,
  normalizeFederatedLearningRuntimeDeliveryStatus,
  normalizeFederatedLearningRuntimeActivationStatus,
  normalizeFederatedLearningRuntimeRolloutAlertStatus,
  normalizeFederatedLearningRuntimeRolloutEscalationStatus,
  normalizeFederatedLearningRuntimeRolloutControlMode,
  normalizeFederatedLearningExperimentStatus,
  normalizeFederatedLearningRuntimeTarget,
  selectFederatedLearningAggregationBatch,
  sanitizeFederatedLearningExperimentConfig,
  sanitizeFederatedLearningUpdateSummary,
} from './federatedLearningPrototype';

describe('federated learning prototype helpers', () => {
  it('normalizes runtime targets and statuses', () => {
    expect(normalizeFederatedLearningRuntimeTarget('flutter')).toBe('flutter_mobile');
    expect(normalizeFederatedLearningRuntimeTarget('web-pwa')).toBe('web_pwa');
    expect(normalizeFederatedLearningRuntimeTarget('hybrid')).toBe('hybrid');
    expect(normalizeFederatedLearningRuntimeTarget('desktop')).toBeNull();
    expect(normalizeFederatedLearningExperimentStatus('pilot-ready')).toBe('pilot_ready');
    expect(normalizeFederatedLearningExperimentStatus('active')).toBe('active');
    expect(normalizeFederatedLearningExperimentStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningCandidatePromotionStatus('approved-for-eval')).toBe('approved_for_eval');
    expect(normalizeFederatedLearningCandidatePromotionStatus('hold')).toBe('hold');
    expect(normalizeFederatedLearningCandidatePromotionStatus('rejected')).toBeNull();
    expect(normalizeFederatedLearningCandidatePromotionTarget('sandbox-eval')).toBe('sandbox_eval');
    expect(normalizeFederatedLearningCandidatePromotionTarget('production')).toBeNull();
    expect(normalizeFederatedLearningExperimentReviewStatus('approved')).toBe('approved');
    expect(normalizeFederatedLearningExperimentReviewStatus('blocked')).toBe('blocked');
    expect(normalizeFederatedLearningExperimentReviewStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningPilotEvidenceStatus('ready-for-pilot')).toBe('ready_for_pilot');
    expect(normalizeFederatedLearningPilotEvidenceStatus('blocked')).toBe('blocked');
    expect(normalizeFederatedLearningPilotEvidenceStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningPilotApprovalStatus('approved')).toBe('approved');
    expect(normalizeFederatedLearningPilotApprovalStatus('blocked')).toBe('blocked');
    expect(normalizeFederatedLearningPilotApprovalStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningPilotExecutionStatus('launched')).toBe('launched');
    expect(normalizeFederatedLearningPilotExecutionStatus('completed')).toBe('completed');
    expect(normalizeFederatedLearningPilotExecutionStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningRuntimeDeliveryStatus('assigned')).toBe('assigned');
    expect(normalizeFederatedLearningRuntimeDeliveryStatus('supersede')).toBe('superseded');
    expect(normalizeFederatedLearningRuntimeDeliveryStatus('revoked')).toBe('revoked');
    expect(normalizeFederatedLearningRuntimeDeliveryStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningRuntimeActivationStatus('resolved')).toBe('resolved');
    expect(normalizeFederatedLearningRuntimeActivationStatus('fallback')).toBe('fallback');
    expect(normalizeFederatedLearningRuntimeActivationStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningRuntimeRolloutAlertStatus('active')).toBe('active');
    expect(normalizeFederatedLearningRuntimeRolloutAlertStatus('acknowledge')).toBe('acknowledged');
    expect(normalizeFederatedLearningRuntimeRolloutAlertStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningRuntimeRolloutEscalationStatus('open')).toBe('open');
    expect(normalizeFederatedLearningRuntimeRolloutEscalationStatus('in_progress')).toBe('investigating');
    expect(normalizeFederatedLearningRuntimeRolloutEscalationStatus('closed')).toBe('resolved');
    expect(normalizeFederatedLearningRuntimeRolloutEscalationStatus('archived')).toBeNull();
    expect(normalizeFederatedLearningRuntimeRolloutControlMode('monitor')).toBe('monitor');
    expect(normalizeFederatedLearningRuntimeRolloutControlMode('restrict')).toBe('restricted');
    expect(normalizeFederatedLearningRuntimeRolloutControlMode('pause')).toBe('paused');
    expect(normalizeFederatedLearningRuntimeRolloutControlMode('archived')).toBeNull();
  });

  it('builds stable ids, feature-flag payloads, and audit actions', () => {
    const experimentId = buildFederatedLearningExperimentDocId('My Pilot / Alpha');
    expect(experimentId).toBe('fl_exp_my_pilot_alpha');
    expect(buildFederatedLearningFeatureFlagId(experimentId)).toBe('feature_fl_exp_my_pilot_alpha');
    expect(buildFederatedLearningExperimentReviewRecordDocId(experimentId)).toBe('fl_review_my_pilot_alpha');
    expect(buildFederatedLearningAggregationRunDocId(experimentId, ['sum-1', 'sum-2']))
      .toBe('fl_agg_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningMergeArtifactDocId('fl_agg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_merge_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningCandidateModelPackageDocId('fl_agg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_pkg_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningCandidatePromotionRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_prom_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningCandidatePromotionRevocationRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_prom_revoke_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningPilotEvidenceRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_pilot_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningPilotApprovalRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_pilot_approval_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningPilotExecutionRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_pilot_execution_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningRuntimeDeliveryRecordDocId('fl_pkg_1cb85e2396ee2ed67818ed78'))
      .toBe('fl_delivery_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningRuntimeActivationRecordDocId(
      'fl_delivery_1cb85e2396ee2ed67818ed78',
      'site-1',
    )).toBe('fl_activation_cf2b2e6c70bdbb66d8055edf');
    expect(buildFederatedLearningRuntimeRolloutAlertRecordDocId(
      'fl_delivery_1cb85e2396ee2ed67818ed78',
    )).toBe('fl_rollout_alert_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningRuntimeRolloutEscalationRecordDocId(
      'fl_delivery_1cb85e2396ee2ed67818ed78',
    )).toBe('fl_rollout_escalation_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningRuntimeRolloutControlRecordDocId(
      'fl_delivery_1cb85e2396ee2ed67818ed78',
    )).toBe('fl_rollout_control_1cb85e2396ee2ed67818ed78');
    expect(buildFederatedLearningRuntimeDeliveryManifestDigest(
      'sha256:pkg-1',
      ['site-1', 'site-2'],
      'assigned',
      'flutter_mobile',
    )).toBe('sha256:19002381ae0437a1ffae3ef8');
    expect(federatedLearningAuditAction('experiment.upsert')).toBe('federated_learning.experiment.upsert');

    const config = sanitizeFederatedLearningExperimentConfig({
      name: 'Pilot Alpha',
      description: 'Site-limited experiment',
      runtimeTarget: 'flutter_mobile',
      status: 'pilot_ready',
      allowedSiteIds: ['site-1', 'site-1', 'site-2'],
      aggregateThreshold: 32,
      rawUpdateMaxBytes: 8192,
      enablePrototypeUploads: true,
    });
    const payload = buildFederatedLearningFeatureFlagPayload(experimentId, config);
    expect(config.mergeStrategy).toBe(FEDERATED_LEARNING_MERGE_STRATEGY);
    expect(payload.enabled).toBe(true);
    expect(payload.scope).toBe('site');
    expect(payload.enabledSites).toEqual(['site-1', 'site-2']);
  });

  it('validates bounded experiment config and update summaries', () => {
    expect(() => sanitizeFederatedLearningExperimentConfig({
      name: 'Pilot',
      runtimeTarget: 'flutter_mobile',
      status: 'active',
      allowedSiteIds: [],
    })).toThrow('allowedSiteIds are required when status is pilot_ready or active.');

    const summary = sanitizeFederatedLearningUpdateSummary({
      siteId: 'site-1',
      traceId: 'trace-1',
      schemaVersion: 'v1',
      sampleCount: 8,
      vectorLength: 3,
      vectorSketch: [1, 0.5, 0.25],
      payloadBytes: 2048,
      updateNorm: 14.5,
      payloadDigest: 'sha256:abc123',
      optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
      localEpochCount: 1,
      localStepCount: 8,
      trainingWindowSeconds: 45,
      warmStartPackageId: 'fl_pkg_1',
      warmStartDeliveryRecordId: 'fl_delivery_1',
      warmStartModelVersion: 'fl_runtime_model_v1',
      batteryState: 'charging',
      networkType: 'wifi',
    }, 4096);
    expect(summary.payloadBytes).toBe(2048);
    expect(summary.networkType).toBe('wifi');
    expect(summary.optimizerStrategy).toBe(
      'bounded_runtime_vector_local_finetune_v1',
    );
    expect(summary.localStepCount).toBe(8);
    expect(summary.warmStartPackageId).toBe('fl_pkg_1');

    expect(() => sanitizeFederatedLearningUpdateSummary({
      siteId: 'site-1',
      traceId: 'trace-1',
      schemaVersion: 'v1',
      sampleCount: 8,
      vectorLength: 3,
      vectorSketch: [1, 0.5, 0.25],
      payloadBytes: 2048,
      updateNorm: 14.5,
      payloadDigest: 'sha256:abc123',
      rawUpdate: 'forbidden',
    }, 4096)).toThrow('rawUpdate is not allowed in prototype update summaries.');
  });

  it('selects the smallest pending summary batch that meets the threshold', () => {
    const selection = selectFederatedLearningAggregationBatch([
      {
        id: 'sum-1',
        siteId: 'site-1',
        sampleCount: 10,
        vectorLength: 3,
        vectorSketch: [1, 0.5, 0],
        payloadBytes: 1024,
        updateNorm: 1.5,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
        warmStartPackageId: 'fl_pkg_1',
        warmStartModelVersion: 'fl_runtime_model_v1',
        traceId: 'trace-1',
        payloadDigest: 'sha256:update-1',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 8,
        vectorLength: 3,
        vectorSketch: [0.5, 1, 0.5],
        payloadBytes: 768,
        updateNorm: 1.2,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
        warmStartPackageId: 'fl_pkg_1',
        warmStartModelVersion: 'fl_runtime_model_v1',
        traceId: 'trace-2',
        payloadDigest: 'sha256:update-2',
      },
      {
        id: 'sum-3',
        siteId: 'site-1',
        sampleCount: 12,
        vectorLength: 3,
        vectorSketch: [0.2, 0.3, 1.2],
        payloadBytes: 1536,
        updateNorm: 2.1,
        schemaVersion: 'v2',
        runtimeTarget: 'hybrid',
      },
    ], 18);

    expect(selection).toEqual({
      summaryIds: ['sum-1', 'sum-2'],
      summaryCount: 2,
      distinctSiteCount: 2,
      contributingSiteIds: ['site-1', 'site-2'],
      totalSampleCount: 18,
      maxVectorLength: 3,
      totalPayloadBytes: 1792,
      averageUpdateNorm: 1.35,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
      compatibilityKey: 'v1|flutter_mobile|bounded_runtime_vector_local_finetune_v1|fl_pkg_1|fl_runtime_model_v1|3',
      warmStartPackageId: 'fl_pkg_1',
      warmStartModelVersion: 'fl_runtime_model_v1',
    });

    const mergedRuntimeVector = buildFederatedLearningMergedRuntimeVector([
      {
        sampleCount: 10,
        vectorSketch: [1, 0.5, 0],
        updateNorm: 1.5,
      },
      {
        sampleCount: 8,
        vectorSketch: [0.5, 1, 0.5],
        updateNorm: 1.2,
      },
    ], 3);
    const mergeWeights = buildFederatedLearningMergeWeightSummary([
      {
        sampleCount: 10,
        updateNorm: 1.5,
      },
      {
        sampleCount: 8,
        updateNorm: 1.2,
      },
    ]);

    expect(mergeWeights).toEqual({
      normCap: 2.683282,
      effectiveTotalWeight: 18,
      rawTotalWeight: 18,
      dampedSummaryCount: 0,
      minUpdateNorm: 1.2,
      maxUpdateNorm: 1.5,
    });

    const contributionDetails = buildFederatedLearningContributionDetails([
      {
        id: 'sum-1',
        siteId: 'site-1',
        sampleCount: 10,
        payloadBytes: 1024,
        vectorLength: 3,
        updateNorm: 1.5,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        traceId: 'trace-1',
        payloadDigest: 'sha256:update-1',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 8,
        payloadBytes: 768,
        vectorLength: 3,
        updateNorm: 1.2,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        traceId: 'trace-2',
        payloadDigest: 'sha256:update-2',
      },
    ], mergeWeights.normCap);

    expect(contributionDetails).toEqual([
      {
        summaryId: 'sum-1',
        siteId: 'site-1',
        sampleCount: 10,
        payloadBytes: 1024,
        vectorLength: 3,
        updateNorm: 1.5,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        traceId: 'trace-1',
        payloadDigest: 'sha256:update-1',
        rawWeight: 10,
        normScale: 1,
        effectiveWeight: 10,
      },
      {
        summaryId: 'sum-2',
        siteId: 'site-2',
        sampleCount: 8,
        payloadBytes: 768,
        vectorLength: 3,
        updateNorm: 1.2,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        traceId: 'trace-2',
        payloadDigest: 'sha256:update-2',
        rawWeight: 8,
        normScale: 1,
        effectiveWeight: 8,
      },
    ]);

    expect(buildFederatedLearningMergeArtifactSummary('sum-2', selection!, mergedRuntimeVector, mergeWeights, contributionDetails)).toEqual({
      mergeStrategy: FEDERATED_LEARNING_MERGE_STRATEGY,
      normCap: 2.683282,
      effectiveTotalWeight: 18,
      rawTotalWeight: 18,
      dampedSummaryCount: 0,
      minUpdateNorm: 1.2,
      maxUpdateNorm: 1.5,
      triggerSummaryId: 'sum-2',
      summaryIds: ['sum-1', 'sum-2'],
      payloadFormat: 'runtime_vector_v1',
      modelVersion: 'fl_runtime_model_v1',
      sampleCount: 18,
      summaryCount: 2,
      distinctSiteCount: 2,
      contributingSiteIds: ['site-1', 'site-2'],
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
      compatibilityKey: 'v1|flutter_mobile|bounded_runtime_vector_local_finetune_v1|fl_pkg_1|fl_runtime_model_v1|3',
      warmStartPackageId: 'fl_pkg_1',
      warmStartModelVersion: 'fl_runtime_model_v1',
      maxVectorLength: 3,
      runtimeVectorLength: 3,
      runtimeVector: [0.777778, 0.722222, 0.222222],
      runtimeVectorDigest: expect.stringMatching(/^sha256:[a-f0-9]{64}$/),
      totalPayloadBytes: 1792,
      averageUpdateNorm: 1.35,
      boundedDigest: expect.stringMatching(/^sha256:[a-f0-9]{64}$/),
      contributionDetails,
      siteContributionSummaries: [
        {
          siteId: 'site-1',
          summaryCount: 1,
          totalSampleCount: 10,
          totalPayloadBytes: 1024,
          rawWeight: 10,
          effectiveWeight: 10,
          dampedSummaryCount: 0,
          minUpdateNorm: 1.5,
          maxUpdateNorm: 1.5,
        },
        {
          siteId: 'site-2',
          summaryCount: 1,
          totalSampleCount: 8,
          totalPayloadBytes: 768,
          rawWeight: 8,
          effectiveWeight: 8,
          dampedSummaryCount: 0,
          minUpdateNorm: 1.2,
          maxUpdateNorm: 1.2,
        },
      ],
    });

    expect(buildFederatedLearningCandidateModelPackageSummary(
      'fl_agg_1cb85e2396ee2ed67818ed78',
      'fl_merge_1cb85e2396ee2ed67818ed78',
      buildFederatedLearningMergeArtifactSummary(
        'sum-2',
        selection!,
        mergedRuntimeVector,
        mergeWeights,
        contributionDetails,
      ),
    )).toEqual({
      mergeStrategy: FEDERATED_LEARNING_MERGE_STRATEGY,
      normCap: 2.683282,
      effectiveTotalWeight: 18,
      rawTotalWeight: 18,
      dampedSummaryCount: 0,
      minUpdateNorm: 1.2,
      maxUpdateNorm: 1.5,
      triggerSummaryId: 'sum-2',
      summaryIds: ['sum-1', 'sum-2'],
      packageFormat: 'runtime_vector_v1',
      rolloutStatus: 'not_distributed',
      modelVersion: 'fl_runtime_model_v1',
      packageDigest: expect.stringMatching(/^sha256:[a-f0-9]{64}$/),
      boundedDigest: expect.stringMatching(/^sha256:[a-f0-9]{64}$/),
      runtimeVectorLength: 3,
      runtimeVector: [0.777778, 0.722222, 0.222222],
      runtimeVectorDigest: expect.stringMatching(/^sha256:[a-f0-9]{64}$/),
      sampleCount: 18,
      summaryCount: 2,
      distinctSiteCount: 2,
      contributingSiteIds: ['site-1', 'site-2'],
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
      compatibilityKey: 'v1|flutter_mobile|bounded_runtime_vector_local_finetune_v1|fl_pkg_1|fl_runtime_model_v1|3',
      warmStartPackageId: 'fl_pkg_1',
      warmStartModelVersion: 'fl_runtime_model_v1',
      maxVectorLength: 3,
      totalPayloadBytes: 1792,
      averageUpdateNorm: 1.35,
      contributionDetails,
      siteContributionSummaries: [
        {
          siteId: 'site-1',
          summaryCount: 1,
          totalSampleCount: 10,
          totalPayloadBytes: 1024,
          rawWeight: 10,
          effectiveWeight: 10,
          dampedSummaryCount: 0,
          minUpdateNorm: 1.5,
          maxUpdateNorm: 1.5,
        },
        {
          siteId: 'site-2',
          summaryCount: 1,
          totalSampleCount: 8,
          totalPayloadBytes: 768,
          rawWeight: 8,
          effectiveWeight: 8,
          dampedSummaryCount: 0,
          minUpdateNorm: 1.2,
          maxUpdateNorm: 1.2,
        },
      ],
    });
  });

  it('supports summary-balanced merge weighting for bounded experiments', () => {
    const mergedRuntimeVector = buildFederatedLearningMergedRuntimeVector([
      {
        sampleCount: 20,
        vectorSketch: [1, 0],
        updateNorm: 1,
      },
      {
        sampleCount: 5,
        vectorSketch: [0, 1],
        updateNorm: 1,
      },
    ], 2, FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY);
    const mergeWeights = buildFederatedLearningMergeWeightSummary([
      {
        sampleCount: 20,
        updateNorm: 1,
      },
      {
        sampleCount: 5,
        updateNorm: 1,
      },
    ], FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY);

    expect(mergedRuntimeVector).toEqual([0.5, 0.5]);
    expect(mergeWeights).toEqual({
      normCap: 2,
      effectiveTotalWeight: 2,
      rawTotalWeight: 2,
      dampedSummaryCount: 0,
      minUpdateNorm: 1,
      maxUpdateNorm: 1,
    });

    const summaryBalancedConfig = sanitizeFederatedLearningExperimentConfig({
      name: 'Pilot Beta',
      runtimeTarget: 'flutter_mobile',
      status: 'draft',
      mergeStrategy: 'summary_balanced',
    });
    expect(summaryBalancedConfig.mergeStrategy).toBe(
      FEDERATED_LEARNING_SUMMARY_BALANCED_MERGE_STRATEGY,
    );
  });

  it('skips incompatible warm-start lineages when assembling an aggregation batch', () => {
    const selection = selectFederatedLearningAggregationBatch([
      {
        id: 'sum-1',
        siteId: 'site-1',
        sampleCount: 10,
        vectorLength: 3,
        vectorSketch: [1, 0.5, 0],
        payloadBytes: 1024,
        updateNorm: 1.5,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
        warmStartPackageId: 'fl_pkg_a',
        warmStartModelVersion: 'fl_runtime_model_v1',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 8,
        vectorLength: 3,
        vectorSketch: [0.5, 1, 0.5],
        payloadBytes: 768,
        updateNorm: 1.2,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
        warmStartPackageId: 'fl_pkg_b',
        warmStartModelVersion: 'fl_runtime_model_v2',
      },
      {
        id: 'sum-3',
        siteId: 'site-3',
        sampleCount: 9,
        vectorLength: 3,
        vectorSketch: [0.25, 0.5, 0.75],
        payloadBytes: 896,
        updateNorm: 1.4,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
        optimizerStrategy: 'bounded_runtime_vector_local_finetune_v1',
        warmStartPackageId: 'fl_pkg_a',
        warmStartModelVersion: 'fl_runtime_model_v1',
      },
    ], 18);

    expect(selection).toEqual({
      summaryIds: ['sum-1', 'sum-3'],
      summaryCount: 2,
      distinctSiteCount: 2,
      contributingSiteIds: ['site-1', 'site-3'],
      totalSampleCount: 19,
      maxVectorLength: 3,
      totalPayloadBytes: 1920,
      averageUpdateNorm: 1.45,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
      optimizerStrategies: ['bounded_runtime_vector_local_finetune_v1'],
      compatibilityKey: 'v1|flutter_mobile|bounded_runtime_vector_local_finetune_v1|fl_pkg_a|fl_runtime_model_v1|3',
      warmStartPackageId: 'fl_pkg_a',
      warmStartModelVersion: 'fl_runtime_model_v1',
    });
  });

  it('dampens high-norm update outliers during runtime-vector merge generation', () => {
    const mergedRuntimeVector = buildFederatedLearningMergedRuntimeVector([
      {
        sampleCount: 10,
        vectorSketch: [1, 1],
        updateNorm: 1,
      },
      {
        sampleCount: 10,
        vectorSketch: [10, 10],
        updateNorm: 100,
      },
    ], 2);

    expect(mergedRuntimeVector).toEqual([2.5, 2.5]);
  });

  it('returns null when accepted summaries do not yet satisfy the threshold', () => {
    const selection = selectFederatedLearningAggregationBatch([
      {
        id: 'sum-1',
        siteId: 'site-1',
        sampleCount: 5,
        vectorLength: 3,
        vectorSketch: [1, 0.5, 0],
        payloadBytes: 1024,
        updateNorm: 1.5,
        schemaVersion: 'v1',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 6,
        vectorLength: 3,
        vectorSketch: [0.5, 1, 0.5],
        payloadBytes: 768,
        updateNorm: 1.2,
        schemaVersion: 'v1',
      },
    ], 20);

    expect(selection).toBeNull();
  });
});