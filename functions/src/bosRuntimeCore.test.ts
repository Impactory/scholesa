import { emaStateEstimatorUpdate, summarizeClassInsights } from './bosRuntimeCore';

describe('bosRuntimeCore', () => {
  it('initializes an EMA state estimate from the first observation', () => {
    const state = emaStateEstimatorUpdate(null, {
      cognition: 0.72,
      engagement: 0.61,
      integrity: 0.83,
    });

    expect(state.x_hat).toEqual({
      cognition: 0.72,
      engagement: 0.61,
      integrity: 0.83,
    });
    expect(state.P.diag).toEqual([0.25, 0.25, 0.25]);
    expect(state.P.trace).toBeCloseTo(0.75, 6);
    expect(state.P.confidence).toBeCloseTo(0.25, 6);
  });

  it('shrinks uncertainty and blends the next observation', () => {
    const state = emaStateEstimatorUpdate(
      {
        x_hat: { cognition: 0.4, engagement: 0.5, integrity: 0.6 },
        P: { diag: [0.25, 0.25, 0.25], trace: 0.75, confidence: 0.25 },
      },
      { cognition: 0.7, engagement: 0.9, integrity: 0.3 },
    );

    expect(state.x_hat.cognition).toBeCloseTo(0.49, 6);
    expect(state.x_hat.engagement).toBeCloseTo(0.62, 6);
    expect(state.x_hat.integrity).toBeCloseTo(0.51, 6);
    expect(state.P.diag).toEqual([0.225, 0.225, 0.225]);
    expect(state.P.trace).toBeCloseTo(0.675, 6);
    expect(state.P.confidence).toBeGreaterThan(0.25);
  });

  it('returns a canonical BAE watchlist sorted by highest risk first', () => {
    const summary = summarizeClassInsights([
      {
        learnerId: 'steady',
        x_hat: { cognition: 0.76, engagement: 0.74, integrity: 0.79 },
      },
      {
        learnerId: 'attention-now',
        x_hat: { cognition: 0.21, engagement: 0.34, integrity: 0.39 },
      },
      {
        learnerId: 'watch',
        x_hat: { cognition: 0.42, engagement: 0.44, integrity: 0.52 },
      },
    ]);

    expect(summary.learnerCount).toBe(3);
    expect(summary.averages.cognition).toBeCloseTo((0.76 + 0.21 + 0.42) / 3, 6);
    expect(summary.watchlist.map((learner) => learner.learnerId)).toEqual([
      'attention-now',
      'watch',
    ]);
  });

  it('skips malformed state values instead of averaging fake neutral scores', () => {
    const summary = summarizeClassInsights([
      {
        learnerId: 'valid',
        x_hat: { cognition: 0.9, engagement: 0.8, integrity: 0.7 },
      },
      {
        learnerId: 'malformed',
        x_hat: { cognition: undefined, engagement: undefined, integrity: undefined },
      },
    ]);

    expect(summary.learnerCount).toBe(2);
    expect(summary.averages.cognition).toBeCloseTo(0.9, 6);
    expect(summary.coverage.cognition).toBe(1);
    expect(summary.watchlist.map((learner) => learner.learnerId)).toEqual([]);
  });
});