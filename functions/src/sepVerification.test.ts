import { classifySepEntropyBand, summarizeVerificationSignalType } from './sepVerification';

describe('sepVerification', () => {
  it('classifies high SEP risk as high entropy', () => {
    expect(classifySepEntropyBand({ riskScore: 0.82, threshold: 0.6, H_sem: 0.74 })).toBe('high');
  });

  it('classifies medium SEP risk below the gate threshold', () => {
    expect(classifySepEntropyBand({ riskScore: 0.42, threshold: 0.6, H_sem: 0.38 })).toBe('medium');
  });

  it('identifies joint verification prompts when autonomy and reliability are both elevated', () => {
    expect(
      summarizeVerificationSignalType(
        { signals: ['verification_gap'], riskScore: 0.72, threshold: 0.5 },
        { riskScore: 0.76, threshold: 0.6, H_sem: 0.68 },
      ),
    ).toBe('joint');
  });

  it('identifies autonomy-led verification prompts when only autonomy risk is elevated', () => {
    expect(
      summarizeVerificationSignalType(
        { signals: ['heavy_ai_use'], riskScore: 0.71, threshold: 0.5 },
        { riskScore: 0.34, threshold: 0.6, H_sem: 0.22 },
      ),
    ).toBe('autonomy');
  });
});