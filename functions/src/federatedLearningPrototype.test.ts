import {
  buildFederatedLearningExperimentDocId,
  buildFederatedLearningFeatureFlagId,
  buildFederatedLearningFeatureFlagPayload,
  federatedLearningAuditAction,
  normalizeFederatedLearningExperimentStatus,
  normalizeFederatedLearningRuntimeTarget,
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
});