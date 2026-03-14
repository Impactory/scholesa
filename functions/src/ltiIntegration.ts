import { createHash } from 'crypto';

export interface LtiGradePassbackInput {
  siteId: string;
  learnerId: string;
  missionAttemptId: string;
  requestedBy: string;
  lineItemId?: string | null;
  lineItemUrl?: string | null;
  scoreGiven: number;
  scoreMaximum: number;
  activityProgress?: string;
  gradingProgress?: string;
}

export interface LtiGradePassbackJobRecord {
  provider: 'lti_1p3';
  type: 'grade_push';
  jobType: 'grade_push';
  status: 'queued';
  siteId: string;
  requestedBy: string;
  learnerId: string;
  missionAttemptId: string;
  lineItemId: string | null;
  lineItemUrl: string | null;
  scoreGiven: number;
  scoreMaximum: number;
  activityProgress: string;
  gradingProgress: string;
  idempotencyKey: string;
}

function requireNonEmpty(value: string | null | undefined, fieldName: string): string {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new Error(`${fieldName} is required.`);
  }
  return normalized;
}

export function normalizeIntegrationProvider(provider: string | null | undefined): string {
  const normalized = typeof provider === 'string' ? provider.trim().toLowerCase() : '';
  if (!normalized) return 'google-classroom';
  if (['lti', 'lti1p3', 'lti-1p3', 'lti_1p3'].includes(normalized)) return 'lti_1p3';
  if (normalized === 'google_classroom') return 'google-classroom';
  return normalized;
}

export function buildLtiGradePassbackIdempotencyKey(input: LtiGradePassbackInput): string {
  const base = [
    requireNonEmpty(input.siteId, 'siteId'),
    requireNonEmpty(input.learnerId, 'learnerId'),
    requireNonEmpty(input.missionAttemptId, 'missionAttemptId'),
    requireNonEmpty(input.lineItemId || input.lineItemUrl || null, 'lineItemId or lineItemUrl'),
    input.scoreGiven.toFixed(4),
    input.scoreMaximum.toFixed(4),
  ].join(':');

  return createHash('sha256').update(base).digest('hex');
}

export function buildLtiGradePassbackJob(input: LtiGradePassbackInput): LtiGradePassbackJobRecord {
  const siteId = requireNonEmpty(input.siteId, 'siteId');
  const learnerId = requireNonEmpty(input.learnerId, 'learnerId');
  const missionAttemptId = requireNonEmpty(input.missionAttemptId, 'missionAttemptId');
  const requestedBy = requireNonEmpty(input.requestedBy, 'requestedBy');
  if (!Number.isFinite(input.scoreMaximum) || input.scoreMaximum <= 0) {
    throw new Error('scoreMaximum must be greater than 0.');
  }
  if (!Number.isFinite(input.scoreGiven) || input.scoreGiven < 0 || input.scoreGiven > input.scoreMaximum) {
    throw new Error('scoreGiven must be between 0 and scoreMaximum.');
  }

  return {
    provider: 'lti_1p3',
    type: 'grade_push',
    jobType: 'grade_push',
    status: 'queued',
    siteId,
    requestedBy,
    learnerId,
    missionAttemptId,
    lineItemId: input.lineItemId?.trim() || null,
    lineItemUrl: input.lineItemUrl?.trim() || null,
    scoreGiven: input.scoreGiven,
    scoreMaximum: input.scoreMaximum,
    activityProgress: input.activityProgress?.trim() || 'Submitted',
    gradingProgress: input.gradingProgress?.trim() || 'PendingManual',
    idempotencyKey: buildLtiGradePassbackIdempotencyKey(input),
  };
}

export function buildLtiGradePassbackAuditLog(job: LtiGradePassbackJobRecord, actorUid: string) {
  return {
    userId: actorUid,
    action: 'lti.grade_passback.queued',
    collection: 'syncJobs',
    documentId: job.idempotencyKey,
    timestamp: Date.now(),
    details: {
      provider: job.provider,
      type: job.type,
      siteId: job.siteId,
      learnerId: job.learnerId,
      missionAttemptId: job.missionAttemptId,
      lineItemId: job.lineItemId,
      lineItemUrl: job.lineItemUrl,
      scoreGiven: job.scoreGiven,
      scoreMaximum: job.scoreMaximum,
      idempotencyKey: job.idempotencyKey,
    },
  };
}