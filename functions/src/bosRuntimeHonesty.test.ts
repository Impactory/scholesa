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
  emaStateEstimatorUpdate: jest.fn(),
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
  it('reads learner-loop event time from createdAt before legacy timestamp fields', () => {
    expect(__bosRuntimeInternals.readInteractionEventMillis({
      createdAt: { toMillis: () => 2000 },
      timestamp: { toMillis: () => 1000 },
    })).toBe(2000);

    expect(__bosRuntimeInternals.readInteractionEventMillis({
      timestamp: { seconds: 3, nanoseconds: 500_000_000 },
    })).toBe(3500);

    expect(__bosRuntimeInternals.readInteractionEventMillis({
      timestampIso: '2026-04-27T00:00:00.000Z',
    })).toBe(Date.parse('2026-04-27T00:00:00.000Z'));
  });

  it('builds learner-loop insights from real state, event, goal, and MVL rows', () => {
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    const response = __bosRuntimeInternals.buildLearnerLoopInsightsResponse({
      siteId: 'site-1',
      learnerId: 'learner-1',
      lookbackDays: 30,
      generatedAt: '2026-04-27T00:00:00.000Z',
      stateRows: [
        {
          id: 'latest',
          data: { x_hat: { cognition: 1.2, engagement: -0.1, integrity: 0.9 } },
        },
        { id: 'bad', data: { x_hat: null } },
        {
          id: 'oldest',
          data: { x_hat: { cognition: 0.5, engagement: 0.4, integrity: 0.6 } },
        },
      ],
      eventRows: [
        { id: 'opened-1', data: { eventType: 'ai_help_opened' } },
        { id: 'opened-2', data: { eventType: 'ai_help_opened' } },
        { id: 'help-1', data: { eventType: 'ai_help_used' } },
        { id: 'response-1', data: { eventType: 'ai_coach_response' } },
        { id: 'explain-1', data: { eventType: 'explain_it_back_submitted' } },
        { id: 'mvl-1', data: { eventType: 'mvl_gate_triggered' } },
        ...Array.from({ length: 6 }, (_, index) => ({
          id: `goal-${index + 1}`,
          data: {
            eventType: 'ai_learning_goal_updated',
            payload: { latest_goal: `Goal ${index + 1}` },
          },
        })),
        { id: 'unknown-1', data: { eventType: 'not_a_loop_signal' } },
      ],
      mvlRows: [
        { id: 'active-null', data: { resolution: null } },
        { id: 'active-empty', data: { resolution: '' } },
        { id: 'passed', data: { resolution: 'passed' } },
        { id: 'failed', data: { resolution: 'failed' } },
      ],
    });

    expect(response.state).toEqual({ cognition: 1, engagement: 0, integrity: 0.9 });
    expect(response.trend).toEqual({
      cognitionDelta: 0.5,
      engagementDelta: -0.4,
      integrityDelta: 0.30000000000000004,
      improvementScore: 0.15000000000000002,
    });
    expect(response.stateAvailability).toEqual({
      validSamples: 2,
      hasCurrentState: true,
      hasTrendBaseline: true,
    });
    expect(response.eventCounts).toEqual({
      ai_help_opened: 2,
      ai_help_used: 1,
      ai_coach_response: 1,
      ai_learning_goal_updated: 6,
      mvl_gate_triggered: 1,
      explain_it_back_submitted: 1,
      checkpoint_submitted: 0,
      artifact_submitted: 0,
      mission_completed: 0,
    });
    expect(response.verification).toEqual({
      aiHelpOpened: 2,
      aiHelpUsed: 1,
      explainBackSubmitted: 1,
      pendingExplainBack: 1,
    });
    expect(response.mvl).toEqual({ active: 2, passed: 1, failed: 1 });
    expect(response.activeGoals).toEqual(['Goal 1', 'Goal 2', 'Goal 3', 'Goal 4', 'Goal 5']);
    expect(response.generatedAt).toBe('2026-04-27T00:00:00.000Z');
    expect(warnSpy).toHaveBeenCalledWith('[BOS] Malformed orchestration state: bad');
    warnSpy.mockRestore();
  });

  it('keeps empty learner-loop insights honest when no usable state exists', () => {
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    const response = __bosRuntimeInternals.buildLearnerLoopInsightsResponse({
      siteId: 'site-1',
      learnerId: 'learner-1',
      lookbackDays: 7,
      generatedAt: '2026-04-27T00:00:00.000Z',
      stateRows: [{ id: 'malformed', data: { x_hat: undefined } }],
      eventRows: [{ id: 'unknown', data: { eventType: 'unknown_event' } }],
      mvlRows: [],
    });

    expect(response.state).toBeNull();
    expect(response.trend).toBeNull();
    expect(response.stateAvailability).toEqual({
      validSamples: 0,
      hasCurrentState: false,
      hasTrendBaseline: false,
    });
    expect(response.eventCounts).toEqual(__bosRuntimeInternals.createLearnerLoopEventCounts());
    expect(response.mvl).toEqual({ active: 0, passed: 0, failed: 0 });
    expect(response.activeGoals).toEqual([]);
    warnSpy.mockRestore();
  });

  it('drops malformed orchestration provenance blocks from callable state payloads', () => {
    const sanitized = __bosRuntimeInternals.sanitizeOrchestrationStateResponse({
      siteId: 'site-1',
      learnerId: 'learner-1',
      sessionOccurrenceId: 'occ-1',
      x_hat: { cognition: 0.7, engagement: 0.5, integrity: 0.8 },
      P: { trace: 0.4, confidence: 0.9 },
      model: {
        estimator: 'ema-state-estimator',
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
        estimator: 'ema-state-estimator',
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
      estimator: 'ema-state-estimator',
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