export interface SepRiskLike {
  riskScore: number;
  threshold: number;
  H_sem?: number;
}

export interface AutonomyRiskLike {
  signals: string[];
  riskScore: number;
  threshold: number;
}

export function classifySepEntropyBand(risk: SepRiskLike): 'low' | 'medium' | 'high' {
  const signal = Number.isFinite(risk.H_sem) ? Number(risk.H_sem) : risk.riskScore;
  if (signal >= Math.max(0.6, risk.threshold)) {
    return 'high';
  }
  if (signal >= Math.max(0.3, risk.threshold * 0.5)) {
    return 'medium';
  }
  return 'low';
}

export function summarizeVerificationSignalType(
  autonomy: AutonomyRiskLike,
  reliability: SepRiskLike,
): 'autonomy' | 'reliability' | 'joint' {
  const autonomyHigh = autonomy.riskScore > autonomy.threshold;
  const reliabilityHigh = reliability.riskScore > reliability.threshold;
  if (autonomyHigh && reliabilityHigh) {
    return 'joint';
  }
  if (autonomyHigh) {
    return 'autonomy';
  }
  return 'reliability';
}