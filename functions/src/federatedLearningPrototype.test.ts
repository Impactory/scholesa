import {
  buildFederatedLearningAggregationRunDocId,
  buildFederatedLearningExperimentDocId,
  buildFederatedLearningFeatureFlagId,
  buildFederatedLearningFeatureFlagPayload,
  federatedLearningAuditAction,
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
  });

  it('builds stable ids, feature-flag payloads, and audit actions', () => {
    const experimentId = buildFederatedLearningExperimentDocId('My Pilot / Alpha');
    expect(experimentId).toBe('fl_exp_my_pilot_alpha');
    expect(buildFederatedLearningFeatureFlagId(experimentId)).toBe('feature_fl_exp_my_pilot_alpha');
    expect(buildFederatedLearningAggregationRunDocId(experimentId, ['sum-1', 'sum-2']))
      .toBe('fl_agg_5d4e2d02f90f7a83ff0b2369');
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
      vectorLength: 128,
      payloadBytes: 2048,
      updateNorm: 14.5,
      payloadDigest: 'sha256:abc123',
      batteryState: 'charging',
      networkType: 'wifi',
    }, 4096);
    expect(summary.payloadBytes).toBe(2048);
    expect(summary.networkType).toBe('wifi');

    expect(() => sanitizeFederatedLearningUpdateSummary({
      siteId: 'site-1',
      traceId: 'trace-1',
      schemaVersion: 'v1',
      sampleCount: 8,
      vectorLength: 128,
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
        vectorLength: 128,
        payloadBytes: 1024,
        updateNorm: 1.5,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 8,
        vectorLength: 96,
        payloadBytes: 768,
        updateNorm: 1.2,
        schemaVersion: 'v1',
        runtimeTarget: 'flutter_mobile',
      },
      {
        id: 'sum-3',
        siteId: 'site-1',
        sampleCount: 12,
        vectorLength: 144,
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
      totalSampleCount: 18,
      maxVectorLength: 128,
      totalPayloadBytes: 1792,
      averageUpdateNorm: 1.35,
      schemaVersions: ['v1'],
      runtimeTargets: ['flutter_mobile'],
    });
  });

  it('returns null when accepted summaries do not yet satisfy the threshold', () => {
    const selection = selectFederatedLearningAggregationBatch([
      {
        id: 'sum-1',
        siteId: 'site-1',
        sampleCount: 5,
        vectorLength: 128,
        payloadBytes: 1024,
        updateNorm: 1.5,
        schemaVersion: 'v1',
      },
      {
        id: 'sum-2',
        siteId: 'site-2',
        sampleCount: 6,
        vectorLength: 96,
        payloadBytes: 768,
        updateNorm: 1.2,
        schemaVersion: 'v1',
      },
    ], 20);

    expect(selection).toBeNull();
  });
});