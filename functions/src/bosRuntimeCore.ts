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

interface LearnerMetrics {
  cognition?: number;
  engagement?: number;
  integrity?: number;
}

function clamp(value: number, min: number = 0, max: number = 1): number {
  return Math.min(max, Math.max(min, value));
}

function readMetric(value: unknown): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return undefined;
  }
  return clamp(value);
}

function learnerMetrics(learner: ClassInsightLearner): LearnerMetrics {
  return {
    cognition: readMetric(learner.x_hat?.cognition),
    engagement: readMetric(learner.x_hat?.engagement),
    integrity: readMetric(learner.x_hat?.integrity),
  };
}

function averageDefined(values: Array<number | undefined>): number | null {
  const definedValues = values.filter((value): value is number => typeof value === 'number');
  if (definedValues.length === 0) {
    return null;
  }
  return definedValues.reduce((sum, value) => sum + value, 0) / definedValues.length;
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
  const metrics = learnerMetrics(learner);
  const weightedSignals = [
    metrics.cognition == null ? null : (1 - metrics.cognition) * 0.4,
    metrics.engagement == null ? null : (1 - metrics.engagement) * 0.35,
    metrics.integrity == null ? null : (1 - metrics.integrity) * 0.25,
  ].filter((value): value is number => value != null);

  if (weightedSignals.length === 0) {
    return -1;
  }

  return weightedSignals.reduce((sum, value) => sum + value, 0);
}

export function summarizeClassInsights(learners: ClassInsightLearner[]) {
  const learnerCount = learners.length;
  const metrics = learners.map((learner) => learnerMetrics(learner));
  const averages = {
    cognition: averageDefined(metrics.map((entry) => entry.cognition)),
    engagement: averageDefined(metrics.map((entry) => entry.engagement)),
    integrity: averageDefined(metrics.map((entry) => entry.integrity)),
  };

  const coverage = {
    cognition: metrics.filter((entry) => entry.cognition != null).length,
    engagement: metrics.filter((entry) => entry.engagement != null).length,
    integrity: metrics.filter((entry) => entry.integrity != null).length,
  };

  const watchlist = learners
    .filter((learner) => learnerRiskScore(learner) >= 0.35)
    .sort((left, right) => learnerRiskScore(right) - learnerRiskScore(left));

  return {
    learnerCount,
    averages,
    coverage,
    watchlist,
  };
}