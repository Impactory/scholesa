export interface BosRuntimeTargetRegion {
  cognitionTarget: number;
  engagementTarget: number;
  integrityFloor: number;
}

export interface BosRuntimeCalibration {
  gradeBand: 'G1_3' | 'G4_6' | 'G7_9' | 'G10_12';
  targetRegion: BosRuntimeTargetRegion;
  integrityFloor: number;
  ekfAlpha: number;
  autonomyRiskThreshold: number;
  reliabilityRiskThreshold: number;
  modelVersion: string;
  trainingRunId?: string;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asFiniteNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function normalizeBosCalibrationGradeBand(raw: string): 'G1_3' | 'G4_6' | 'G7_9' | 'G10_12' {
  switch ((raw || '').trim()) {
    case '1-3':
    case 'G1_3':
      return 'G1_3';
    case '4-6':
    case 'G4_6':
      return 'G4_6';
    case '7-9':
    case 'G7_9':
      return 'G7_9';
    case '10-12':
    case 'G10_12':
      return 'G10_12';
    default:
      return 'G4_6';
  }
}

export function resolveBosRuntimeCalibration(
  profileDoc: Record<string, unknown> | null | undefined,
  gradeBand: string,
): BosRuntimeCalibration | null {
  const profile = asRecord(profileDoc);
  if (!profile) return null;

  const normalizedGradeBand = normalizeBosCalibrationGradeBand(gradeBand);
  const gradeBandProfiles = asRecord(profile.gradeBandProfiles);
  const gradeBandProfile = asRecord(gradeBandProfiles?.[normalizedGradeBand]);
  if (!gradeBandProfile) return null;

  const targetRegion = asRecord(gradeBandProfile.targetRegion);
  const integrityFloor = clamp(
    asFiniteNumber(gradeBandProfile.integrityFloor, asFiniteNumber(targetRegion?.integrityFloor, 0.65)),
    0.45,
    0.9,
  );

  return {
    gradeBand: normalizedGradeBand,
    targetRegion: {
      cognitionTarget: clamp(asFiniteNumber(targetRegion?.cognitionTarget, 0.66), 0.45, 0.9),
      engagementTarget: clamp(asFiniteNumber(targetRegion?.engagementTarget, 0.64), 0.45, 0.9),
      integrityFloor,
    },
    integrityFloor,
    ekfAlpha: clamp(asFiniteNumber(gradeBandProfile.ekfAlpha, 0.7), 0.55, 0.85),
    autonomyRiskThreshold: clamp(asFiniteNumber(gradeBandProfile.autonomyRiskThreshold, 0.5), 0.45, 0.7),
    reliabilityRiskThreshold: clamp(asFiniteNumber(gradeBandProfile.reliabilityRiskThreshold, 0.6), 0.45, 0.8),
    modelVersion: typeof profile.modelVersion === 'string' && profile.modelVersion.trim().length > 0
      ? profile.modelVersion.trim()
      : 'synthetic-bos-mia-v1',
    trainingRunId: typeof profile.trainingRunId === 'string' && profile.trainingRunId.trim().length > 0
      ? profile.trainingRunId.trim()
      : undefined,
  };
}