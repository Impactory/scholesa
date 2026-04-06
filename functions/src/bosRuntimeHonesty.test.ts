jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  firestore: jest.fn(() => ({})),
}));

jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((optionsOrHandler: unknown, maybeHandler?: unknown) =>
    typeof optionsOrHandler === 'function' ? optionsOrHandler : maybeHandler),
  HttpsError: class HttpsError extends Error {
    constructor(public code: string, message: string) {
      super(message);
      this.name = 'HttpsError';
    }
  },
}));

jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: jest.fn((_options: unknown, handler: unknown) => handler),
}));

jest.mock('./gen2Runtime', () => ({
  SCHOLESA_GEN2_REGION: 'test-region',
}));

jest.mock('./internalInferenceGateway', () => ({
  callInternalInferenceJson: jest.fn(),
  isInternalInferenceRequired: jest.fn(() => false),
}));

jest.mock('./bosRuntimeCore', () => ({
  ekfLiteUpdate: jest.fn(),
  summarizeClassInsights: jest.fn(),
}));

jest.mock('./bosRuntimeCalibration', () => ({
  resolveBosRuntimeCalibration: jest.fn(),
}));

jest.mock('./fdmInteractionSignals', () => ({
  readInteractionSignalObservation: jest.fn(),
}));

jest.mock('./coppaGuards', () => ({
  hasSiteAccess: jest.fn(),
  isCoppaConsentActive: jest.fn(),
}));

import { __bosRuntimeInternals } from './bosRuntime';

describe('bosRuntime honesty guards', () => {
  it('drops malformed orchestration provenance blocks from callable state payloads', () => {
    const sanitized = __bosRuntimeInternals.sanitizeOrchestrationStateResponse({
      siteId: 'site-1',
      learnerId: 'learner-1',
      sessionOccurrenceId: 'occ-1',
      x_hat: { cognition: 0.7, engagement: 0.5, integrity: 0.8 },
      P: { trace: 0.4, confidence: 0.9 },
      model: {
        estimator: 'ekf-lite',
        version: '0.1.0',
        Q_version: 'v1',
      },
      fusion: {
        familiesPresent: ['interaction'],
      },
      calibration: {
        scope: 'synthetic',
        gradeBand: 'G4_6',
        modelVersion: 'synthetic-bos-v1',
      },
    });

    expect(sanitized.model).toBeUndefined();
    expect(sanitized.fusion).toBeUndefined();
    expect(sanitized.calibration).toBeUndefined();
    expect(sanitized.x_hat).toEqual({ cognition: 0.7, engagement: 0.5, integrity: 0.8 });
    expect(sanitized.P).toEqual({ trace: 0.4, confidence: 0.9 });
  });

  it('preserves fully formed orchestration provenance blocks', () => {
    const sanitized = __bosRuntimeInternals.sanitizeOrchestrationStateResponse({
      siteId: 'site-1',
      learnerId: 'learner-1',
      sessionOccurrenceId: 'occ-1',
      x_hat: { cognition: 0.7, engagement: 0.5, integrity: 0.8 },
      P: { trace: 0.4, confidence: 0.9 },
      model: {
        estimator: 'ekf-lite',
        version: '0.1.0',
        Q_version: 'v1',
        R_version: 'v1',
      },
      fusion: {
        familiesPresent: ['interaction', 'voice_understanding'],
        sensorFusionMet: true,
      },
      calibration: {
        scope: 'synthetic',
        gradeBand: 'G4_6',
        modelVersion: 'synthetic-bos-v1',
        trainingRunId: 'run-1',
        ekfAlpha: 0.7,
      },
    });

    expect(sanitized.model).toEqual({
      estimator: 'ekf-lite',
      version: '0.1.0',
      Q_version: 'v1',
      R_version: 'v1',
    });
    expect(sanitized.fusion).toEqual({
      familiesPresent: ['interaction', 'voice_understanding'],
      sensorFusionMet: true,
    });
    expect(sanitized.calibration).toEqual({
      scope: 'synthetic',
      gradeBand: 'G4_6',
      modelVersion: 'synthetic-bos-v1',
      trainingRunId: 'run-1',
      ekfAlpha: 0.7,
    });
  });
});