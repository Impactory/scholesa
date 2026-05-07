import { __voiceSystemInternals } from './voiceSystem';

const {
  buildTypedStudentLocalResponse,
  requiresStrictStudentConfidence,
  resolveClientOrchestrationState,
  resolveClientMvlContext,
  resolveRuntimeProjectId,
  resolveVoiceInputModality,
} = __voiceSystemInternals;

const prototypeUnderstanding = {
  intent: 'hint_request' as const,
  complexity: 'medium' as const,
  needsScaffold: true,
  emotionalState: 'curious' as const,
  confidence: 0.88,
  responseMode: 'hint' as const,
  topicTags: ['prototype'],
};

describe('MiloOS typed input intelligence', () => {
  it('detects typed, keyboard, and voice input sources', () => {
    expect(resolveVoiceInputModality({ inputModality: 'typed' })).toBe('typed');
    expect(resolveVoiceInputModality({ context: { source: 'keyboard-entry' } })).toBe('typed');
    expect(resolveVoiceInputModality({ context: { modality: 'microphone' } })).toBe('voice');
    expect(resolveVoiceInputModality({})).toBe('unknown');
  });

  it('keeps strict confidence for voice but allows typed learner support to stay useful', () => {
    expect(requiresStrictStudentConfidence('student', 'voice')).toBe(true);
    expect(requiresStrictStudentConfidence('student', 'unknown')).toBe(true);
    expect(requiresStrictStudentConfidence('student', 'typed')).toBe(false);
    expect(requiresStrictStudentConfidence('teacher', 'voice')).toBe(false);
  });

  it('gives typed learners actionable evidence guidance without claiming mastery', () => {
    const response = buildTypedStudentLocalResponse(
      'en',
      'focus_nudge',
      prototypeUnderstanding,
      'How can I improve this prototype iteration and add portfolio evidence?'
    );

    expect(response).toContain('Pick one change between your first version and this version');
    expect(response).toContain('capture the proof');
    expect(response).toContain('what you will test next');
    expect(response).toContain('Keep the work yours');
    expect(response).not.toMatch(/mastery|grade|score/i);
  });
});

describe('resolveRuntimeProjectId', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  it('uses Gen 2 runtime project env aliases for voice token signing', () => {
    delete process.env.GOOGLE_CLOUD_PROJECT;
    process.env.GCLOUD_PROJECT = 'studio-runtime-project';

    expect(resolveRuntimeProjectId()).toBe('studio-runtime-project');
  });

  it('uses Firebase config projectId when direct project env vars are absent', () => {
    delete process.env.GOOGLE_CLOUD_PROJECT;
    delete process.env.GCLOUD_PROJECT;
    delete process.env.GCP_PROJECT;
    delete process.env.FIREBASE_PROJECT_ID;
    process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'studio-firebase-config' });

    expect(resolveRuntimeProjectId()).toBe('studio-firebase-config');
  });
});

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
