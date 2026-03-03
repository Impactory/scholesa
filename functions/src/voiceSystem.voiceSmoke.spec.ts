import { __voiceSystemInternals } from './voiceSystem';

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${String(expected)} but received ${String(actual)}`);
  }
}

function assertDeepEqual(actual: unknown, expected: unknown, message: string): void {
  const left = JSON.stringify(actual);
  const right = JSON.stringify(expected);
  if (left !== right) {
    throw new Error(`${message}: expected ${right} but received ${left}`);
  }
}

function assertTruthy(value: unknown, message: string): void {
  if (!value) {
    throw new Error(message);
  }
}

function makeRequest(headers: Record<string, string | undefined>) {
  return {
    header: (name: string) => headers[name.toLowerCase()],
  } as unknown as { header: (name: string) => string | undefined };
}

function runVoiceSmokeRegressionSuite(): void {
  const traceFromBody = __voiceSystemInternals.resolveTraceId(
    makeRequest({
      'x-trace-id': 'trace-header',
      'x-cloud-trace-context': 'trace-cloud/123;o=1',
    }),
    {
      traceId: 'trace-body',
      context: {
        traceId: 'trace-context',
        voiceTraceId: 'trace-voice',
        voiceInputTraceId: 'trace-input',
      },
    },
  );
  assertEqual(traceFromBody, 'trace-body', 'traceId should prioritize body.traceId');

  const traceFromVoiceContext = __voiceSystemInternals.resolveTraceId(
    makeRequest({
      'x-trace-id': 'trace-header',
    }),
    {
      context: {
        voiceTraceId: 'trace-voice',
      },
    },
  );
  assertEqual(traceFromVoiceContext, 'trace-voice', 'traceId should fallback to context.voiceTraceId');

  const traceFromHeader = __voiceSystemInternals.resolveTraceId(
    makeRequest({
      'x-trace-id': 'trace-header',
    }),
    {},
  );
  assertEqual(traceFromHeader, 'trace-header', 'traceId should fallback to x-trace-id header');

  const bosContext = __voiceSystemInternals.resolveBosInteractionContext(
    {
      sessionOccurrenceId: 'occ-123',
      missionId: 'mission-xyz',
      contextMode: 'in_class',
      conceptTags: ['ai_coach_popup', 'voice', 'mode:hint'],
      context: {
        selectedLearnerId: 'learner-selected',
      },
    },
    {
      uid: 'teacher-1',
      role: 'teacher',
      siteId: 'site-1',
      siteIds: ['site-1'],
      gradeBand: '6-8',
    },
  );
  assertEqual(bosContext.actorId, 'learner-selected', 'teacher selected learner should become actorId');
  assertEqual(bosContext.actorRole, 'learner', 'teacher selected learner should set actorRole to learner');
  assertEqual(bosContext.sessionOccurrenceId, 'occ-123', 'sessionOccurrenceId should be preserved');
  assertEqual(bosContext.contextMode, 'in_class', 'contextMode should normalize to in_class');
  assertDeepEqual(
    bosContext.conceptTags,
    ['ai_coach_popup', 'voice', 'mode:hint'],
    'conceptTags should be preserved and normalized',
  );

  const policyHint = __voiceSystemInternals.extractInternalBosPayload({
    intervention: {
      mode: 'hint',
      type: 'scaffold',
      salience: 'high',
      triggerMvl: false,
      confidence: 0.72,
      reasonCodes: ['bos_closed_loop_control'],
    },
  });
  assertTruthy(policyHint, 'BOS policy payload should parse');
  assertEqual(policyHint?.mode, 'hint', 'parsed policy mode should equal hint');
  assertEqual(policyHint?.type, 'scaffold', 'parsed policy type should equal scaffold');

  const learnerHints = __voiceSystemInternals.deriveBosModeToolHints('student', {
    mode: 'explain',
    triggerMvl: false,
    confidence: 0.8,
    reasonCodes: [],
  });
  assertDeepEqual(learnerHints, ['read_aloud'], 'student explain mode should map to read_aloud');

  const teacherHints = __voiceSystemInternals.deriveBosModeToolHints('teacher', {
    mode: 'verify',
    triggerMvl: false,
    confidence: 0.8,
    reasonCodes: [],
  });
  assertDeepEqual(
    teacherHints,
    ['rubric_feedback_draft'],
    'teacher verify mode should map to rubric_feedback_draft',
  );
}

runVoiceSmokeRegressionSuite();
console.log('Voice BOS smoke regression suite passed.');
