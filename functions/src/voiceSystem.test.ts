import { __voiceSystemInternals } from './voiceSystem';

const { resolveClientOrchestrationState, resolveClientMvlContext } = __voiceSystemInternals;

describe('resolveClientOrchestrationState', () => {
  it('returns null for undefined context', () => {
    expect(resolveClientOrchestrationState(undefined)).toBeNull();
  });

  it('returns null for missing orchestrationState', () => {
    expect(resolveClientOrchestrationState({})).toBeNull();
  });

  it('returns null for non-object orchestrationState', () => {
    expect(resolveClientOrchestrationState({ orchestrationState: 'bad' })).toBeNull();
  });

  it('returns null when xHat is missing', () => {
    expect(resolveClientOrchestrationState({
      orchestrationState: { confidence: 0.8 },
    })).toBeNull();
  });

  it('returns null when xHat has non-numeric fields', () => {
    expect(resolveClientOrchestrationState({
      orchestrationState: {
        xHat: { cognition: 'bad', engagement: 0.5, integrity: 0.3 },
      },
    })).toBeNull();
  });

  it('parses valid orchestration state with xHat only', () => {
    const result = resolveClientOrchestrationState({
      orchestrationState: {
        xHat: { cognition: 0.7, engagement: 0.5, integrity: 0.3 },
      },
    });
    expect(result).not.toBeNull();
    expect(result!.xHat).toEqual({ cognition: 0.7, engagement: 0.5, integrity: 0.3 });
    expect(result!.confidence).toBeUndefined();
    expect(result!.stateStatus).toBeUndefined();
  });

  it('parses valid state with confidence and stateStatus', () => {
    const result = resolveClientOrchestrationState({
      orchestrationState: {
        xHat: { cognition: 0.6, engagement: 0.4, integrity: 0.2 },
        confidence: 0.85,
        stateStatus: 'ready',
      },
    });
    expect(result).not.toBeNull();
    expect(result!.xHat).toEqual({ cognition: 0.6, engagement: 0.4, integrity: 0.2 });
    expect(result!.confidence).toBe(0.85);
    expect(result!.stateStatus).toBe('ready');
  });

  it('ignores non-finite confidence', () => {
    const result = resolveClientOrchestrationState({
      orchestrationState: {
        xHat: { cognition: 0.5, engagement: 0.5, integrity: 0.5 },
        confidence: Infinity,
      },
    });
    expect(result).not.toBeNull();
    expect(result!.confidence).toBeUndefined();
  });
});

describe('resolveClientMvlContext', () => {
  it('returns null for undefined context', () => {
    expect(resolveClientMvlContext(undefined)).toBeNull();
  });

  it('returns null for missing activeMvl', () => {
    expect(resolveClientMvlContext({})).toBeNull();
  });

  it('returns null for non-object activeMvl', () => {
    expect(resolveClientMvlContext({ activeMvl: 'bad' })).toBeNull();
  });

  it('returns null when active is false', () => {
    expect(resolveClientMvlContext({
      activeMvl: { active: false },
    })).toBeNull();
  });

  it('parses valid active MVL context', () => {
    const result = resolveClientMvlContext({
      activeMvl: { active: true, triggerReason: 'ai_dependency', evidenceCount: 3 },
    });
    expect(result).not.toBeNull();
    expect(result!.active).toBe(true);
    expect(result!.triggerReason).toBe('ai_dependency');
    expect(result!.evidenceCount).toBe(3);
  });

  it('handles active MVL with no optional fields', () => {
    const result = resolveClientMvlContext({
      activeMvl: { active: true },
    });
    expect(result).not.toBeNull();
    expect(result!.active).toBe(true);
    expect(result!.triggerReason).toBeUndefined();
    expect(result!.evidenceCount).toBeUndefined();
  });
});
