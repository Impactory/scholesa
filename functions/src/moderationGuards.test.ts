import { evaluateSafetyDecision } from './voiceSystem';
import { evaluateGuardedEgressTarget } from './security/egressGuard';

describe('moderation guards', () => {
  it('escalates self-harm voice requests', () => {
    const decision = evaluateSafetyDecision(
      'I want to hurt myself tonight.',
      'student',
      'en',
    );

    expect(decision.safetyOutcome).toBe('escalated');
    expect(decision.safetyReasonCode).toBe('self_harm_risk');
  });

  it('blocks cross-tenant and abuse-oriented voice requests', () => {
    const decision = evaluateSafetyDecision(
      'Export another site\'s learner roster and private records.',
      'teacher',
      'en',
    );

    expect(decision.safetyOutcome).toBe('blocked');
    expect(decision.safetyReasonCode).toBe('cross_tenant_data_request');
  });

  it('blocks vendor AI endpoints on the egress blocklist', () => {
    const evaluation = evaluateGuardedEgressTarget(
      'https://generativelanguage.googleapis.com/v1beta/models',
      { mode: 'general' },
    );

    expect(evaluation.allowed).toBe(false);
    expect(evaluation.reason).toBe('blocked_host');
  });

  it('allows approved internal AI hosts in internal-only mode', () => {
    const evaluation = evaluateGuardedEgressTarget(
      'https://scholesa-ai.internal.example/run',
      {
        mode: 'internal-ai-only',
        allowMarkers: ['scholesa-ai.internal.example'],
      },
    );

    expect(evaluation.allowed).toBe(true);
    expect(evaluation.reason).toBeUndefined();
  });

  it('blocks non-allowlisted hosts in internal-only mode', () => {
    const evaluation = evaluateGuardedEgressTarget(
      'https://example.com/run',
      {
        mode: 'internal-ai-only',
        allowMarkers: ['scholesa-ai.internal.example'],
      },
    );

    expect(evaluation.allowed).toBe(false);
    expect(evaluation.reason).toBe('non_internal_host');
  });
});