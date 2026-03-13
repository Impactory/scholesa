export interface FeatureVector {
  cognition: number;
  engagement: number;
  integrity: number;
}

export interface StateEstimate {
  x_hat: { cognition: number; engagement: number; integrity: number };
  P: { diag: number[]; trace: number; confidence: number };
}

export interface ClassInsightLearner {
  learnerId: string;
  x_hat?: { cognition?: number; engagement?: number; integrity?: number };
  P?: { trace?: number; confidence?: number };
  lastUpdatedAt?: unknown;
}

function clamp(value: number, min: number = 0, max: number = 1): number {
  return Math.min(max, Math.max(min, value));
}

export function ekfLiteUpdate(
  prior: StateEstimate | null,
  observation: FeatureVector,
  alpha: number = 0.7,
): StateEstimate {
  if (!prior) {
    return {
      x_hat: {
        cognition: observation.cognition,
        engagement: observation.engagement,
        integrity: observation.integrity,
      },
      P: { diag: [0.25, 0.25, 0.25], trace: 0.75, confidence: 0.25 },
    };
  }

  const x = prior.x_hat;
  const y = observation;
  const newCognition = clamp(alpha * x.cognition + (1 - alpha) * y.cognition);
  const newEngagement = clamp(alpha * x.engagement + (1 - alpha) * y.engagement);
  const newIntegrity = clamp(alpha * x.integrity + (1 - alpha) * y.integrity);
  const newDiag = prior.P.diag.map((entry) => Math.max(0.01, entry * 0.9));
  const newTrace = newDiag.reduce((sum, entry) => sum + entry, 0);

  return {
    x_hat: {
      cognition: newCognition,
      engagement: newEngagement,
      integrity: newIntegrity,
    },
    P: { diag: newDiag, trace: newTrace, confidence: 1 - newTrace / 3 },
  };
}

function learnerRiskScore(learner: ClassInsightLearner): number {
  const xHat = learner.x_hat ?? {};
  const cognition = clamp(Number(xHat.cognition ?? 0.5));
  const engagement = clamp(Number(xHat.engagement ?? 0.5));
  const integrity = clamp(Number(xHat.integrity ?? 0.5));
  return ((1 - cognition) * 0.4) + ((1 - engagement) * 0.35) + ((1 - integrity) * 0.25);
}

export function summarizeClassInsights(learners: ClassInsightLearner[]) {
  const learnerCount = learners.length;
  const averages = learnerCount > 0
    ? {
        cognition: learners.reduce((sum, learner) => sum + clamp(Number(learner.x_hat?.cognition ?? 0.5)), 0) / learnerCount,
        engagement: learners.reduce((sum, learner) => sum + clamp(Number(learner.x_hat?.engagement ?? 0.5)), 0) / learnerCount,
        integrity: learners.reduce((sum, learner) => sum + clamp(Number(learner.x_hat?.integrity ?? 0.5)), 0) / learnerCount,
      }
    : { cognition: 0, engagement: 0, integrity: 0 };

  const watchlist = learners
    .filter((learner) => learnerRiskScore(learner) >= 0.35)
    .sort((left, right) => learnerRiskScore(right) - learnerRiskScore(left));

  return {
    learnerCount,
    averages,
    watchlist,
  };
}