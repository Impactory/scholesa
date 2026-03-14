import {
  buildLtiGradePassbackAuditLog,
  buildLtiGradePassbackIdempotencyKey,
  buildLtiGradePassbackJob,
  normalizeIntegrationProvider,
} from './ltiIntegration';

describe('ltiIntegration helpers', () => {
  it('normalizes LTI provider aliases', () => {
    expect(normalizeIntegrationProvider('lti-1p3')).toBe('lti_1p3');
    expect(normalizeIntegrationProvider('LTI')).toBe('lti_1p3');
    expect(normalizeIntegrationProvider('google_classroom')).toBe('google-classroom');
  });

  it('builds stable idempotency keys and queued jobs', () => {
    const input = {
      siteId: 'site-1',
      learnerId: 'learner-1',
      missionAttemptId: 'attempt-1',
      requestedBy: 'educator-1',
      lineItemId: 'line-item-1',
      scoreGiven: 8,
      scoreMaximum: 10,
    };

    const keyA = buildLtiGradePassbackIdempotencyKey(input);
    const keyB = buildLtiGradePassbackIdempotencyKey({ ...input });
    expect(keyA).toBe(keyB);

    const job = buildLtiGradePassbackJob(input);
    expect(job.provider).toBe('lti_1p3');
    expect(job.type).toBe('grade_push');
    expect(job.status).toBe('queued');
    expect(job.idempotencyKey).toBe(keyA);
    expect(job.gradingProgress).toBe('PendingManual');
  });

  it('rejects invalid grade values', () => {
    expect(() => buildLtiGradePassbackJob({
      siteId: 'site-1',
      learnerId: 'learner-1',
      missionAttemptId: 'attempt-1',
      requestedBy: 'educator-1',
      lineItemId: 'line-item-1',
      scoreGiven: 11,
      scoreMaximum: 10,
    })).toThrow('scoreGiven must be between 0 and scoreMaximum.');
  });

  it('creates audit logs without PII fields beyond ids', () => {
    const job = buildLtiGradePassbackJob({
      siteId: 'site-1',
      learnerId: 'learner-1',
      missionAttemptId: 'attempt-1',
      requestedBy: 'educator-1',
      lineItemUrl: 'https://lms.example/lineitems/1',
      scoreGiven: 4,
      scoreMaximum: 5,
    });

    const audit = buildLtiGradePassbackAuditLog(job, 'educator-1');
    expect(audit.action).toBe('lti.grade_passback.queued');
    expect(audit.details.scoreGiven).toBe(4);
    expect(audit.details.lineItemUrl).toBe('https://lms.example/lineitems/1');
  });
});