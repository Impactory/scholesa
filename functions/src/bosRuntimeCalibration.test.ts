import { normalizeBosCalibrationGradeBand, resolveBosRuntimeCalibration } from './bosRuntimeCalibration';

describe('bosRuntimeCalibration', () => {
  it('normalizes supported grade band aliases', () => {
    expect(normalizeBosCalibrationGradeBand('4-6')).toBe('G4_6');
    expect(normalizeBosCalibrationGradeBand('G7_9')).toBe('G7_9');
    expect(normalizeBosCalibrationGradeBand('unknown')).toBe('G4_6');
  });

  it('resolves and clamps calibration fields from a training profile', () => {
    const calibration = resolveBosRuntimeCalibration(
      {
        modelVersion: 'synthetic-bos-mia-starter-full-v1',
        trainingRunId: 'bos-mia-synthetic-2026-03-15T12-00-00-000Z',
        gradeBandProfiles: {
          G4_6: {
            targetRegion: {
              cognitionTarget: 1.2,
              engagementTarget: 0.61,
              integrityFloor: 0.42,
            },
            integrityFloor: 0.43,
            ekfAlpha: 0.92,
            autonomyRiskThreshold: 0.33,
            reliabilityRiskThreshold: 0.88,
          },
        },
      },
      '4-6',
    );

    expect(calibration).not.toBeNull();
    expect(calibration?.gradeBand).toBe('G4_6');
    expect(calibration?.targetRegion.cognitionTarget).toBe(0.9);
    expect(calibration?.integrityFloor).toBe(0.45);
    expect(calibration?.ekfAlpha).toBe(0.85);
    expect(calibration?.autonomyRiskThreshold).toBe(0.45);
    expect(calibration?.reliabilityRiskThreshold).toBe(0.8);
    expect(calibration?.modelVersion).toBe('synthetic-bos-mia-starter-full-v1');
  });

  it('returns null when the requested grade band is missing', () => {
    const calibration = resolveBosRuntimeCalibration(
      {
        modelVersion: 'synthetic-bos-mia-starter-full-v1',
        gradeBandProfiles: {
          G1_3: {
            targetRegion: {
              cognitionTarget: 0.66,
              engagementTarget: 0.68,
              integrityFloor: 0.6,
            },
            integrityFloor: 0.6,
            ekfAlpha: 0.7,
            autonomyRiskThreshold: 0.5,
            reliabilityRiskThreshold: 0.6,
          },
        },
      },
      'G10_12',
    );

    expect(calibration).toBeNull();
  });
});