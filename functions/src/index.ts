import { createHmac, randomUUID } from 'crypto';
import { onCall, onRequest, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret, defineString } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import Stripe from 'stripe';
import { SCHOLESA_GEN2_REGION } from './gen2Runtime';
import { guardedFetch } from './security/egressGuard';
import {
  buildExplainBackSubmittedEvent,
  explainBackRecordedFeedback,
} from './aiCoachExplainBack';
import {
  enqueueLearnerGoalReminders,
  sendNotification as sendExternalNotification,
} from './notificationPipeline';
import { callInternalInferenceJson } from './internalInferenceGateway';
import { persistLogoutAuditRecord } from './logoutAudit';
import { ANALYTICS_REPAIR_AUDIT_ACTIONS, buildAnalyticsRepairRunRecord } from './analyticsRepairRuns';
import { matchesAuditLogFilters, normalizeAuditLogFilters } from './auditLogFilters';
import { classifySepEntropyBand, summarizeVerificationSignalType } from './sepVerification';
import { resolveParentCurrentLevel } from './parentDashboardSummary';
import {
  handleVoiceApi,
  handleCopilotMessage,
  handleVoiceAudio,
  handleVoiceTranscribe,
  handleTtsSpeak,
  __voiceSystemInternals,
} from './voiceSystem';
import { applyKidFriendlyConversationalTone } from './aiCoachTone';

admin.initializeApp();

const firestoreNamespace = admin.firestore as typeof admin.firestore & {
  FieldValue?: typeof FieldValue;
  Timestamp?: typeof Timestamp;
};
firestoreNamespace.FieldValue ??= FieldValue;
firestoreNamespace.Timestamp ??= Timestamp;

// Export telemetry aggregation functions
export {
  aggregateDailyTelemetry,
  aggregateWeeklyTelemetry,
  triggerTelemetryAggregation,
  backfillTelemetryAggregates,
} from './telemetryAggregator';

// Export BOS+MIA runtime functions
export {
  bosIngestEvent,
  bosGetOrchestrationState,
  bosGetIntervention,
  bosScoreMvl,
  bosSubmitMvlEvidence,
  bosTeacherOverrideMvl,
  bosGetClassInsights,
  bosGetLearnerLoopInsights,
  bosContestability,
  bosWeeklyFairnessAudit,
} from './bosRuntime';

// Export COPPA operational controls
export {
  upsertSchoolConsentRecord,
  getSchoolConsentRecord,
  upsertCoppaRetentionOverride,
  submitParentDataRequest,
  processParentDataRequest,
  runCoppaRetentionSweep,
  scheduledCoppaRetentionSweep,
  getCoppaComplianceSnapshot,
} from './coppaOps';

// Export workflow callable boundaries for finance/admin/secret operations.
export {
  listPartnerPayouts,
  listWorkflowApprovals,
  decideWorkflowApproval,
  listSafetyIncidents,
  resolveSafetyIncident,
  getIntegrationsHealth,
  triggerIntegrationSyncJob,
  updateIntegrationConnectionStatus,
  createCleverAuthUrl,
  listCleverSchools,
  listCleverSections,
  queueCleverRosterSync,
  resolveCleverIdentityLink,
  disconnectCleverConnection,
  createClassLinkAuthUrl,
  listClassLinkSchools,
  listClassLinkSections,
  queueClassLinkRosterSync,
  resolveClassLinkIdentityLink,
  disconnectClassLinkConnection,
  listEnterpriseSsoProviders,
  upsertEnterpriseSsoProvider,
  upsertLtiPlatformRegistration,
  upsertLtiResourceLink,
  queueLtiGradePassback,
  listExternalIdentityLinks,
  resolveExternalIdentityLink,
  listFeatureFlags,
  upsertFeatureFlag,
  listFederatedLearningExperiments,
  listFederatedLearningExperimentReviewRecords,
  listSiteFederatedLearningExperiments,
  listFederatedLearningAggregationRuns,
  listFederatedLearningMergeArtifacts,
  listFederatedLearningCandidateModelPackages,
  listFederatedLearningCandidatePromotionRecords,
  listFederatedLearningCandidatePromotionRevocationRecords,
  listFederatedLearningPilotEvidenceRecords,
  listFederatedLearningPilotApprovalRecords,
  listFederatedLearningPilotExecutionRecords,
  listFederatedLearningRuntimeDeliveryRecords,
  listFederatedLearningRuntimeActivationRecords,
  listFederatedLearningRuntimeRolloutAlertRecords,
  listFederatedLearningRuntimeRolloutAuditEvents,
  listFederatedLearningRuntimeRolloutEscalationRecords,
  listFederatedLearningRuntimeRolloutEscalationHistoryRecords,
  listFederatedLearningRuntimeRolloutControlRecords,
  listSiteFederatedLearningRuntimeDeliveryRecords,
  listSiteFederatedLearningRuntimeActivationRecords,
  resolveSiteFederatedLearningRuntimePackage,
  upsertFederatedLearningExperiment,
  upsertFederatedLearningExperimentReviewRecord,
  upsertFederatedLearningPilotEvidenceRecord,
  upsertFederatedLearningPilotApprovalRecord,
  upsertFederatedLearningPilotExecutionRecord,
  upsertFederatedLearningRuntimeDeliveryRecord,
  upsertFederatedLearningRuntimeActivationRecord,
  upsertFederatedLearningRuntimeRolloutAlertRecord,
  upsertFederatedLearningRuntimeRolloutEscalationRecord,
  upsertFederatedLearningRuntimeRolloutControlRecord,
  upsertFederatedLearningCandidatePromotionRecord,
  revokeFederatedLearningCandidatePromotionRecord,
  recordFederatedLearningPrototypeUpdate,
  listWorkflowContacts,
  getParentBillingSummary,
  getSiteBillingSnapshot,
  requestSiteBillingPlanChange,
  listHqBillingRecords,
  createHqInvoice,
  listCohortLaunches,
  upsertCohortLaunch,
  listPartnerLaunches,
  upsertPartnerLaunch,
  listKpiPacks,
  generateKpiPack,
  backfillKpiPackVoiceReliability,
  listRedTeamReviews,
  upsertRedTeamReview,
  listTrainingCycles,
  upsertTrainingCycle,
} from './workflowOps';

// Voice-first API surface (scholesa-api + scholesa-stt + scholesa-tts)
export const voiceApi = onRequest({ cors: true }, async (req, res) => handleVoiceApi(req, res));
export const copilotMessage = onRequest({ cors: true }, async (req, res) => handleCopilotMessage(req, res));
export const voiceTranscribe = onRequest({ cors: true }, async (req, res) => handleVoiceTranscribe(req, res));
export const ttsSpeak = onRequest({ cors: true }, async (req, res) => handleTtsSpeak(req, res));
export const voiceAudio = onRequest({ cors: true }, async (req, res) => handleVoiceAudio(req, res));

// Define secrets for Firebase Functions v2
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

// Stripe price IDs / notification config — defineString for v2 runtime
const stripePriceLearner = defineString('STRIPE_PRICE_LEARNER', { default: 'price_learner_seat' });
const stripePriceEducator = defineString('STRIPE_PRICE_EDUCATOR', { default: 'price_educator_seat' });
const stripePriceParent = defineString('STRIPE_PRICE_PARENT', { default: 'price_parent_seat' });
const stripePriceSite = defineString('STRIPE_PRICE_SITE', { default: 'price_site_license' });
const notifyEndpoint = defineString('NOTIFY_ENDPOINT', { default: '' });
const notifyApiKey = defineSecret('NOTIFY_API_KEY');

// Lazy-initialized Stripe client
let stripeClient: Stripe | null = null;

function getStripe(): Stripe | null {
  if (stripeClient) return stripeClient;
  const key = stripeSecretKey.value();
  if (key) {
    stripeClient = new Stripe(key, {
      apiVersion: '2026-02-25.clover',
      typescript: true,
    });
  }
  return stripeClient;
}

type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';
type TelemetryRole = Role | 'system';
type CanonicalTelemetryRole = 'student' | 'teacher' | 'admin' | 'system';

interface UserRecord {
  email?: string;
  displayName?: string;
  role?: string;
  siteIds?: string[];
  activeSiteId?: string;
  learnerIds?: string[];
  parentIds?: string[];
  educatorIds?: string[];
  teacherIds?: string[];
  gradeBand?: string;
  isActive?: boolean;
  updatedAt?: FirebaseFirestore.FieldValue | number;
}

function normalizeRoleValue(rawRole: unknown): Role | null {
  if (typeof rawRole !== 'string') return null;
  const normalized = rawRole.trim().toLowerCase();
  switch (normalized) {
    case 'learner':
    case 'student':
      return 'learner';
    case 'educator':
    case 'teacher':
      return 'educator';
    case 'parent':
    case 'guardian':
      return 'parent';
    case 'site':
    case 'sitelead':
    case 'site_lead':
      return 'site';
    case 'partner':
      return 'partner';
    case 'hq':
    case 'admin':
      return 'hq';
    default:
      return null;
  }
}

function toCanonicalTelemetryRole(role: TelemetryRole): CanonicalTelemetryRole {
  if (role === 'learner') return 'student';
  if (role === 'educator') return 'teacher';
  if (role === 'system') return 'system';
  return 'admin';
}

const USERS_COLLECTION = 'users';
const AUDIT_COLLECTION = 'auditLogs';
const TELEMETRY_COLLECTION = 'telemetryEvents';
const ORDERS_COLLECTION = 'orders';
const ENTITLEMENTS_COLLECTION = 'entitlements';
const FULFILLMENTS_COLLECTION = 'fulfillments';
const NOTIFICATION_REQUESTS_COLLECTION = 'notificationRequests';
const LEARNER_REMINDER_PREFERENCES_COLLECTION = 'learnerReminderPreferences';
const NOTIFICATION_RATE_COLLECTION = 'notificationRateLimits';
const CHECKOUT_INTENTS_COLLECTION = 'checkoutIntents';
const STRIPE_CUSTOMERS_COLLECTION = 'stripeCustomers';
const SUBSCRIPTIONS_COLLECTION = 'subscriptions';
// Stripe Price IDs — resolved from defineString params
function getStripePriceIds(): Record<ProductId, string> {
  return {
    'learner-seat': stripePriceLearner.value(),
    'educator-seat': stripePriceEducator.value(),
    'parent-seat': stripePriceParent.value(),
    'site-license': stripePriceSite.value(),
  };
}

const ALLOWED_TELEMETRY_EVENTS: Set<string> = new Set([
  'auth.login',
  'auth.logout',
  'attendance.recorded',
  'mission.attempt.submitted',
  'message.sent',
  'order.intent',
  'order.paid',
  'cta.clicked',
  'site.switched',
  'cms.page.viewed',
  'export.requested',
  'export.downloaded',
  'lead.submitted',
  'contract.created',
  'contract.approved',
  'deliverable.submitted',
  'deliverable.accepted',
  'payout.approved',
  'notification.requested',
  'aiDraft.requested',
  'aiDraft.reviewed',
  // Motivation & Engagement Events
  'app.open',
  'app.session.end',
  'mission.started',
  'mission.completed',
  'mission.abandoned',
  'reflection.submitted',
  'portfolio.item.added',
  'help.requested',
  'badge.viewed',
  'leaderboard.viewed',
  'streak.celebrated',
  'popup.shown',
  'popup.dismissed',
  'popup.completed',
  'nudge.accepted',
  'nudge.dismissed',
  'nudge.snoozed',
  'onboarding.started',
  'onboarding.completed',
  'diagnostic.submitted',
  'calibration.recorded',
  'learner.goal.updated',
  'accessibility.setting.changed',
  'fsrs.review.rated',
  'fsrs.queue.snoozed',
  'fsrs.queue.rescheduled',
  'interleaving.mode.changed',
  'worked_example.shown',
  'insight.viewed',
  'support.applied',
  'support.outcome.logged',
  'site.checkin',
  'site.checkout',
  'site.late_pickup.flagged',
  'schedule.viewed',
  'room.conflict.detected',
  'substitute.requested',
  'substitute.assigned',
  'mission.snapshot.created',
  'version_history_checkpointed',
  'roster.imported',
  'rubric.applied',
  'rubric.shared_to_parent_summary',
  'educator.review.completed',
  'educator.feedback.submitted',
  'support.intervention.logged',
  'motivation.insight.viewed',
  'fdm.state.changed',
  'mvl.required',
  'mvl.completed',
  'autonomy_risk.detected',
  'sep.verify.prompted',
  // ── BOS+MIA Runtime Events ──
  'mission_viewed',
  'mission_selected',
  'mission_started',
  'mission_completed',
  'checkpoint_started',
  'checkpoint_submitted',
  'checkpoint_graded',
  'artifact_created',
  'artifact_submitted',
  'artifact_reviewed',
  'ai_help_opened',
  'ai_help_used',
  'ai_coach_response',
  'ai_coach_feedback',
  'mvl_gate_triggered',
  'mvl_evidence_attached',
  'mvl_passed',
  'mvl_failed',
  'teacher_override_mvl',
  'teacher_override_intervention',
  'contestability_requested',
  'contestability_resolved',
  'session_joined',
  'session_left',
  'idle_detected',
  'focus_restored',
  'educator_class_view',
  'educator_learner_drilldown',
  'voice.transcribe',
  'voice.message',
  'voice.tts',
  'voice.blocked',
  'voice.escalated',
  'bos_mia.usability.feedback',
]);

const TELEMETRY_UNSCOPED_SITE_ID = 'unscoped';
const PUBLIC_TELEMETRY_EVENTS: Set<string> = new Set([
  'cms.page.viewed',
  'cta.clicked',
]);
const TELEMETRY_CALLABLE_CORS: Array<string | RegExp> = [
  /^https:\/\/(?:[a-z0-9-]+\.)?scholesa\.com$/,
  /^http:\/\/localhost(?::\d+)?$/,
  /^http:\/\/127\.0\.0\.1(?::\d+)?$/,
];
const TELEMETRY_CALLABLE_OPTIONS = {
  region: SCHOLESA_GEN2_REGION,
  cors: TELEMETRY_CALLABLE_CORS,
};
const TELEMETRY_PII_KEY_BLOCKLIST = new Set<string>([
  'name',
  'firstname',
  'lastname',
  'fullname',
  'displayname',
  'email',
  'phonenumber',
  'phone',
  'message',
  'messagebody',
  'body',
  'prompt',
  'response',
  'question',
  'query',
  'transcript',
  'audio',
  'audiobase64',
  'audiobytes',
  'rawtext',
  'rawprompt',
  'content',
  'text',
  'address',
]);
const TELEMETRY_MAX_METADATA_DEPTH = 4;
const TELEMETRY_MAX_COLLECTION_LENGTH = 50;
const TELEMETRY_MAX_STRING_LENGTH = 512;

type ProductId = 'learner-seat' | 'educator-seat' | 'parent-seat' | 'site-license';

const PRODUCT_CATALOG: Record<ProductId, { amount: string; currency: string; roles: Role[] }> = {
  'learner-seat': { amount: '25', currency: 'USD', roles: ['learner'] },
  'educator-seat': { amount: '30', currency: 'USD', roles: ['educator'] },
  'parent-seat': { amount: '10', currency: 'USD', roles: ['parent'] },
  'site-license': { amount: '500', currency: 'USD', roles: ['site', 'hq'] },
};

async function requireHq(authUid: string | undefined) {
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const snap = await admin.firestore().collection(USERS_COLLECTION).doc(authUid).get();
  const data = snap.data() as UserRecord | undefined;
  if (!data || normalizeRoleValue(data.role) !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }
  return {
    uid: authUid,
    user: {
      ...data,
      role: 'hq',
    },
  };
}

async function sendNotification(payload: {
  channel: string;
  siteId?: string;
  threadId?: string;
  messageId?: string;
  userId?: string;
  type?: string;
  data?: Record<string, unknown>;
}) {
  return sendExternalNotification(payload, {
    endpoint: notifyEndpoint.value(),
    apiKey: notifyApiKey.value(),
    fetchImpl: (url, init) => guardedFetch(
      url,
      init,
      { source: 'functions.sendNotification', mode: 'general' },
    ) as Promise<any>,
  });
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((v) => typeof v === 'string') as string[];
}

// ──────────────────────────────────────────────────────
// MiloOS control surface — Helper Functions
// Spec: BOS_MIA_HOW_TO_IMPLEMENT.md §5, Math Contract §6-§8
// ──────────────────────────────────────────────────────

// §4.2 Grade-band integrity thresholds
const AI_M_DAGGER: Record<string, number> = {
  G1_3: 0.55, G4_6: 0.60, G7_9: 0.65, G10_12: 0.70,
  K_5: 0.58, G6_8: 0.62, G9_12: 0.70,
};

type CoppaBand = 'K_5' | 'G6_8' | 'G9_12';

const COPPA_ALLOWED_MODES: Record<CoppaBand, string[]> = {
  K_5: ['hint', 'verify'],
  G6_8: ['hint', 'verify', 'explain'],
  G9_12: ['hint', 'verify', 'explain', 'debug'],
};

const COPPA_K5_ALLOWED_MIME_TYPES = new Set([
  'text/plain',
  'application/pdf',
  'image/png',
  'image/jpeg',
]);

const COPPA_BLOCKED_ATTACHMENT_PREFIXES = [
  'application/x-msdownload',
  'application/x-dosexec',
  'application/x-sh',
  'application/x-binary',
];

interface CoppaAttachment {
  mimeType?: string;
  sizeBytes?: number;
}

function normalizeGradeBandValue(value: unknown): string | null {
  if (typeof value !== 'string' || value.trim().length === 0) return null;
  const normalized = value.trim().toUpperCase();
  if (['G1_3', 'G4_6', 'G7_9', 'G10_12', 'K_5', 'G6_8', 'G9_12'].includes(normalized)) {
    return normalized;
  }
  return null;
}

function toCoppaBand(gradeBand: string): CoppaBand {
  switch (gradeBand) {
    case 'G1_3':
    case 'G4_6':
    case 'K_5':
      return 'K_5';
    case 'G7_9':
    case 'G6_8':
      return 'G6_8';
    case 'G10_12':
    case 'G9_12':
      return 'G9_12';
    default:
      return 'K_5';
  }
}

function resolveGradeBandFromClaims(
  request: CallableRequest,
  payloadGradeBand: unknown,
): { gradeBand: string; coppaBand: CoppaBand; source: 'custom_claim' | 'payload' | 'default' } {
  const token = (request.auth?.token ?? {}) as Record<string, unknown>;
  const claimGradeBand = normalizeGradeBandValue(token.gradeBand);
  const reqGradeBand = normalizeGradeBandValue(payloadGradeBand);

  if (claimGradeBand && reqGradeBand && claimGradeBand !== reqGradeBand) {
    throw new HttpsError('permission-denied', 'gradeBand claim does not match request payload.');
  }

  if (claimGradeBand) {
    return { gradeBand: claimGradeBand, coppaBand: toCoppaBand(claimGradeBand), source: 'custom_claim' };
  }
  if (reqGradeBand) {
    return { gradeBand: reqGradeBand, coppaBand: toCoppaBand(reqGradeBand), source: 'payload' };
  }
  return { gradeBand: 'K_5', coppaBand: 'K_5', source: 'default' };
}

function validateCoppaMode(mode: string, coppaBand: CoppaBand) {
  if (!COPPA_ALLOWED_MODES[coppaBand].includes(mode)) {
    throw new HttpsError(
      'failed-precondition',
      `Mode "${mode}" is not allowed for grade band ${coppaBand}. Allowed modes: ${COPPA_ALLOWED_MODES[coppaBand].join(', ')}`,
    );
  }
}

function normalizeAttachments(raw: unknown): CoppaAttachment[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((entry) => typeof entry === 'object' && entry !== null)
    .map((entry) => {
      const value = entry as Record<string, unknown>;
      const mimeType = typeof value.mimeType === 'string' ? value.mimeType.trim().toLowerCase() : undefined;
      const sizeBytes = typeof value.sizeBytes === 'number' && Number.isFinite(value.sizeBytes)
        ? value.sizeBytes
        : undefined;
      return { mimeType, sizeBytes };
    });
}

function validateCoppaAttachments(attachments: CoppaAttachment[], coppaBand: CoppaBand) {
  const maxCount = coppaBand === 'K_5' ? 3 : coppaBand === 'G6_8' ? 5 : 8;
  const maxSize = coppaBand === 'K_5' ? 2 * 1024 * 1024 : coppaBand === 'G6_8' ? 5 * 1024 * 1024 : 10 * 1024 * 1024;

  if (attachments.length > maxCount) {
    throw new HttpsError('invalid-argument', `Too many attachments for ${coppaBand}. Max allowed: ${maxCount}.`);
  }

  for (const attachment of attachments) {
    const mimeType = attachment.mimeType || '';
    const sizeBytes = attachment.sizeBytes ?? 0;
    if (sizeBytes > maxSize) {
      throw new HttpsError('invalid-argument', `Attachment exceeds max size for ${coppaBand}.`);
    }

    if (COPPA_BLOCKED_ATTACHMENT_PREFIXES.some((prefix) => mimeType.startsWith(prefix))) {
      throw new HttpsError('invalid-argument', `Attachment type "${mimeType}" is blocked.`);
    }

    if (coppaBand === 'K_5' && mimeType && !COPPA_K5_ALLOWED_MIME_TYPES.has(mimeType)) {
      throw new HttpsError(
        'invalid-argument',
        `Attachment type "${mimeType}" is not allowed for K-5. Allowed types: ${[...COPPA_K5_ALLOWED_MIME_TYPES].join(', ')}`,
      );
    }
  }
}

function validateCoppaInputText(input: unknown, coppaBand: CoppaBand) {
  if (typeof input !== 'string' || input.trim().length === 0) return;
  const maxChars = coppaBand === 'K_5' ? 600 : coppaBand === 'G6_8' ? 1200 : 2000;
  if (input.length > maxChars) {
    throw new HttpsError('invalid-argument', `Input exceeds max length for ${coppaBand}.`);
  }
  if (coppaBand === 'K_5' && /https?:\/\//i.test(input)) {
    throw new HttpsError('invalid-argument', 'External links are blocked for K-5 AI requests.');
  }
}

async function assertActiveSchoolConsent(siteId: string) {
  const consentDoc = await admin.firestore().collection('coppaSchoolConsents').doc(siteId).get();
  if (!consentDoc.exists) {
    throw new HttpsError('failed-precondition', 'School consent record is required before AI access.');
  }
  const consent = consentDoc.data() as Record<string, unknown>;
  const active = consent.active === true
    && consent.agreementSigned === true
    && consent.educationalUseOnly === true
    && consent.parentNoticeProvided === true
    && consent.noStudentMarketing === true;
  if (!active) {
    throw new HttpsError('failed-precondition', 'School consent record is incomplete or inactive.');
  }
}

interface ReliabilityRiskResult {
  riskType: 'reliability';
  method: 'sep';
  K: number;
  M: number;
  H_sem: number;
  riskScore: number;
  threshold: number;
}

/**
 * Compute reliability risk via SEP v1 heuristic (Math Contract §6).
 * V1: Heuristic proxy — high uncertainty + low cognition = high reliability risk.
 * V2+: True semantic entropy with sampling + clustering.
 */
function computeReliabilityRisk(
  mode: string,
  xHat: { cognition: number; engagement: number; integrity: number } | null,
  pSummary: { trace: number; confidence: number } | null,
): ReliabilityRiskResult {
  // SEP v1: Proxy risk from state uncertainty + mode
  const baseRisk = pSummary ? (1 - pSummary.confidence) * 0.5 : 0.25;

  // Higher risk for explain/debug modes (more complex output)
  const modeMultiplier = (mode === 'explain' || mode === 'debug') ? 1.3 : 1.0;

  // Low cognition increases risk (model is less certain about learner state)
  const cognitionPenalty = xHat ? Math.max(0, 0.5 - xHat.cognition) * 0.4 : 0.1;

  const riskScore = Math.min(1.0, (baseRisk * modeMultiplier + cognitionPenalty));

  return {
    riskType: 'reliability',
    method: 'sep',
    K: 1,   // V1: single response (no sampling)
    M: 1,   // V1: single cluster
    H_sem: 0,
    riskScore: Math.round(riskScore * 1000) / 1000,
    threshold: 0.6,
  };
}

interface AutonomyRiskResult {
  riskType: 'autonomy';
  signals: string[];
  riskScore: number;
  threshold: number;
}

/**
 * Compute autonomy risk from behavioral patterns (Math Contract §7).
 * Detects: rapid_submit, verification_gap, heavy_ai_use, minimal_editing,
 *          low_self_explanation, repeated_hints_no_attempt.
 */
async function computeAutonomyRisk(
  learnerId: string,
  sessionOccurrenceId: string | undefined,
  xHat: { cognition: number; engagement: number; integrity: number } | null,
  gradeBand: string,
): Promise<AutonomyRiskResult> {
  const signals: string[] = [];
  let riskScore = 0;

  if (!sessionOccurrenceId) {
    return { riskType: 'autonomy', signals, riskScore: 0, threshold: 0.5 };
  }

  // Query recent interaction events (last 20)
  const recentEvents = await admin.firestore().collection('interactionEvents')
    .where('actorId', '==', learnerId)
    .where('sessionOccurrenceId', '==', sessionOccurrenceId)
    .orderBy('timestamp', 'desc')
    .limit(20)
    .get();

  const events = recentEvents.docs.map(d => d.data());
  const totalEvents = events.length;

  if (totalEvents < 3) {
    return { riskType: 'autonomy', signals, riskScore: 0, threshold: 0.5 };
  }

  // Signal 1: Heavy MiloOS use — >40% of events are ai_help_*
  const aiEvents = events.filter(e =>
    e.eventType === 'ai_help_used' || e.eventType === 'ai_help_opened'
  ).length;
  if (aiEvents / totalEvents > 0.4) {
    signals.push('heavy_ai_use');
    riskScore += 0.25;
  }

  // Signal 2: Rapid submit after MiloOS — ai_help_used followed by checkpoint_submitted
  // within 30 seconds (approximated by consecutive order)
  for (let i = 0; i < events.length - 1; i++) {
    if (events[i].eventType === 'checkpoint_submitted' && events[i + 1].eventType === 'ai_help_used') {
      signals.push('rapid_submit');
      riskScore += 0.2;
      break;
    }
  }

  // Signal 3: Verification gap — no explain_it_back_submitted events
  const hasExplainBack = events.some(e => e.eventType === 'explain_it_back_submitted');
  const hasAiUse = aiEvents > 0;
  if (hasAiUse && !hasExplainBack) {
    signals.push('verification_gap');
    riskScore += 0.15;
  }

  // Signal 4: Repeated hints without independent attempt
  const consecutiveHints = events.filter(e => e.eventType === 'ai_help_used');
  const independentAttempts = events.filter(e =>
    e.eventType === 'checkpoint_submitted' || e.eventType === 'artifact_submitted'
  );
  if (consecutiveHints.length > 3 && independentAttempts.length === 0) {
    signals.push('repeated_hints_no_attempt');
    riskScore += 0.25;
  }

  // Signal 5: Low integrity state
  if (xHat && xHat.integrity < (AI_M_DAGGER[gradeBand] ?? 0.6)) {
    signals.push('low_integrity_state');
    riskScore += 0.15;
  }

  // Deduplicate signals
  const uniqueSignals = [...new Set(signals)];

  return {
    riskType: 'autonomy',
    signals: uniqueSignals,
    riskScore: Math.min(1.0, Math.round(riskScore * 1000) / 1000),
    threshold: 0.5,
  };
}

interface MvlCheckResult {
  gateActive: boolean;
  episodeId?: string;
  reason?: string;
}

/**
 * Check if MVL gate should be triggered and create episode if needed.
 * MVL triggers on: integrity < m_dagger, high reliability risk, high autonomy risk.
 * Sensor fusion rule: needs corroboration (≥2 risk sources).
 */
async function checkAndMaybeCreateMvl(params: {
  siteId: string;
  learnerId: string;
  sessionOccurrenceId?: string;
  gradeBand: string;
  xHat: { cognition: number; engagement: number; integrity: number } | null;
  reliabilityRisk: ReliabilityRiskResult;
  autonomyRisk: AutonomyRiskResult;
}): Promise<MvlCheckResult> {
  const { siteId, learnerId, sessionOccurrenceId, gradeBand, xHat, reliabilityRisk, autonomyRisk } = params;

  // Check for existing active MVL gate
  if (sessionOccurrenceId) {
    const existing = await admin.firestore().collection('mvlEpisodes')
      .where('learnerId', '==', learnerId)
      .where('sessionOccurrenceId', '==', sessionOccurrenceId)
      .where('resolution', '==', null)
      .limit(1)
      .get();

    if (!existing.empty) {
      return {
        gateActive: true,
        episodeId: existing.docs[0].id,
        reason: existing.docs[0].data().triggerReason || 'active_mvl_gate',
      };
    }
  }

  // Sensor fusion: count how many risk sources are elevated
  const riskSources: string[] = [];
  const mDagger = AI_M_DAGGER[gradeBand] ?? 0.60;

  if (xHat && xHat.integrity < mDagger) {
    riskSources.push('integrity_below_threshold');
  }
  if (reliabilityRisk.riskScore > reliabilityRisk.threshold) {
    riskSources.push('high_reliability_risk');
  }
  if (autonomyRisk.riskScore > autonomyRisk.threshold) {
    riskSources.push('high_autonomy_risk');
  }

  // Sensor fusion rule: ≥2 risk sources required for MVL trigger
  if (riskSources.length < 2) {
    return { gateActive: false };
  }

  // Create MVL episode
  const mvlDoc = await admin.firestore().collection('mvlEpisodes').add({
    siteId,
    learnerId,
    sessionOccurrenceId: sessionOccurrenceId || null,
    triggerReason: riskSources.join(' + '),
    riskSources,
    reliability: reliabilityRisk,
    autonomy: autonomyRisk,
    evidenceEventIds: [],
    resolution: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Emit mvl_gate_triggered event
  await admin.firestore().collection('interactionEvents').add({
    eventType: 'mvl_gate_triggered',
    siteId,
    actorId: learnerId,
    actorRole: 'system',
    gradeBand,
    sessionOccurrenceId: sessionOccurrenceId || null,
    payload: {
      episodeId: mvlDoc.id,
      riskSources,
      reliabilityScore: reliabilityRisk.riskScore,
      autonomyScore: autonomyRisk.riskScore,
      integrityState: xHat?.integrity ?? null,
    },
    timestamp: FieldValue.serverTimestamp(),
  });

  return {
    gateActive: true,
    episodeId: mvlDoc.id,
    reason: riskSources.join(' + '),
  };
}

/**
 * Generate MVL intercept message when gate is active.
 * Non-punitive: formative verification prompt.
 */
function generateMvlInterceptMessage(
  mode: string,
  displayName: string,
  reason: string | undefined,
  tags: string[],
): string {
  const tagNote = tags.length > 0 ? ` about ${tags.join(', ')}` : '';
  switch (mode) {
    case 'hint':
      return `${displayName}, before we continue — can you show me what you've tried so far${tagNote}? Walk me through your thinking step by step.`;
    case 'verify':
      return `${displayName}, let's pause and verify your understanding${tagNote}. Can you explain the key concept in your own words?`;
    case 'explain':
      return `${displayName}, I'd love to hear your explanation first${tagNote}. What do you think is happening and why? Then we can compare notes.`;
    case 'debug':
      return `${displayName}, before I help debug${tagNote} — what have you checked already? Show me the steps you've taken to find the issue.`;
    default:
      return `${displayName}, let's check in. Can you share your reasoning so far?`;
  }
}

/**
 * Generate MiloOS response from internal inference only.
 * Forbidden: final answers, doing the learner's work, punitive language, or low-confidence autonomous help.
 */

type AiCoachUnderstandingSignal = {
  intent: string;
  complexity: string;
  needsScaffold: boolean;
  emotionalState: string;
  confidence: number;
  responseMode: string;
  topicTags: string[];
};

type AiCoachSafetyOutcome = 'allowed' | 'blocked' | 'modified' | 'escalated';

const AI_COACH_POLICY_VERSION = 'gen-ai-coach-policy-2026-03-12';

function extractInternalLlmPayload(data: unknown): {
  text?: string;
  modelVersion?: string;
  toolSuggestions?: string[];
  traceId?: string;
  policyVersion?: string;
  safetyOutcome?: AiCoachSafetyOutcome;
  safetyReasonCode?: string;
  understanding?: Partial<AiCoachUnderstandingSignal>;
} | undefined {
  const root = (data && typeof data === 'object') ? data as Record<string, unknown> : undefined;
  if (!root) return undefined;
  const response = (root.response && typeof root.response === 'object') ? root.response as Record<string, unknown> : undefined;
  const output = (response?.output && typeof response.output === 'object') ? response.output as Record<string, unknown> : undefined;
  const result = (root.result && typeof root.result === 'object') ? root.result as Record<string, unknown> : undefined;
  const metadata = (root.metadata && typeof root.metadata === 'object') ? root.metadata as Record<string, unknown> : undefined;

  const text = [
    root.text,
    result?.text,
    output?.text,
    response?.text,
    root.message,
    result?.message,
  ].find((value) => typeof value === 'string' && value.trim().length > 0) as string | undefined;

  const rawToolSuggestions = [
    root.toolSuggestions,
    result?.toolSuggestions,
    output?.toolSuggestions,
    metadata?.toolSuggestions,
  ].find((value) => Array.isArray(value)) as unknown[] | undefined;

  const understandingSource = [
    root.understanding,
    result?.understanding,
    output?.understanding,
    response?.understanding,
    metadata?.understanding,
  ].find((value) => value && typeof value === 'object') as Record<string, unknown> | undefined;

  const toStringArray = (input: unknown): string[] | undefined => {
    if (!Array.isArray(input)) return undefined;
    const values = input.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0);
    return values.length > 0 ? values : undefined;
  };

  const toOptionalString = (input: unknown): string | undefined =>
    typeof input === 'string' && input.trim().length > 0 ? input.trim() : undefined;

  const toOptionalBoolean = (input: unknown): boolean | undefined =>
    typeof input === 'boolean' ? input : undefined;

  const toOptionalNumber = (input: unknown): number | undefined =>
    typeof input === 'number' && Number.isFinite(input) ? input : undefined;

  const toOptionalSafetyOutcome = (input: unknown): AiCoachSafetyOutcome | undefined =>
    input === 'allowed' || input === 'blocked' || input === 'modified' || input === 'escalated'
      ? input
      : undefined;

  return {
    text: toOptionalString(text),
    modelVersion: toOptionalString(root.modelVersion ?? result?.modelVersion ?? output?.modelVersion ?? metadata?.modelVersion),
    toolSuggestions: toStringArray(rawToolSuggestions),
    traceId: toOptionalString(root.traceId ?? result?.traceId ?? output?.traceId ?? metadata?.traceId),
    policyVersion: toOptionalString(root.policyVersion ?? result?.policyVersion ?? output?.policyVersion ?? metadata?.policyVersion),
    safetyOutcome: toOptionalSafetyOutcome(
      root.safetyOutcome ?? result?.safetyOutcome ?? output?.safetyOutcome ?? metadata?.safetyOutcome,
    ),
    safetyReasonCode: toOptionalString(
      root.safetyReasonCode ?? result?.safetyReasonCode ?? output?.safetyReasonCode ?? metadata?.safetyReasonCode,
    ),
    understanding: understandingSource ? {
      intent: toOptionalString(understandingSource.intent),
      complexity: toOptionalString(understandingSource.complexity),
      needsScaffold: toOptionalBoolean(understandingSource.needsScaffold),
      emotionalState: toOptionalString(understandingSource.emotionalState),
      confidence: toOptionalNumber(understandingSource.confidence),
      responseMode: toOptionalString(understandingSource.responseMode),
      topicTags: toStringArray(understandingSource.topicTags),
    } : undefined,
  };
}

function mergeAiCoachUnderstanding(
  base: AiCoachUnderstandingSignal,
  override?: Partial<AiCoachUnderstandingSignal>,
): AiCoachUnderstandingSignal {
  if (!override) return base;
  return {
    intent: override.intent ?? base.intent,
    complexity: override.complexity ?? base.complexity,
    needsScaffold: override.needsScaffold ?? base.needsScaffold,
    emotionalState: override.emotionalState ?? base.emotionalState,
    confidence: typeof override.confidence === 'number' ? override.confidence : base.confidence,
    responseMode: override.responseMode ?? base.responseMode,
    topicTags: Array.isArray(override.topicTags) && override.topicTags.length > 0 ? override.topicTags : base.topicTags,
  };
}

const MIN_AUTONOMOUS_LEARNER_CONFIDENCE = 0.97;

function clampLearnerConfidence(value: unknown): number {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return 0;
  if (numeric < 0) return 0;
  if (numeric > 1) return 1;
  return numeric;
}

function buildLearnerConfidenceGuardMessage(displayName: string, locale: string): string {
  switch (locale) {
    case 'zh-CN':
      return `${displayName}，我想更谨慎一点。先告诉我你已经试过什么，我可以帮你想下一步更安全的做法。如果你需要完整检查，请老师和你一起看。`;
    case 'zh-TW':
      return `${displayName}，我想更謹慎一點。先告訴我你已經試過什麼，我可以幫你想下一步更安全的做法。如果你需要完整檢查，請老師和你一起看。`;
    case 'th':
      return `${displayName} ฉันอยากระวังให้มากขึ้น ลองบอกก่อนว่าคุณได้ลองอะไรไปแล้วบ้าง แล้วฉันจะช่วยคิดขั้นต่อไปที่ปลอดภัยให้ ถ้าต้องการตรวจแบบครบถ้วน ให้ครูช่วยดูไปด้วยกัน`;
    default:
      return `${displayName}, I want to be careful here. Tell me what you have already tried, and I can help with the next safe step. If you need a full check, ask your educator to review it with you.`;
  }
}

function buildLearnerInferenceUnavailableMessage(displayName: string, locale: string): string {
  switch (locale) {
    case 'zh-CN':
      return `${displayName}，MiloOS 现在还不能提供足够可靠的回答。你可以先分享你目前的思路，或者请老师陪你一起看下一步。`;
    case 'zh-TW':
      return `${displayName}，MiloOS 現在還不能提供足夠可靠的回答。你可以先分享你目前的思路，或者請老師陪你一起看下一步。`;
    case 'th':
      return `${displayName} MiloOS ยังไม่พร้อมให้คำตอบที่เชื่อถือได้ในตอนนี้ ลองเล่าสิ่งที่ทำมาถึงตอนนี้ หรือให้ครูช่วยดูขั้นต่อไปกับคุณ`;
    default:
      return `${displayName}, MiloOS is not ready to give a reliable answer right now. Share your work so far, or ask your educator to review the next step with you.`;
  }
}

function buildLearnerGuardNextSteps(locale: string): string[] {
  switch (locale) {
    case 'zh-CN':
      return ['告诉我你已经试过的步骤。', '指出你卡住的具体位置。', '请老师和你一起检查下一步。'];
    case 'zh-TW':
      return ['告訴我你已經試過的步驟。', '指出你卡住的具體位置。', '請老師和你一起檢查下一步。'];
    case 'th':
      return ['บอกขั้นตอนที่คุณลองไปแล้ว', 'บอกจุดที่คุณติดอยู่', 'ให้ครูช่วยดูขั้นต่อไปกับคุณ'];
    default:
      return ['Tell me which step you already tried.', 'Point to the exact place you got stuck.', 'Ask your educator to review the next step with you.'];
  }
}

function buildAiCoachInput(
  coachMode: string,
  studentInput: string | undefined,
  tags: string[],
  checkpointId?: string,
): string {
  const trimmedInput = typeof studentInput === 'string' ? studentInput.trim() : '';
  const tagsSummary = tags.length > 0 ? `Focus concepts: ${tags.join(', ')}.` : '';
  const checkpointSummary = checkpointId ? `Checkpoint: ${checkpointId}.` : '';
  if (trimmedInput) {
    return `${trimmedInput} ${tagsSummary} ${checkpointSummary}`.replace(/\s+/g, ' ').trim();
  }
  return `The learner needs ${coachMode} support. ${tagsSummary} ${checkpointSummary}`.replace(/\s+/g, ' ').trim();
}

async function generateCoachResponseWithInference(input: {
  siteId: string;
  coachMode: string;
  gradeBand: string;
  displayName: string;
  locale: string;
  traceId: string;
  policyVersion: string;
  studentInput?: string;
  conceptTags: string[];
  checkpointId?: string;
  learnerState?: { cognition: number; engagement: number; integrity: number } | null;
  coppaBand: string;
}): Promise<{
  message: string;
  suggestedNextSteps: string[];
  requiresExplainBack: boolean;
  modelVersion: string;
  traceId?: string;
  policyVersion?: string;
  safetyOutcome?: AiCoachSafetyOutcome;
  safetyReasonCode?: string;
  confidence?: number;
}> {
  const applyLearnerConversationalTone = (text: string, locale: string): string => {
    const normalized = text.replace(/\s+/g, ' ').trim();
    if (!normalized) return normalized;
    if (locale !== 'en') return normalized;
    const hasEncouragement = /\b(great|good|nice|awesome|you can do this|you've got this|well done)\b/i.test(normalized);
    const hasQuestion = /\?/.test(normalized);
    let out = hasEncouragement ? normalized : `Nice effort. ${normalized}`;
    if (!hasQuestion) {
      out = `${out} What should we try first?`;
    }
    return out;
  };

  const learnerMessage = buildAiCoachInput(
    input.coachMode,
    input.studentInput,
    input.conceptTags,
    input.checkpointId,
  );
  const heuristicUnderstanding = __voiceSystemInternals.deriveUnderstandingSignal({
    message: learnerMessage,
    role: 'student',
    safety: {
      safetyOutcome: 'allowed',
      safetyReasonCode: 'none',
      localizedMessage: '',
      category: 'generic',
    },
  });

  const llmResult = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
    service: 'llm',
    body: {
      message: learnerMessage,
      locale: input.locale,
      role: 'learner',
      requesterRole: 'student',
      gradeBand: input.gradeBand,
      maxTokens: 220,
      coachMode: input.coachMode,
      conceptTags: input.conceptTags,
      learnerState: input.learnerState ?? undefined,
      coppaBand: input.coppaBand,
      understanding: {
        intent: heuristicUnderstanding.intent,
        complexity: heuristicUnderstanding.complexity,
        needsScaffold: heuristicUnderstanding.needsScaffold,
        emotionalState: heuristicUnderstanding.emotionalState,
        confidence: heuristicUnderstanding.confidence,
        responseMode: heuristicUnderstanding.responseMode,
        topicTags: heuristicUnderstanding.topicTags,
      },
    },
    context: {
      traceId: input.traceId,
      siteId: input.siteId,
      role: 'learner',
      gradeBand: input.gradeBand,
      locale: input.locale,
      policyVersion: input.policyVersion,
      callerService: 'genAiCoach',
    },
  });

  if (!llmResult.ok) {
    throw new HttpsError('unavailable', 'Internal AI inference is required but unavailable.');
  }

  const llmPayload = extractInternalLlmPayload(llmResult.data);
  if (!llmPayload?.text?.trim()) {
    throw new HttpsError('unavailable', 'Internal AI inference returned an empty response.');
  }

  const certifiedConfidence = clampLearnerConfidence(llmPayload.understanding?.confidence);
  const understanding = mergeAiCoachUnderstanding(
    heuristicUnderstanding as AiCoachUnderstandingSignal,
    llmPayload?.understanding,
  );
  if (certifiedConfidence < MIN_AUTONOMOUS_LEARNER_CONFIDENCE) {
    return {
      message: buildLearnerConfidenceGuardMessage(input.displayName, input.locale),
      suggestedNextSteps: buildLearnerGuardNextSteps(input.locale),
      requiresExplainBack: true,
      modelVersion: llmPayload.modelVersion ?? 'confidence-guard-v1',
      traceId: llmPayload.traceId ?? input.traceId,
      policyVersion: llmPayload.policyVersion ?? input.policyVersion,
      safetyOutcome: llmPayload.safetyOutcome ?? 'escalated',
      safetyReasonCode: llmPayload.safetyReasonCode ?? 'child_low_confidence_guard',
      confidence: certifiedConfidence,
    };
  }

  const candidateText = applyLearnerConversationalTone(llmPayload.text.trim(), input.locale);

  const suggestedNextSteps = llmPayload?.toolSuggestions?.slice(0, 3)
    ?? [];
  const requiresExplainBack = input.coachMode === 'verify' || input.coachMode === 'explain' || input.coppaBand === 'G9_12';

  return {
    message: candidateText,
    suggestedNextSteps,
    requiresExplainBack,
    modelVersion: llmPayload?.modelVersion ?? 'voice-orchestrator-v1',
    traceId: llmPayload?.traceId ?? input.traceId,
    policyVersion: llmPayload?.policyVersion ?? input.policyVersion,
    safetyOutcome: llmPayload?.safetyOutcome ?? 'allowed',
    safetyReasonCode: llmPayload?.safetyReasonCode ?? 'none',
    confidence: understanding.confidence,
  };
}

export const genAiCoach = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const userId = request.auth.uid;
  const profile = await getUserProfile(userId);
  if (!profile || normalizeRoleValue(profile.role) !== 'learner') {
    throw new HttpsError('permission-denied', 'Learner role required for MiloOS.');
  }

  // ── A2) Hard schema validation ──────────────────
  const {
    mode, siteId, gradeBand, sessionOccurrenceId, missionId, checkpointId,
    conceptTags, studentInput, attachments, personaInstructions,
  } = request.data || {};

  const coachMode: string = mode || 'hint';
  const validModes = ['hint', 'verify', 'explain', 'debug'];
  if (!validModes.includes(coachMode)) {
    throw new HttpsError('invalid-argument', `Invalid mode: ${coachMode}. Must be one of: ${validModes.join(', ')}`);
  }
  if (!siteId) {
    throw new HttpsError('invalid-argument', 'siteId is required.');
  }

  await assertActiveSchoolConsent(siteId);
  const { gradeBand: gb, coppaBand, source: gradeBandSource } = resolveGradeBandFromClaims(request, gradeBand);
  validateCoppaMode(coachMode, coppaBand);
  const normalizedAttachments = normalizeAttachments(attachments);
  validateCoppaAttachments(normalizedAttachments, coppaBand);
  validateCoppaInputText(studentInput, coppaBand);

  const tags: string[] = Array.isArray(conceptTags) ? conceptTags : [];
  const displayName = profile.displayName ?? 'learner';
  const policyVersion = AI_COACH_POLICY_VERSION;

  // ── A0) Sense: Load orchestration state (x_hat, P) ──
  let xHat: { cognition: number; engagement: number; integrity: number } | null = null;
  let pSummary: { trace: number; confidence: number } | null = null;
  if (sessionOccurrenceId) {
    const stateDocId = `${userId}_${sessionOccurrenceId}`;
    const stateDoc = await admin.firestore().collection('orchestrationStates').doc(stateDocId).get();
    if (stateDoc.exists) {
      const stateData = stateDoc.data()!;
      xHat = stateData.x_hat || null;
      pSummary = stateData.P ? { trace: stateData.P.trace, confidence: stateData.P.confidence } : null;
    }
  }

  // ── Emit ai_help_opened event ──────────────────
  const aiHelpOpenedRef = await admin.firestore().collection('interactionEvents').add({
    eventType: 'ai_help_opened',
    siteId,
    actorId: userId,
    actorRole: 'learner',
    gradeBand: gb,
    sessionOccurrenceId: sessionOccurrenceId || null,
    missionId: missionId || null,
    checkpointId: checkpointId || null,
    payload: { mode: coachMode, conceptTags: tags, coppaBand, gradeBandSource },
    timestamp: FieldValue.serverTimestamp(),
  });
  const traceId = aiHelpOpenedRef.id;

  // ── A0) Detect: Compute reliability risk (SEP v1 heuristic) ──
  const reliabilityRisk = computeReliabilityRisk(coachMode, xHat, pSummary);

  // ── A0) Detect: Compute autonomy risk (behavioral signals) ──
  const autonomyRisk = await computeAutonomyRisk(userId, sessionOccurrenceId, xHat, gb);
  if (autonomyRisk.signals.length > 0) {
    await persistTelemetryEvent({
      event: 'autonomy_risk.detected',
      userId,
      role: 'learner',
      siteId,
      traceId: aiHelpOpenedRef.id,
      metadata: {
        signalType: autonomyRisk.signals[0],
        signals: autonomyRisk.signals,
        riskScore: autonomyRisk.riskScore,
        threshold: autonomyRisk.threshold,
        service: 'bos_runtime',
      },
    });
  }

  // ── A0) Gate: Check if MVL should block this AI response ──
  const mvlResult = await checkAndMaybeCreateMvl({
    siteId,
    learnerId: userId,
    sessionOccurrenceId,
    gradeBand: gb,
    xHat,
    reliabilityRisk,
    autonomyRisk,
  });

  // ── A0) Control: Generate response via internal inference with BOS/MVL gating ──
  let message: string;
  let requiresExplainBack = false;
  let suggestedNextSteps: string[] = [];
  let modelVersion = 'confidence-guard-v1';
  let responseTraceId = traceId;
  let responsePolicyVersion = policyVersion;
  let safetyOutcome: AiCoachSafetyOutcome = 'allowed';
  let safetyReasonCode = 'none';
  let responseConfidence: number | undefined;

  // If MVL gate is active, intercept with verification prompt
  if (mvlResult.gateActive) {
    await persistTelemetryEvent({
      event: 'sep.verify.prompted',
      userId,
      role: 'learner',
      siteId,
      traceId: aiHelpOpenedRef.id,
      metadata: {
        entropyBand: classifySepEntropyBand(reliabilityRisk),
        signalType: summarizeVerificationSignalType(autonomyRisk, reliabilityRisk),
        riskScore: reliabilityRisk.riskScore,
        threshold: reliabilityRisk.threshold,
        triggerReason: mvlResult.reason,
        service: 'bos_runtime',
      },
    });
    message = generateMvlInterceptMessage(coachMode, displayName, mvlResult.reason, tags);
    requiresExplainBack = true;
    suggestedNextSteps = [
      'Show your work by explaining your reasoning',
      'Provide evidence of your understanding',
      'Try a different approach independently first',
    ];
  } else {
    try {
      const generated = await generateCoachResponseWithInference({
        siteId,
        coachMode,
        gradeBand: gb,
        displayName,
        locale: 'en',
        traceId,
        policyVersion,
        studentInput,
        conceptTags: tags,
        checkpointId,
        learnerState: xHat,
        coppaBand,
      });
      message = generated.message;
      requiresExplainBack = generated.requiresExplainBack;
      suggestedNextSteps = generated.suggestedNextSteps;
      modelVersion = generated.modelVersion;
      responseTraceId = generated.traceId ?? traceId;
      responsePolicyVersion = generated.policyVersion ?? policyVersion;
      safetyOutcome = generated.safetyOutcome ?? 'allowed';
      safetyReasonCode = generated.safetyReasonCode ?? 'none';
      responseConfidence = generated.confidence;
    } catch (error) {
      console.warn('genAiCoach inference guard engaged', { coachMode, siteId, reason: error instanceof Error ? error.message : String(error) });
      message = buildLearnerInferenceUnavailableMessage(displayName, 'en');
      requiresExplainBack = true;
      suggestedNextSteps = buildLearnerGuardNextSteps('en');
      safetyOutcome = 'escalated';
      safetyReasonCode = 'child_inference_unavailable';
    }
  }

  const personaHint = typeof personaInstructions === 'string' ? personaInstructions.trim() : '';
  message = applyKidFriendlyConversationalTone(message, displayName, personaHint);

  if (coppaBand === 'G6_8') {
    suggestedNextSteps = [...new Set([...suggestedNextSteps, 'Connect this response to your checkpoint submission.'])];
  }
  if (coppaBand === 'G9_12') {
    requiresExplainBack = true;
    suggestedNextSteps = [...new Set([...suggestedNextSteps, 'Provide an explain-back and cite your evidence.'])];
  }

  // ── A1) Forbidden check: never give final answers for graded checkpoints ──
  // Internal inference responses stay inside BOS/MVL gating and COPPA mode checks.

  // ── Emit ai_help_used event ──────────────────
  await admin.firestore().collection('interactionEvents').add({
    eventType: 'ai_help_used',
    siteId,
    actorId: userId,
    actorRole: 'learner',
    gradeBand: gb,
    sessionOccurrenceId: sessionOccurrenceId || null,
    missionId: missionId || null,
    checkpointId: checkpointId || null,
    payload: {
      mode: coachMode,
      aiHelpOpenedEventId: aiHelpOpenedRef.id,
      traceId: responseTraceId,
      policyVersion: responsePolicyVersion,
      safetyOutcome,
      safetyReasonCode,
      reliabilityRiskScore: reliabilityRisk.riskScore,
      autonomyRiskScore: autonomyRisk.riskScore,
      mvlGateActive: mvlResult.gateActive,
      ...(responseConfidence != null
        ? {responseConfidence}
        : {}),
      requiresExplainBack,
      coppaBand,
    },
    timestamp: FieldValue.serverTimestamp(),
  });

  // ── Emit ai_coach_response event (audit trail) ──
  await admin.firestore().collection('interactionEvents').add({
    eventType: 'ai_coach_response',
    siteId,
    actorId: userId,
    actorRole: 'learner',
    gradeBand: gb,
    sessionOccurrenceId: sessionOccurrenceId || null,
    missionId: missionId || null,
    checkpointId: checkpointId || null,
    payload: {
      mode: coachMode,
      traceId: responseTraceId,
      policyVersion: responsePolicyVersion,
      safetyOutcome,
      safetyReasonCode,
      hasLearnerState: !!xHat,
      reliabilityRisk: reliabilityRisk,
      autonomyRisk: autonomyRisk,
      mvlGateActive: mvlResult.gateActive,
      mvlEpisodeId: mvlResult.episodeId || null,
      coppaBand,
      gradeBandSource,
      ...(responseConfidence != null
        ? {responseConfidence}
        : {}),
    },
    timestamp: FieldValue.serverTimestamp(),
  });

  // ── A2) Response contract ──────────────────
  return {
    message,
    mode: coachMode,
    requiresExplainBack,
    suggestedNextSteps,
    learnerState: xHat,
    coppaBand,
    risk: {
      reliability: reliabilityRisk,
      autonomy: autonomyRisk,
    },
    mvl: {
      gateActive: mvlResult.gateActive,
      episodeId: mvlResult.episodeId || null,
      reason: mvlResult.reason || null,
    },
    meta: {
      version: '1.0.0',
      traceId: responseTraceId,
      modelVersion,
      gradeBand: gb,
      gradeBandSource,
      coppaBand,
      conceptTags: tags,
      attachments: normalizedAttachments,
      aiHelpOpenedEventId: aiHelpOpenedRef.id,
    },
    metadata: {
      traceId: responseTraceId,
      policyVersion: responsePolicyVersion,
      safetyOutcome,
      safetyReasonCode,
      modelVersion,
    },
  };
});

export const submitExplainBack = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const userId = request.auth.uid;
  const profile = await getUserProfile(userId);
  if (!profile || normalizeRoleValue(profile.role) !== 'learner') {
    throw new HttpsError(
      'permission-denied',
      'Learner role required for explain-back submissions.',
    );
  }

  const siteId = typeof request.data?.siteId === 'string'
    ? request.data.siteId.trim()
    : '';
  const interactionId = typeof request.data?.interactionId === 'string'
    ? request.data.interactionId.trim()
    : '';
  const explainBack = typeof request.data?.explainBack === 'string'
    ? request.data.explainBack.trim()
    : '';

  if (!siteId) {
    throw new HttpsError('invalid-argument', 'siteId is required.');
  }
  if (!interactionId) {
    throw new HttpsError('invalid-argument', 'interactionId is required.');
  }
  if (!explainBack) {
    throw new HttpsError('invalid-argument', 'explainBack is required.');
  }

  await assertActiveSchoolConsent(siteId);

  let openedSnap = await admin.firestore().collection('interactionEvents').doc(interactionId).get();
  let openedEventId = interactionId;
  if (!openedSnap.exists) {
    const traceMatchSnap = await admin.firestore()
      .collection('interactionEvents')
      .where('eventType', '==', 'ai_help_opened')
      .where('siteId', '==', siteId)
      .where('actorId', '==', userId)
      .where('traceId', '==', interactionId)
      .limit(1)
      .get();
    if (!traceMatchSnap.empty) {
      openedSnap = traceMatchSnap.docs[0];
      openedEventId = openedSnap.id;
    }
  }
  if (!openedSnap.exists) {
    throw new HttpsError('not-found', 'MiloOS session not found.');
  }

  const openedData = openedSnap.data() as Record<string, unknown>;
  if (openedData.eventType !== 'ai_help_opened') {
    throw new HttpsError(
      'failed-precondition',
      'interactionId must reference a MiloOS session.',
    );
  }
  if (openedData.actorId !== userId) {
    throw new HttpsError('permission-denied', 'MiloOS session ownership mismatch.');
  }
  if (openedData.siteId !== siteId) {
    throw new HttpsError('permission-denied', 'Site access denied.');
  }

  const explainBackEvent = buildExplainBackSubmittedEvent({
    actorId: userId,
    aiHelpOpenedEventId: openedEventId,
    explainBack,
    openedEvent: {
      siteId,
      gradeBand: openedData.gradeBand,
      sessionOccurrenceId: openedData.sessionOccurrenceId,
      missionId: openedData.missionId,
      checkpointId: openedData.checkpointId,
      payload: (openedData.payload as Record<string, unknown> | undefined) ?? {},
    },
  });

  await admin.firestore().collection('interactionEvents').add({
    ...explainBackEvent,
    timestamp: FieldValue.serverTimestamp(),
  });

  return {
    approved: true,
    feedback: explainBackRecordedFeedback,
  };
});

async function getUserProfile(uid: string) {
  const snap = await admin.firestore().collection(USERS_COLLECTION).doc(uid).get();
  return snap.data() as UserRecord | undefined;
}

async function requireRoleAndSite(authUid: string | undefined, allowedRoles: Role[], siteId?: string) {
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const profile = await getUserProfile(authUid);
  const canonicalRole = normalizeRoleValue(profile?.role);
  if (!profile || !canonicalRole || !allowedRoles.includes(canonicalRole)) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }
  if (siteId && siteId.trim().length > 0) {
    const inSites = (profile.siteIds ?? []).includes(siteId) || profile.activeSiteId === siteId;
    if (!inSites) {
      throw new HttpsError('permission-denied', 'Site access denied.');
    }
  }
  return {
    uid: authUid,
    role: canonicalRole,
    profile: {
      ...profile,
      role: canonicalRole,
    },
  };
}

function normalizeTelemetryKey(key: string): string {
  return key.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
}

function toHeaderString(value: string | string[] | undefined): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (Array.isArray(value) && value.length > 0) {
    return toHeaderString(value[0]);
  }
  return undefined;
}

function extractTraceIdFromHeader(headerValue: string | undefined): string | undefined {
  if (!headerValue) return undefined;
  const traceId = headerValue.split('/')[0]?.trim();
  return traceId && traceId.length > 0 ? traceId : undefined;
}

function resolveTelemetryEnv(): 'dev' | 'staging' | 'prod' {
  const raw = String(process.env.VIBE_ENV || process.env.APP_ENV || process.env.NODE_ENV || '')
    .trim()
    .toLowerCase();
  if (raw === 'production' || raw === 'prod') return 'prod';
  if (raw === 'staging' || raw === 'stage') return 'staging';
  return 'dev';
}

function toCanonicalTelemetryGradeBand(rawValue: unknown): 'k5' | 'ms' | 'hs' {
  if (typeof rawValue === 'number' && Number.isFinite(rawValue)) {
    if (rawValue <= 5) return 'k5';
    if (rawValue <= 8) return 'ms';
    return 'hs';
  }
  if (typeof rawValue !== 'string') return 'ms';
  const normalized = rawValue.trim().toLowerCase();
  if (
    normalized === 'k5' ||
    normalized === 'k-5' ||
    normalized === 'k_5' ||
    normalized === 'grades_1_3' ||
    normalized === 'grades_4_6'
  ) {
    return 'k5';
  }
  if (
    normalized === 'ms' ||
    normalized === '6-8' ||
    normalized === 'g6_8' ||
    normalized === 'grades_7_9'
  ) {
    return 'ms';
  }
  if (
    normalized === 'hs' ||
    normalized === '9-12' ||
    normalized === 'g9_12' ||
    normalized === 'grades_10_12'
  ) {
    return 'hs';
  }
  return 'ms';
}

function normalizeTelemetryLocale(rawValue: unknown): 'en' | 'zh-CN' | 'zh-TW' | 'th' {
  if (typeof rawValue !== 'string') return 'en';
  const normalized = rawValue.trim();
  if (normalized === 'en' || normalized === 'zh-CN' || normalized === 'zh-TW' || normalized === 'th') {
    return normalized;
  }
  const lowered = normalized.toLowerCase();
  if (lowered.startsWith('zh-tw') || lowered.startsWith('zh-hk') || lowered.startsWith('zh-hant')) {
    return 'zh-TW';
  }
  if (lowered.startsWith('zh')) return 'zh-CN';
  if (lowered.startsWith('th')) return 'th';
  return 'en';
}

function resolveTelemetryService(metadata: Record<string, unknown> | undefined): string {
  const value = metadata?.service;
  if (typeof value === 'string' && value.trim().length > 0) {
    return value.trim();
  }
  return 'scholesa-api';
}

function resolveTelemetryLocale(metadata: Record<string, unknown> | undefined): 'en' | 'zh-CN' | 'zh-TW' | 'th' {
  return normalizeTelemetryLocale(metadata?.locale ?? metadata?.targetLocale);
}

function resolveTelemetryGradeBand(
  metadata: Record<string, unknown> | undefined,
  role: TelemetryRole,
): 'k5' | 'ms' | 'hs' {
  const raw = metadata?.gradeBand ?? metadata?.grade ?? metadata?.grade_level;
  if (raw !== undefined) {
    return toCanonicalTelemetryGradeBand(raw);
  }
  if (role === 'learner') return 'ms';
  return 'hs';
}

function isTelemetryOriginAllowed(origin: string | undefined): boolean {
  if (!origin) return false;
  return TELEMETRY_CALLABLE_CORS.some((allowedOrigin) => {
    if (typeof allowedOrigin === 'string') {
      return allowedOrigin === origin;
    }
    return allowedOrigin.test(origin);
  });
}

function shouldRedactTelemetryKey(keyPath: string): boolean {
  const leaf = keyPath.split('.').pop() ?? keyPath;
  const normalized = normalizeTelemetryKey(leaf.replace(/\[\d+\]/g, ''));
  return TELEMETRY_PII_KEY_BLOCKLIST.has(normalized);
}

function sanitizeTelemetryValue(
  value: unknown,
  keyPath: string,
  depth: number,
  redactedPaths: Set<string>,
): unknown {
  if (depth > TELEMETRY_MAX_METADATA_DEPTH) {
    redactedPaths.add(`${keyPath}:depth_limit`);
    return null;
  }

  if (value === null || value === undefined) return null;

  if (typeof value === 'string') {
    if (shouldRedactTelemetryKey(keyPath)) {
      redactedPaths.add(keyPath);
      return '[redacted]';
    }
    const trimmed = value.trim();
    if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(trimmed)) {
      redactedPaths.add(keyPath);
      return '[redacted_email]';
    }
    const digits = trimmed.replace(/\D/g, '');
    if (digits.length >= 10 && digits.length <= 15) {
      redactedPaths.add(keyPath);
      return '[redacted_phone]';
    }
    return trimmed.length > TELEMETRY_MAX_STRING_LENGTH
      ? `${trimmed.slice(0, TELEMETRY_MAX_STRING_LENGTH)}...`
      : trimmed;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (Array.isArray(value)) {
    return value
      .slice(0, TELEMETRY_MAX_COLLECTION_LENGTH)
      .map((item, index) => sanitizeTelemetryValue(item, `${keyPath}[${index}]`, depth + 1, redactedPaths));
  }

  if (typeof value === 'object') {
    const sanitized: Record<string, unknown> = {};
    let count = 0;
    for (const [key, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      if (count >= TELEMETRY_MAX_COLLECTION_LENGTH) break;
      const nestedPath = keyPath ? `${keyPath}.${key}` : key;
      if (shouldRedactTelemetryKey(nestedPath)) {
        redactedPaths.add(nestedPath);
        continue;
      }
      sanitized[key] = sanitizeTelemetryValue(nestedValue, nestedPath, depth + 1, redactedPaths);
      count += 1;
    }
    return sanitized;
  }

  return String(value);
}

function sanitizeTelemetryMetadata(
  metadata: Record<string, unknown> | undefined,
): { metadata: Record<string, unknown>; redactedPaths: string[] } {
  const source = metadata ?? {};
  const redactedPaths = new Set<string>();
  const sanitized: Record<string, unknown> = {};
  let count = 0;

  for (const [key, value] of Object.entries(source)) {
    if (count >= TELEMETRY_MAX_COLLECTION_LENGTH) break;
    if (shouldRedactTelemetryKey(key)) {
      redactedPaths.add(key);
      continue;
    }
    sanitized[key] = sanitizeTelemetryValue(value, key, 0, redactedPaths);
    count += 1;
  }

  return {
    metadata: sanitized,
    redactedPaths: Array.from(redactedPaths.values()),
  };
}

async function persistTelemetryEvent(params: {
  event: string;
  userId: string;
  role?: TelemetryRole;
  siteId?: string;
  metadata?: Record<string, unknown>;
  requestId?: string;
  traceId?: string;
}) {
  const { event, userId, role, siteId, metadata, requestId, traceId } = params;
  const { metadata: sanitizedMetadata, redactedPaths } = sanitizeTelemetryMetadata(metadata);
  const effectiveUserId = userId && userId.trim().length > 0 ? userId : 'system';
  const effectiveSiteId = siteId && siteId.trim().length > 0 ? siteId.trim() : TELEMETRY_UNSCOPED_SITE_ID;
  const normalizedRole = role === 'system' ? 'system' : normalizeRoleValue(role);
  const effectiveRole: TelemetryRole = normalizedRole ?? 'system';
  const effectiveRequestId = requestId ?? `telemetry-${randomUUID()}`;
  const effectiveTraceId = traceId ?? effectiveRequestId;
  const schemaRole = toCanonicalTelemetryRole(effectiveRole);
  const telemetryService = resolveTelemetryService(sanitizedMetadata);
  const telemetryEnv = resolveTelemetryEnv();
  const locale = resolveTelemetryLocale(sanitizedMetadata);
  const gradeBand = resolveTelemetryGradeBand(sanitizedMetadata, effectiveRole);
  const timestampIso = new Date().toISOString();
  return admin.firestore().collection(TELEMETRY_COLLECTION).add({
    event,
    eventType: event,
    userId: effectiveUserId,
    role: schemaRole,
    roleCanonical: schemaRole,
    actorRole: effectiveRole,
    service: telemetryService,
    env: telemetryEnv,
    siteId: effectiveSiteId,
    gradeBand,
    locale,
    traceId: effectiveTraceId,
    metadata: {
      ...sanitizedMetadata,
      requestId: effectiveRequestId,
      traceId: effectiveTraceId,
      service: telemetryService,
      env: telemetryEnv,
      siteId: effectiveSiteId,
      role: schemaRole,
      requesterRole: effectiveRole,
      locale,
      gradeBand,
      roleCanonical: schemaRole,
      eventType: event,
      timestamp: timestampIso,
      timestampIso,
      redactionApplied: redactedPaths.length > 0,
      redactedPathCount: redactedPaths.length,
    },
    timestamp: FieldValue.serverTimestamp(),
    timestampIso,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function handleTelemetry(request: CallableRequest) {
  const event = typeof request.data?.event === 'string' ? request.data.event : undefined;
  if (!event || !ALLOWED_TELEMETRY_EVENTS.has(event)) {
    throw new HttpsError('invalid-argument', 'Invalid event name.');
  }

  const metadata = request.data?.metadata;
  if (metadata !== undefined && (typeof metadata !== 'object' || Array.isArray(metadata))) {
    throw new HttpsError('invalid-argument', 'metadata must be an object if provided');
  }

  const metadataRecord = metadata as Record<string, unknown> | undefined;
  const requestId = toHeaderString(request.rawRequest?.headers?.['x-request-id']);
  const traceId = extractTraceIdFromHeader(toHeaderString(request.rawRequest?.headers?.['x-cloud-trace-context']));
  const origin = toHeaderString(request.rawRequest?.headers?.origin);
  const auth = request.auth;
  if (!auth) {
    if (!PUBLIC_TELEMETRY_EVENTS.has(event)) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    if (!isTelemetryOriginAllowed(origin)) {
      throw new HttpsError('permission-denied', 'Telemetry origin not allowed.');
    }

    await persistTelemetryEvent({
      event,
      userId: 'anonymous',
      role: 'system',
      siteId: TELEMETRY_UNSCOPED_SITE_ID,
      metadata: {
        ...(metadataRecord ?? {}),
        authState: 'anonymous',
        ...(origin ? { origin } : {}),
      },
      requestId,
      traceId,
    });

    return { status: 'ok' };
  }

  const userProfile = await getUserProfile(auth.uid);
  if (!userProfile || !userProfile.role) {
    throw new HttpsError('permission-denied', 'User profile missing role.');
  }
  const role = normalizeRoleValue(userProfile.role);
  if (!role) {
    throw new HttpsError('permission-denied', 'User role is not allowed.');
  }

  const siteFromRequest = typeof request.data?.siteId === 'string' && request.data.siteId.trim().length > 0
    ? request.data.siteId.trim()
    : undefined;
  if (siteFromRequest) {
    const allowed = (userProfile.siteIds ?? []).includes(siteFromRequest) || userProfile.activeSiteId === siteFromRequest;
    if (!allowed) {
      throw new HttpsError('permission-denied', 'Site access denied.');
    }
  }

  const siteId = siteFromRequest ?? userProfile.activeSiteId ?? (userProfile.siteIds?.[0] ?? TELEMETRY_UNSCOPED_SITE_ID);
  if (siteId === TELEMETRY_UNSCOPED_SITE_ID && role !== 'hq') {
    throw new HttpsError('permission-denied', 'No active site context available.');
  }

  await persistTelemetryEvent({
    event,
    userId: auth.uid,
    role,
    siteId,
    metadata: metadataRecord,
    requestId,
    traceId,
  });

  return { status: 'ok' };
}

export const logTelemetryEvent = onCall(TELEMETRY_CALLABLE_OPTIONS, async (request: CallableRequest) => handleTelemetry(request));

// Backwards compatibility: keep the old callable name pointing to telemetry pipeline.
export const logAnalyticsEvent = onCall(TELEMETRY_CALLABLE_OPTIONS, async (request: CallableRequest) => handleTelemetry(request));

type TelemetryDashboardPeriod = 'week' | 'month' | 'quarter' | 'year';

const DASHBOARD_PERIOD_DAYS: Record<TelemetryDashboardPeriod, number> = {
  week: 7,
  month: 30,
  quarter: 90,
  year: 365,
};

const ACCOUNTABILITY_EVENT_TYPES = [
  'attendance.recorded',
  'mission.attempt.submitted',
  'message.sent',
] as const;

const EDUCATOR_REVIEW_SLA_HOURS = 48;

function normalizeDashboardPeriod(value: unknown): TelemetryDashboardPeriod {
  if (value === 'week' || value === 'month' || value === 'quarter' || value === 'year') {
    return value;
  }
  return 'week';
}

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function buildUtcDateKeys(startUtcDay: Date, days: number): string[] {
  const keys: string[] = [];
  for (let index = 0; index < days; index++) {
    const date = new Date(startUtcDay);
    date.setUTCDate(startUtcDay.getUTCDate() + index);
    keys.push(date.toISOString().slice(0, 10));
  }
  return keys;
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asTimestamp(value: unknown): Timestamp | null {
  if (value instanceof Timestamp) return value;
  return null;
}

function roundTo(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

function applySiteFilter(query: FirebaseFirestore.Query, siteId?: string): FirebaseFirestore.Query {
  if (!siteId) return query;
  return query.where('siteId', '==', siteId);
}

export const getTelemetryDashboardMetrics = onCall(async (request: CallableRequest<{
  siteId?: string;
  period?: string;
}>) => {
  const authUid = request.auth?.uid;
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const userProfile = await getUserProfile(authUid);
  if (!userProfile || !userProfile.role) {
    throw new HttpsError('permission-denied', 'User profile missing role.');
  }
  const profileRole = normalizeRoleValue(userProfile.role);
  if (!profileRole) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }

  const allowedRoles: Role[] = ['hq', 'site', 'educator'];
  if (!allowedRoles.includes(profileRole)) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  let effectiveSiteId: string | undefined;

  if (requestedSiteId.length > 0) {
    if (profileRole === 'hq') {
      effectiveSiteId = requestedSiteId;
    } else {
      const hasSiteAccess = (userProfile.siteIds ?? []).includes(requestedSiteId) || userProfile.activeSiteId === requestedSiteId;
      if (!hasSiteAccess) {
        throw new HttpsError('permission-denied', 'Site access denied.');
      }
      effectiveSiteId = requestedSiteId;
    }
  } else if (profileRole !== 'hq') {
    effectiveSiteId = userProfile.activeSiteId ?? userProfile.siteIds?.[0];
    if (!effectiveSiteId) {
      throw new HttpsError('permission-denied', 'No active site context available.');
    }
  }

  const period = normalizeDashboardPeriod(request.data?.period);
  const periodDays = DASHBOARD_PERIOD_DAYS[period];

  const now = new Date();
  const periodStart = startOfUtcDay(now);
  periodStart.setUTCDate(periodStart.getUTCDate() - (periodDays - 1));
  const periodStartTimestamp = Timestamp.fromDate(periodStart);

  const accountabilityStart = startOfUtcDay(now);
  accountabilityStart.setUTCDate(accountabilityStart.getUTCDate() - 6);
  const accountabilityStartTimestamp = Timestamp.fromDate(accountabilityStart);

  const telemetryCollection = admin.firestore().collection(TELEMETRY_COLLECTION);

  let attendanceQuery: FirebaseFirestore.Query = telemetryCollection
    .where('event', '==', 'attendance.recorded')
    .where('createdAt', '>=', periodStartTimestamp);
  attendanceQuery = applySiteFilter(attendanceQuery, effectiveSiteId);

  let accountabilityQuery: FirebaseFirestore.Query = telemetryCollection
    .where('event', 'in', [...ACCOUNTABILITY_EVENT_TYPES])
    .where('createdAt', '>=', accountabilityStartTimestamp);
  accountabilityQuery = applySiteFilter(accountabilityQuery, effectiveSiteId);

  let reviewQuery: FirebaseFirestore.Query = telemetryCollection
    .where('event', '==', 'educator.review.completed')
    .where('createdAt', '>=', periodStartTimestamp);
  reviewQuery = applySiteFilter(reviewQuery, effectiveSiteId);

  let interventionQuery: FirebaseFirestore.Query = telemetryCollection
    .where('event', '==', 'support.outcome.logged')
    .where('createdAt', '>=', periodStartTimestamp);
  interventionQuery = applySiteFilter(interventionQuery, effectiveSiteId);

  const [attendanceSnapshot, accountabilitySnapshot, reviewSnapshot, interventionSnapshot] = await Promise.all([
    attendanceQuery.get(),
    accountabilityQuery.get(),
    reviewQuery.get(),
    interventionQuery.get(),
  ]);

  const attendanceByDate = new Map<string, { events: number; records: number; present: number; total: number }>();

  for (const doc of attendanceSnapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    const createdAt = asTimestamp(data.createdAt);
    if (!createdAt) continue;

    const dateKey = createdAt.toDate().toISOString().slice(0, 10);
    const bucket = attendanceByDate.get(dateKey) ?? { events: 0, records: 0, present: 0, total: 0 };

    bucket.events += 1;

    const metadata = asRecord(data.metadata);
    const recordsCount = asNumber(metadata.records_count);
    if (recordsCount !== null && recordsCount > 0) {
      const roundedRecords = Math.round(recordsCount);
      bucket.records += roundedRecords;
      bucket.total += roundedRecords;
    }

    const statusCounts = asRecord(metadata.status_counts);
    const presentCount = asNumber(statusCounts.present);
    if (presentCount !== null && presentCount > 0) {
      bucket.present += Math.round(presentCount);
    }

    attendanceByDate.set(dateKey, bucket);
  }

  const attendanceTrend = buildUtcDateKeys(periodStart, periodDays).map((dateKey) => {
    const bucket = attendanceByDate.get(dateKey);
    const total = bucket?.total ?? null;
    const presentRate = total != null && total > 0
      ? roundTo(((bucket?.present ?? 0) / total) * 100, 1)
      : null;
    return {
      date: dateKey,
      records: bucket?.records ?? null,
      events: bucket?.events ?? null,
      presentRate,
    };
  });

  const accountabilityByDate = new Map<string, Set<string>>();

  for (const doc of accountabilitySnapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    const createdAt = asTimestamp(data.createdAt);
    const event = typeof data.event === 'string' ? data.event : '';
    if (!createdAt || !event) continue;

    const dateKey = createdAt.toDate().toISOString().slice(0, 10);
    const eventSet = accountabilityByDate.get(dateKey) ?? new Set<string>();
    eventSet.add(event);
    accountabilityByDate.set(dateKey, eventSet);
  }

  const accountabilityDateKeys = buildUtcDateKeys(accountabilityStart, 7);
  let adherenceAccumulator = 0;
  for (const dateKey of accountabilityDateKeys) {
    const observedEvents = accountabilityByDate.get(dateKey)?.size ?? 0;
    adherenceAccumulator += observedEvents / ACCOUNTABILITY_EVENT_TYPES.length;
  }
  const weeklyAccountabilityAdherenceRate = accountabilityByDate.size > 0
    ? roundTo(
        (adherenceAccumulator / accountabilityDateKeys.length) * 100,
        1,
      )
    : null;

  let reviewCount = 0;
  let reviewWithinSlaCount = 0;
  let turnaroundMinutesTotal = 0;

  for (const doc of reviewSnapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    const metadata = asRecord(data.metadata);
    const turnaroundMinutes = asNumber(metadata.turnaround_minutes);
    if (turnaroundMinutes === null || turnaroundMinutes < 0) continue;

    reviewCount += 1;
    turnaroundMinutesTotal += turnaroundMinutes;
    if (turnaroundMinutes <= EDUCATOR_REVIEW_SLA_HOURS * 60) {
      reviewWithinSlaCount += 1;
    }
  }

  const educatorReviewTurnaroundHoursAvg = reviewCount > 0
    ? roundTo((turnaroundMinutesTotal / reviewCount) / 60, 2)
    : null;

  const educatorReviewWithinSlaRate = reviewCount > 0
    ? roundTo((reviewWithinSlaCount / reviewCount) * 100, 1)
    : null;

  let interventionTotal = 0;
  let interventionHelpedTotal = 0;

  for (const doc of interventionSnapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    const metadata = asRecord(data.metadata);
    const outcome = typeof metadata.outcome === 'string' ? metadata.outcome.trim().toLowerCase() : '';
    if (!outcome) continue;

    interventionTotal += 1;
    if (outcome === 'helped') {
      interventionHelpedTotal += 1;
    }
  }

  const interventionHelpedRate = interventionTotal > 0
    ? roundTo((interventionHelpedTotal / interventionTotal) * 100, 1)
    : null;

  return {
    metrics: {
      weeklyAccountabilityAdherenceRate,
      educatorReviewTurnaroundHoursAvg,
      educatorReviewWithinSlaRate,
      educatorReviewSlaHours: EDUCATOR_REVIEW_SLA_HOURS,
      interventionHelpedRate,
      interventionTotal,
      attendanceTrend,
    },
    period,
    siteId: effectiveSiteId ?? null,
  };
});

function parseDateFromUnknown(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return new Date(value);
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) {
      return new Date(parsed);
    }
  }
  return null;
}

function stringListFromUnknown(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is string => typeof entry === 'string')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function checkpointMappingsFromUnknown(value: unknown): Array<Record<string, string>> {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === 'object' && !Array.isArray(entry))
    .map((entry) => ({
      phase: typeof entry.phase === 'string' ? entry.phase.trim() : '',
      guidance: typeof entry.guidance === 'string' ? entry.guidance.trim() : '',
    }))
    .filter((entry) => entry.phase.length > 0 || entry.guidance.length > 0);
}

function normalizeParentPillarKey(value: unknown): 'futureSkills' | 'leadership' | 'impact' | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'future_skills':
    case 'future skills':
    case 'futureskills':
      return 'futureSkills';
    case 'leadership':
    case 'leadership_agency':
    case 'leadership & agency':
      return 'leadership';
    case 'impact':
    case 'impact_innovation':
    case 'impact & innovation':
      return 'impact';
    default:
      return null;
  }
}

function parentPillarLabelFromCodes(value: unknown): string {
  if (!Array.isArray(value)) return 'Future Skills';
  for (const entry of value) {
    switch (normalizeParentPillarKey(entry)) {
      case 'futureSkills':
        return 'Future Skills';
      case 'leadership':
        return 'Leadership & Agency';
      case 'impact':
        return 'Impact & Innovation';
      default:
        break;
    }
  }
  return 'Future Skills';
}

function formatCompactCount(value: number): string {
  if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(1)}M`;
  }
  if (value >= 1_000) {
    return `${(value / 1_000).toFixed(1)}K`;
  }
  return String(value);
}

function hasSiteAccess(profile: UserRecord, siteId: string): boolean {
  if (!siteId.trim()) return false;
  return (profile.siteIds ?? []).includes(siteId) || profile.activeSiteId === siteId;
}

function resolveRoleSiteId(
  profile: UserRecord,
  actorRole: Role,
  requestedSiteId: string | undefined,
): string | undefined {
  if (requestedSiteId && requestedSiteId.trim().length > 0) {
    if (actorRole === 'hq' || hasSiteAccess(profile, requestedSiteId)) {
      return requestedSiteId;
    }
    throw new HttpsError('permission-denied', 'Site access denied.');
  }
  if (actorRole === 'hq') {
    return undefined;
  }
  const siteId = profile.activeSiteId ?? profile.siteIds?.[0];
  if (!siteId) {
    throw new HttpsError('permission-denied', 'No active site context available.');
  }
  return siteId;
}

async function fetchUsersByIds(userIds: string[]): Promise<Array<{ id: string; data: UserRecord }>> {
  const uniqueIds = Array.from(new Set(userIds.filter((id) => typeof id === 'string' && id.trim().length > 0)));
  if (uniqueIds.length === 0) return [];
  const docs = await Promise.all(
    uniqueIds.map((id) => admin.firestore().collection(USERS_COLLECTION).doc(id).get()),
  );
  return docs
    .filter((doc) => doc.exists)
    .map((doc) => ({ id: doc.id, data: doc.data() as UserRecord }));
}

function toRosterItem(id: string, data: UserRecord): Record<string, unknown> {
  const displayName = typeof data.displayName === 'string' && data.displayName.trim().length > 0
    ? data.displayName.trim()
    : typeof data.email === 'string' && data.email.trim().length > 0
    ? data.email.trim()
    : null;
  return {
    id,
    uid: id,
    displayName,
    email: data.email ?? null,
    role: normalizeRoleValue(data.role),
    siteIds: data.siteIds ?? [],
    activeSiteId: data.activeSiteId ?? null,
  };
}

async function collectParentLinkedLearnerIds(params: {
  parentId: string;
  siteId?: string;
}): Promise<string[]> {
  const { parentId, siteId } = params;
  const learnerIds = new Set<string>();

  const parentDoc = await admin.firestore().collection(USERS_COLLECTION).doc(parentId).get();
  if (parentDoc.exists) {
    const parentData = parentDoc.data() as UserRecord;
    for (const learnerId of toStringArray(parentData.learnerIds)) {
      learnerIds.add(learnerId);
    }
  }

  try {
    let guardianQuery: FirebaseFirestore.Query = admin
      .firestore()
      .collection('guardianLinks')
      .where('parentId', '==', parentId);
    if (siteId && siteId.trim().length > 0) {
      guardianQuery = guardianQuery.where('siteId', '==', siteId);
    }
    const guardianLinks = await guardianQuery.get();
    for (const doc of guardianLinks.docs) {
      const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
      if (learnerId) learnerIds.add(learnerId);
    }
  } catch {
    // Guardian links are best-effort for compatibility with legacy schemas.
  }

  try {
    const usersByParent = await admin
      .firestore()
      .collection(USERS_COLLECTION)
      .where('parentIds', 'array-contains', parentId)
      .get();
    for (const doc of usersByParent.docs) {
      const role = normalizeRoleValue(doc.data().role);
      if (role === 'learner') {
        learnerIds.add(doc.id);
      }
    }
  } catch {
    // Keep deterministic fallback behavior.
  }

  if (!siteId || !siteId.trim()) {
    return Array.from(learnerIds.values());
  }

  const linkedUsers = await fetchUsersByIds(Array.from(learnerIds.values()));
  return linkedUsers
    .filter(({ data }) => hasSiteAccess(data, siteId))
    .map(({ id }) => id);
}

async function buildParentLearnerSummary(params: {
  learnerId: string;
  siteId?: string;
}): Promise<Record<string, unknown> | null> {
  const { learnerId, siteId } = params;
  const learnerDoc = await admin.firestore().collection(USERS_COLLECTION).doc(learnerId).get();
  if (!learnerDoc.exists) return null;
  const learnerData = learnerDoc.data() as UserRecord;
  if (normalizeRoleValue(learnerData.role) !== 'learner') return null;
  if (siteId && !hasSiteAccess(learnerData, siteId)) return null;

  const now = new Date();
  const progressDoc = await admin.firestore().collection('learnerProgress').doc(learnerId).get();
  const progressData = progressDoc.exists
    ? (progressDoc.data() as Record<string, unknown>)
    : {};

  let recentActivities: Array<Record<string, unknown>> = [];
  try {
    const activitiesSnap = await admin
      .firestore()
      .collection('activities')
      .where('learnerId', '==', learnerId)
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    recentActivities = activitiesSnap.docs.map((doc) => {
      const data = doc.data() as Record<string, unknown>;
      return {
        id: doc.id,
        title: typeof data.title === 'string' ? data.title : '',
        description: typeof data.description === 'string' ? data.description : '',
        type: typeof data.type === 'string' ? data.type : 'activity',
        emoji: typeof data.emoji === 'string' ? data.emoji : '📝',
        timestamp: parseDateFromUnknown(data.timestamp)?.toISOString() ?? now.toISOString(),
      };
    });
  } catch {
    recentActivities = [];
  }

  const upcomingEvents = await loadParentUpcomingEvents({ learnerId, siteId, now });

  let attendanceRate: number | null = null;
  try {
    const attendanceSnap = await admin
      .firestore()
      .collection('attendanceRecords')
      .where('learnerId', '==', learnerId)
      .orderBy('timestamp', 'desc')
      .limit(30)
      .get();
    const total = attendanceSnap.size;
    const present = attendanceSnap.docs.filter((doc) => doc.data().status === 'present').length;
    attendanceRate = total > 0 ? present / total : null;
  } catch {
    attendanceRate = null;
  }

  const [portfolioSnap, evidenceSnap, masterySnap, growthSnap, reflectionsSnap, missionAttemptsSnap, interactionEventsSnap, capabilitiesSnap] =
    await Promise.all([
      admin.firestore().collection('portfolioItems').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('evidenceRecords').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('capabilityMastery').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('capabilityGrowthEvents').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('learnerReflections').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('missionAttempts').where('learnerId', '==', learnerId).limit(100).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      admin.firestore().collection('interactionEvents').where('actorId', '==', learnerId).limit(400).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
      siteId
        ? admin.firestore().collection('capabilities').where('siteId', '==', siteId).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] }))
        : Promise.resolve({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] }),
    ]);

  const includeForSite = (data: Record<string, unknown>): boolean => {
    if (!siteId) return true;
    const rowSiteId = typeof data.siteId === 'string' ? data.siteId.trim() : '';
    return !rowSiteId || rowSiteId === siteId;
  };

  const portfolioRows: Array<Record<string, unknown>> = portfolioSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
    .filter(includeForSite);
  const evidenceRows: Array<Record<string, unknown>> = evidenceSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
    .filter(includeForSite);
  const masteryRows: Array<Record<string, unknown>> = masterySnap.docs
    .map((doc) => doc.data() as Record<string, unknown>)
    .filter(includeForSite);
  const growthRows: Array<Record<string, unknown>> = growthSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
    .filter(includeForSite);
  const reflectionRows: Array<Record<string, unknown>> = reflectionsSnap.docs
    .map((doc) => doc.data() as Record<string, unknown>)
    .filter(includeForSite);
  const missionAttemptRows: Array<Record<string, unknown>> = missionAttemptsSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
    .filter(includeForSite);
  const interactionEventRows: Array<Record<string, unknown>> = interactionEventsSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
    .filter(includeForSite);

  // Build authoritative capability ID → title map from the capabilities collection
  const capabilityTitlesById = new Map<string, string>();
  for (const doc of capabilitiesSnap.docs) {
    const data = doc.data();
    const title = typeof data.title === 'string' ? data.title.trim() : '';
    if (title) capabilityTitlesById.set(doc.id, title);
  }

  const reviewerIds = Array.from(
    new Set(
      [
        ...growthRows.map((row) => (typeof row.educatorId === 'string' ? row.educatorId.trim() : '')),
        ...portfolioRows.map((row) => (typeof row.educatorId === 'string' ? row.educatorId.trim() : '')),
        ...missionAttemptRows.map((row) => (typeof row.reviewedBy === 'string' ? row.reviewedBy.trim() : '')),
      ].filter(Boolean),
    ),
  );
  const reviewerNameEntries = await Promise.all(
    reviewerIds.map(async (reviewerId) => {
      try {
        const reviewerSnap = await admin.firestore().collection('users').doc(reviewerId).get();
        const reviewerData = reviewerSnap.data() as Record<string, unknown> | undefined;
        const displayName = typeof reviewerData?.displayName === 'string' ? reviewerData.displayName.trim() : '';
        const email = typeof reviewerData?.email === 'string' ? reviewerData.email.trim() : '';
        return [reviewerId, displayName || email] as const;
      } catch {
        return [reviewerId, ''] as const;
      }
    }),
  );
  const reviewerNames = Object.fromEntries(
    reviewerNameEntries.filter((entry) => Boolean(entry[1])),
  ) as Record<string, string>;

  const proofBundleIds = Array.from(
    new Set(
      [
        ...missionAttemptRows.map((row) => (typeof row.proofBundleId === 'string' ? row.proofBundleId.trim() : '')),
        ...portfolioRows.map((row) => (typeof row.proofBundleId === 'string' ? row.proofBundleId.trim() : '')),
      ].filter(Boolean),
    ),
  );
  const proofBundleEntries = await Promise.all(
    proofBundleIds.map(async (proofBundleId) => {
      try {
        const proofBundleSnap = await admin
          .firestore()
          .collection('proofOfLearningBundles')
          .doc(proofBundleId)
          .get();
        if (!proofBundleSnap.exists) {
          return [proofBundleId, null] as const;
        }
        return [proofBundleId, { id: proofBundleSnap.id, ...(proofBundleSnap.data() as Record<string, unknown>) }] as const;
      } catch {
        return [proofBundleId, null] as const;
      }
    }),
  );
  const proofBundleDetails = Object.fromEntries(
    proofBundleEntries.filter((entry) => entry[1] != null),
  ) as Record<string, Record<string, unknown>>;

  const buildProofCheckpoints = (
    proofBundle: Record<string, unknown> | undefined,
  ): Array<Record<string, unknown>> => {
    const versionHistory = Array.isArray(proofBundle?.versionHistory) ? proofBundle.versionHistory : [];
    return versionHistory
      .filter((entry): entry is Record<string, unknown> => Boolean(entry) && typeof entry === 'object')
      .map((entry) => ({
        id: typeof entry.id === 'string' ? entry.id.trim() : '',
        summary: typeof entry.summary === 'string' ? entry.summary.trim() : '',
        artifactNote: typeof entry.artifactNote === 'string' && entry.artifactNote.trim() ? entry.artifactNote.trim() : null,
        actorId: typeof entry.actorId === 'string' && entry.actorId.trim() ? entry.actorId.trim() : null,
        actorRole: typeof entry.actorRole === 'string' && entry.actorRole.trim() ? entry.actorRole.trim() : null,
        createdAt: parseDateFromUnknown(entry.createdAt)?.toISOString() ?? null,
      }))
      .filter((entry) => Boolean(entry.id) || Boolean(entry.summary))
      .sort((left, right) => Date.parse(String(left.createdAt ?? '1970-01-01')) - Date.parse(String(right.createdAt ?? '1970-01-01')));
  };

  const evidenceDates = evidenceRows
    .map((row) => parseDateFromUnknown(row.observedAt ?? row.growthUpdatedAt ?? row.createdAt))
    .filter((value): value is Date => value instanceof Date)
    .sort((left, right) => right.getTime() - left.getTime());
  const reviewedEvidenceCount = evidenceRows.filter((row) => {
    const rubricStatus = typeof row.rubricStatus === 'string' ? row.rubricStatus.trim().toLowerCase() : '';
    const growthStatus = typeof row.growthStatus === 'string' ? row.growthStatus.trim().toLowerCase() : '';
    return rubricStatus === 'linked' || growthStatus === 'updated';
  }).length;
  const portfolioLinkedEvidenceCount = evidenceRows.filter((row) => {
    const linkedPortfolioItemId = typeof row.linkedPortfolioItemId === 'string' ? row.linkedPortfolioItemId.trim() : '';
    const portfolioStatus = typeof row.portfolioStatus === 'string' ? row.portfolioStatus.trim().toLowerCase() : '';
    return Boolean(linkedPortfolioItemId) || portfolioStatus === 'linked';
  }).length;
  const verificationPromptCount = evidenceRows.filter((row) => {
    return typeof row.nextVerificationPrompt === 'string' && row.nextVerificationPrompt.trim().length > 0;
  }).length;
  const evidenceSummary: Record<string, unknown> = {
    recordCount: evidenceRows.length,
    reviewedCount: reviewedEvidenceCount,
    portfolioLinkedCount: portfolioLinkedEvidenceCount,
    verificationPromptCount,
    latestEvidenceAt: evidenceDates[0]?.toISOString() ?? null,
  };

  const latestLevels = masteryRows
    .map((row) => (typeof row.latestLevel === 'number' && Number.isFinite(row.latestLevel) ? row.latestLevel : null))
    .filter((value): value is number => value != null && value > 0);
  const averageLevel = latestLevels.length
    ? latestLevels.reduce((sum, value) => sum + value, 0) / latestLevels.length
    : null;
  const growthDates = growthRows
    .map((row) => parseDateFromUnknown(row.createdAt))
    .filter((value): value is Date => value instanceof Date)
    .sort((left, right) => right.getTime() - left.getTime());
  const latestGrowthLevel = growthRows
    .map((row) => (typeof row.level === 'number' && Number.isFinite(row.level) ? row.level : null))
    .find((value): value is number => value != null && value > 0) ?? null;
  const growthSummary: Record<string, unknown> = {
    capabilityCount: masteryRows.length,
    updatedCapabilityCount: new Set(
      growthRows
        .map((row) => (typeof row.capabilityId === 'string' ? row.capabilityId.trim() : ''))
        .filter(Boolean),
    ).size,
    averageLevel,
    latestLevel: latestGrowthLevel,
    latestGrowthAt: growthDates[0]?.toISOString() ?? null,
  };

  const pillarBuckets: Record<'futureSkills' | 'leadership' | 'impact', number[]> = {
    futureSkills: [],
    leadership: [],
    impact: [],
  };
  masteryRows.forEach((row) => {
    const pillarKey = normalizeParentPillarKey(row.pillarCode);
    const latestLevel = typeof row.latestLevel === 'number' && Number.isFinite(row.latestLevel) ? row.latestLevel : 0;
    if (pillarKey && latestLevel > 0) {
      pillarBuckets[pillarKey].push(Math.max(0, Math.min(1, latestLevel / 4)));
    }
  });
  const averageBucket = (values: number[]): number | null => {
    if (!values.length) return null;
    return values.reduce((sum, value) => sum + value, 0) / values.length;
  };
  const futureSkills = averageBucket(pillarBuckets.futureSkills);
  const leadership = averageBucket(pillarBuckets.leadership);
  const impact = averageBucket(pillarBuckets.impact);
  const nonZeroCapabilityValues = [futureSkills, leadership, impact].filter((value): value is number => value != null && value > 0);
  const capabilityOverall = nonZeroCapabilityValues.length
    ? nonZeroCapabilityValues.reduce((sum, value) => sum + value, 0) / nonZeroCapabilityValues.length
    : null;
  const capabilityBand = capabilityOverall == null
    ? null
    : capabilityOverall >= 0.75
    ? 'strong'
    : capabilityOverall >= 0.45
    ? 'developing'
    : 'emerging';

  const portfolioDates = portfolioRows
    .map((row) => parseDateFromUnknown(row.updatedAt ?? row.createdAt))
    .filter((value): value is Date => value instanceof Date)
    .sort((left, right) => right.getTime() - left.getTime());
  const verifiedArtifactCount = portfolioRows.filter((row) => {
    const verificationStatus = typeof row.verificationStatus === 'string' ? row.verificationStatus.trim().toLowerCase() : '';
    return verificationStatus === 'reviewed' || verificationStatus === 'verified';
  }).length;
  const evidenceLinkedArtifactCount = portfolioRows.filter((row) => Array.isArray(row.evidenceRecordIds) && row.evidenceRecordIds.length > 0).length;
  const badgeCount = portfolioRows.filter((row) => {
    const title = typeof row.title === 'string' ? row.title.trim().toLowerCase() : '';
    const mediaType = typeof row.mediaType === 'string' ? row.mediaType.trim().toLowerCase() : '';
    return title.includes('badge') || mediaType === 'badge';
  }).length;
  const portfolioSnapshot: Record<string, unknown> = {
    artifactCount: portfolioRows.length,
    publishedArtifactCount: verifiedArtifactCount,
    badgeCount,
    projectCount: Math.max(0, portfolioRows.length - badgeCount),
    evidenceLinkedArtifactCount,
    verifiedArtifactCount,
    latestArtifactAt: portfolioDates[0]?.toISOString() ?? null,
  };
  const portfolioItemsPreview = portfolioRows
    .map((row) => {
      const missionAttemptId = typeof row.missionAttemptId === 'string' ? row.missionAttemptId.trim() : '';
      const matchingMissionAttempt = missionAttemptId
        ? missionAttemptRows.find((attempt) => typeof attempt.id === 'string' && attempt.id === missionAttemptId)
        : undefined;
      const sessionOccurrenceId = typeof matchingMissionAttempt?.sessionOccurrenceId === 'string'
        ? matchingMissionAttempt.sessionOccurrenceId.trim()
        : '';
      const matchingInteractionEvents = sessionOccurrenceId
        ? interactionEventRows.filter((entry) =>
            typeof entry.sessionOccurrenceId === 'string' && entry.sessionOccurrenceId.trim() === sessionOccurrenceId,
          )
        : [];
      const proofBundleSummary = matchingMissionAttempt?.proofBundleSummary as Record<string, unknown> | undefined;
      const proofBundleId = typeof row.proofBundleId === 'string' && row.proofBundleId.trim()
        ? row.proofBundleId.trim()
        : typeof matchingMissionAttempt?.proofBundleId === 'string' && matchingMissionAttempt.proofBundleId.trim()
        ? matchingMissionAttempt.proofBundleId.trim()
        : '';
      const proofBundle = proofBundleId ? proofBundleDetails[proofBundleId] : undefined;
      const proofCheckpoints = buildProofCheckpoints(proofBundle);
      const hasExplainItBack = proofBundleSummary?.hasExplainItBack === true;
      const hasOralCheck = proofBundleSummary?.hasOralCheck === true;
      const hasMiniRebuild = proofBundleSummary?.hasMiniRebuild === true;
      const proofCheckpointCount = typeof proofBundleSummary?.checkpointCount === 'number'
        ? proofBundleSummary.checkpointCount
        : proofCheckpoints.length;
      const hasLearnerAiDisclosure = proofBundleSummary?.hasLearnerAiDisclosure === true;
      const learnerAiDeclaredUsed = proofBundleSummary?.aiAssistanceUsed === true;
      const directProofOfLearningStatus = typeof row.proofOfLearningStatus === 'string'
        ? row.proofOfLearningStatus.trim()
        : '';
      const proofOfLearningStatus = directProofOfLearningStatus
        ? directProofOfLearningStatus
        : !matchingMissionAttempt
        ? 'not-available'
        : hasExplainItBack && hasOralCheck && hasMiniRebuild
        ? 'verified'
        : hasExplainItBack || hasOralCheck || hasMiniRebuild
        ? 'partial'
        : 'missing';
      const learnerAiEventCount = matchingInteractionEvents.filter((entry) => {
        const eventType = typeof entry.eventType === 'string' ? entry.eventType.trim().toLowerCase() : '';
        return eventType === 'ai_help_used' || eventType === 'ai_help_opened';
      }).length;
      const hasLearnerExplainBackEvent = matchingInteractionEvents.some((entry) => {
        const eventType = typeof entry.eventType === 'string' ? entry.eventType.trim().toLowerCase() : '';
        return eventType === 'explain_it_back_submitted';
      });
      const hasAiFeedbackSignal = (typeof row.aiFeedbackDraft === 'string'
        && row.aiFeedbackDraft.trim().length > 0)
        || (typeof row.aiFeedbackBy === 'string'
        && row.aiFeedbackBy.trim().length > 0)
        || parseDateFromUnknown(row.aiFeedbackAt) != null
        || (typeof matchingMissionAttempt?.aiFeedbackDraft === 'string'
        && matchingMissionAttempt.aiFeedbackDraft.trim().length > 0)
        || (typeof matchingMissionAttempt?.aiFeedbackBy === 'string'
        && matchingMissionAttempt.aiFeedbackBy.trim().length > 0)
        || parseDateFromUnknown(matchingMissionAttempt?.aiFeedbackAt) != null;
      const directAiDisclosureStatus = typeof row.aiDisclosureStatus === 'string'
        ? row.aiDisclosureStatus.trim()
        : '';
      const aiAssistanceDetails = typeof row.aiAssistanceDetails === 'string' && row.aiAssistanceDetails.trim()
        ? row.aiAssistanceDetails.trim()
        : typeof matchingMissionAttempt?.aiAssistanceDetails === 'string' && matchingMissionAttempt.aiAssistanceDetails.trim()
        ? matchingMissionAttempt.aiAssistanceDetails.trim()
        : typeof proofBundle?.aiAssistanceDetails === 'string' && proofBundle.aiAssistanceDetails.trim()
        ? proofBundle.aiAssistanceDetails.trim()
        : null;
      const growthEventIds = Array.isArray(row.growthEventIds)
        ? row.growthEventIds.filter((value): value is string => typeof value === 'string' && value.trim().length > 0).map((value) => value.trim())
        : [];
      const matchingGrowth = growthRows
        .filter((entry) => {
          const growthId = typeof entry.id === 'string' ? entry.id.trim() : '';
          const growthMissionAttemptId = typeof entry.missionAttemptId === 'string' ? entry.missionAttemptId.trim() : '';
          return (growthId && growthEventIds.includes(growthId)) || (missionAttemptId && growthMissionAttemptId === missionAttemptId);
        })
        .sort((left, right) => {
          const leftTime = parseDateFromUnknown(left.createdAt)?.getTime() ?? 0;
          const rightTime = parseDateFromUnknown(right.createdAt)?.getTime() ?? 0;
          return rightTime - leftTime;
        });
      const latestGrowth = matchingGrowth[0];
      const reviewerId = latestGrowth
        ? (typeof latestGrowth.educatorId === 'string' ? latestGrowth.educatorId.trim() : '')
        : typeof row.educatorId === 'string' && row.educatorId.trim()
        ? row.educatorId.trim()
        : typeof matchingMissionAttempt?.reviewedBy === 'string' && matchingMissionAttempt.reviewedBy.trim()
        ? matchingMissionAttempt.reviewedBy.trim()
        : '';
      const reviewerName = reviewerId ? reviewerNames[reviewerId] ?? null : null;
      const reviewedAt = latestGrowth
        ? parseDateFromUnknown(latestGrowth.createdAt)?.toISOString() ?? null
        : parseDateFromUnknown(row.updatedAt ?? row.reviewedAt ?? matchingMissionAttempt?.reviewedAt)?.toISOString() ?? null;
      const rubricRawScore = latestGrowth
        ? (typeof latestGrowth.rawScore === 'number' && Number.isFinite(latestGrowth.rawScore) ? latestGrowth.rawScore : null)
        : typeof row.rubricTotalScore === 'number' && Number.isFinite(row.rubricTotalScore)
        ? row.rubricTotalScore
        : typeof matchingMissionAttempt?.rubricTotalScore === 'number' && Number.isFinite(matchingMissionAttempt.rubricTotalScore)
        ? matchingMissionAttempt.rubricTotalScore
        : null;
      const rubricMaxScore = latestGrowth
        ? (typeof latestGrowth.maxScore === 'number' && Number.isFinite(latestGrowth.maxScore) ? latestGrowth.maxScore : null)
        : typeof row.rubricMaxScore === 'number' && Number.isFinite(row.rubricMaxScore)
        ? row.rubricMaxScore
        : typeof matchingMissionAttempt?.rubricMaxScore === 'number' && Number.isFinite(matchingMissionAttempt.rubricMaxScore)
        ? matchingMissionAttempt.rubricMaxScore
        : null;
      const rubricLevel = latestGrowth && typeof latestGrowth.level === 'number' && Number.isFinite(latestGrowth.level)
        ? latestGrowth.level
        : null;
      const aiFeedbackEducatorId = typeof row.aiFeedbackBy === 'string' && row.aiFeedbackBy.trim()
        ? row.aiFeedbackBy.trim()
        : typeof matchingMissionAttempt?.aiFeedbackBy === 'string' && matchingMissionAttempt.aiFeedbackBy.trim()
        ? matchingMissionAttempt.aiFeedbackBy.trim()
        : '';
      const aiFeedbackEducatorName = aiFeedbackEducatorId
        ? reviewerNames[aiFeedbackEducatorId] ?? reviewerName
        : hasAiFeedbackSignal
        ? reviewerName
        : null;
      const aiFeedbackAt = parseDateFromUnknown(row.aiFeedbackAt ?? matchingMissionAttempt?.aiFeedbackAt)?.toISOString()
        ?? (hasAiFeedbackSignal ? reviewedAt : null);
      const aiDisclosureStatus = directAiDisclosureStatus
        ? directAiDisclosureStatus
        : hasLearnerAiDisclosure
        ? learnerAiDeclaredUsed
          ? hasExplainItBack
            ? 'learner-ai-verified'
            : 'learner-ai-verification-gap'
          : 'learner-ai-not-used'
        : learnerAiEventCount > 0
        ? hasLearnerExplainBackEvent
          ? 'learner-ai-verified'
          : 'learner-ai-verification-gap'
        : hasAiFeedbackSignal
        ? 'educator-feedback-ai'
        : matchingMissionAttempt
        ? 'no-learner-ai-signal'
        : 'not-available';
      const progressionDescriptors = stringListFromUnknown(row.progressionDescriptors).length > 0
        ? stringListFromUnknown(row.progressionDescriptors)
        : latestGrowth
        ? stringListFromUnknown(latestGrowth.progressionDescriptors)
        : [];
      const checkpointMappings = checkpointMappingsFromUnknown(row.checkpointMappings).length > 0
        ? checkpointMappingsFromUnknown(row.checkpointMappings)
        : latestGrowth
        ? checkpointMappingsFromUnknown(latestGrowth.checkpointMappings)
        : [];
      return {
        id: typeof row.id === 'string' ? row.id : randomUUID(),
        title: typeof row.title === 'string' && row.title.trim() ? row.title.trim() : 'Portfolio artifact',
        description:
          typeof row.description === 'string' && row.description.trim()
            ? row.description.trim()
            : 'Evidence-backed portfolio artifact.',
        pillar: parentPillarLabelFromCodes(row.pillarCodes),
        type:
          (typeof row.title === 'string' && row.title.toLowerCase().includes('badge')) ||
          (typeof row.mediaType === 'string' && row.mediaType.trim().toLowerCase() === 'badge')
            ? 'badge'
            : 'project',
        completedAt: parseDateFromUnknown(row.updatedAt ?? row.createdAt)?.toISOString() ?? now.toISOString(),
        verificationStatus: typeof row.verificationStatus === 'string' ? row.verificationStatus.trim() : null,
        evidenceLinked: Array.isArray(row.evidenceRecordIds) && row.evidenceRecordIds.length > 0,
        capabilityTitles: Array.isArray(row.capabilityIds)
          ? row.capabilityIds.filter((v): v is string => typeof v === 'string').map((id) => capabilityTitlesById.get(id.trim()) ?? id.trim()).filter(Boolean)
          : [],
        evidenceRecordIds: Array.isArray(row.evidenceRecordIds) ? row.evidenceRecordIds.filter((value) => typeof value === 'string') : [],
        missionAttemptId: missionAttemptId || null,
        verificationPrompt: typeof row.verificationPrompt === 'string' && row.verificationPrompt.trim() ? row.verificationPrompt.trim() : null,
        progressionDescriptors,
        checkpointMappings,
        proofOfLearningStatus,
        aiDisclosureStatus,
        proofHasExplainItBack: hasExplainItBack,
        proofHasOralCheck: hasOralCheck,
        proofHasMiniRebuild: hasMiniRebuild,
        proofCheckpointCount,
        proofExplainItBackExcerpt:
          typeof proofBundle?.explainItBack === 'string' && proofBundle.explainItBack.trim()
            ? proofBundle.explainItBack.trim()
            : null,
        proofOralCheckExcerpt:
          typeof proofBundle?.oralCheckResponse === 'string' && proofBundle.oralCheckResponse.trim()
            ? proofBundle.oralCheckResponse.trim()
            : null,
        proofMiniRebuildExcerpt:
          typeof proofBundle?.miniRebuildPlan === 'string' && proofBundle.miniRebuildPlan.trim()
            ? proofBundle.miniRebuildPlan.trim()
            : null,
        proofCheckpoints,
        aiHasLearnerDisclosure: hasLearnerAiDisclosure,
        aiLearnerDeclaredUsed: learnerAiDeclaredUsed,
        aiHelpEventCount: learnerAiEventCount,
        aiHasExplainItBackEvidence: hasExplainItBack || hasLearnerExplainBackEvent,
        aiHasEducatorAiFeedback: hasAiFeedbackSignal,
        aiAssistanceDetails,
        reviewingEducatorName: reviewerName,
        reviewedAt,
        rubricRawScore,
        rubricMaxScore,
        rubricLevel,
        aiFeedbackEducatorName,
        aiFeedbackAt,
      };
    })
    .sort((left, right) => Date.parse(String(right.completedAt)) - Date.parse(String(left.completedAt)));

  const reflectionDates = reflectionRows
    .map((row) => parseDateFromUnknown(row.createdAt))
    .filter((value): value is Date => value instanceof Date)
    .sort((left, right) => right.getTime() - left.getTime());
  const passportClaims = masteryRows
    .map((row) => {
      const capabilityId = typeof row.capabilityId === 'string' ? row.capabilityId.trim() : '';
      if (!capabilityId) return null;
      const matchingEvidence: Array<Record<string, unknown>> = evidenceRows.filter((entry) =>
        typeof entry.capabilityId === 'string' && entry.capabilityId.trim() === capabilityId,
      );
      const matchingPortfolio: Array<Record<string, unknown>> = portfolioRows.filter((entry) =>
        Array.isArray(entry.capabilityIds) && entry.capabilityIds.includes(capabilityId),
      );
      const matchingGrowth: Array<Record<string, unknown>> = growthRows.filter((entry) =>
        typeof entry.capabilityId === 'string' && entry.capabilityId.trim() === capabilityId,
      );
      const missionAttemptIds = new Set<string>([
        typeof row.latestMissionAttemptId === 'string' ? row.latestMissionAttemptId.trim() : '',
        ...matchingEvidence.map((entry) => (typeof entry.linkedMissionAttemptId === 'string' ? entry.linkedMissionAttemptId.trim() : '')),
        ...matchingGrowth.map((entry) => (typeof entry.missionAttemptId === 'string' ? entry.missionAttemptId.trim() : '')),
        ...matchingPortfolio.map((entry) => (typeof entry.missionAttemptId === 'string' ? entry.missionAttemptId.trim() : '')),
      ]);
      missionAttemptIds.delete('');
      const matchingMissionAttempts: Array<Record<string, unknown>> = missionAttemptRows.filter((entry) =>
        typeof entry.id === 'string' && missionAttemptIds.has(entry.id),
      );
      const sessionOccurrenceIds = new Set<string>(
        matchingMissionAttempts
          .map((entry) => (typeof entry.sessionOccurrenceId === 'string' ? entry.sessionOccurrenceId.trim() : ''))
          .filter(Boolean),
      );
      const matchingInteractionEvents: Array<Record<string, unknown>> = interactionEventRows.filter((entry) =>
        typeof entry.sessionOccurrenceId === 'string' && sessionOccurrenceIds.has(entry.sessionOccurrenceId.trim()),
      );
      const capabilityId = typeof row.capabilityId === 'string' ? row.capabilityId.trim() : '';
      const title = capabilityTitlesById.get(capabilityId) ?? capabilityId || 'Capability title unavailable';
      const latestLevel = typeof row.latestLevel === 'number' && Number.isFinite(row.latestLevel)
        ? Math.round(row.latestLevel)
        : null;
      const verifiedArtifactCount = matchingPortfolio.filter((entry) => {
        const verificationStatus = typeof entry.verificationStatus === 'string'
          ? entry.verificationStatus.trim().toLowerCase()
          : '';
        return verificationStatus === 'reviewed' || verificationStatus === 'verified';
      }).length;
      const latestEvidenceAt = [
        ...matchingEvidence.map((entry) => parseDateFromUnknown(entry.observedAt)),
        ...matchingGrowth.map((entry) => parseDateFromUnknown(entry.createdAt)),
      ]
        .filter((value): value is Date => value instanceof Date)
        .sort((left, right) => right.getTime() - left.getTime())[0] ?? null;
      const hasExplainItBack = matchingMissionAttempts.some((entry) => {
        const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
        return summary?.hasExplainItBack === true;
      });
      const hasOralCheck = matchingMissionAttempts.some((entry) => {
        const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
        return summary?.hasOralCheck === true;
      });
      const hasMiniRebuild = matchingMissionAttempts.some((entry) => {
        const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
        return summary?.hasMiniRebuild === true;
      });
      const hasLearnerAiDisclosure = matchingMissionAttempts.some((entry) => {
        const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
        return summary?.hasLearnerAiDisclosure === true;
      });
      const learnerAiDeclaredUsed = matchingMissionAttempts.some((entry) => {
        const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
        return summary?.aiAssistanceUsed === true;
      });
      const proofOfLearningStatus = hasExplainItBack && hasOralCheck && hasMiniRebuild
        ? 'verified'
        : hasExplainItBack || hasOralCheck || hasMiniRebuild
        ? 'partial'
        : 'missing';
      const hasAiFeedbackSignal = matchingMissionAttempts.some((entry) =>
        (typeof entry.aiFeedbackDraft === 'string' && entry.aiFeedbackDraft.trim().length > 0)
        || (typeof entry.aiFeedbackBy === 'string' && entry.aiFeedbackBy.trim().length > 0)
        || parseDateFromUnknown(entry.aiFeedbackAt) != null,
      ) || matchingPortfolio.some((entry) =>
        (typeof entry.aiFeedbackDraft === 'string' && entry.aiFeedbackDraft.trim().length > 0)
        || (typeof entry.aiFeedbackBy === 'string' && entry.aiFeedbackBy.trim().length > 0)
        || parseDateFromUnknown(entry.aiFeedbackAt) != null,
      );
      const learnerAiEventCount = matchingInteractionEvents.filter((entry) => {
        const eventType = typeof entry.eventType === 'string' ? entry.eventType.trim().toLowerCase() : '';
        return eventType === 'ai_help_used' || eventType === 'ai_help_opened';
      }).length;
      const hasLearnerExplainBackEvent = matchingInteractionEvents.some((entry) => {
        const eventType = typeof entry.eventType === 'string' ? entry.eventType.trim().toLowerCase() : '';
        return eventType === 'explain_it_back_submitted';
      });
      const aiDisclosureStatus = hasLearnerAiDisclosure
        ? learnerAiDeclaredUsed
          ? hasExplainItBack
            ? 'learner-ai-verified'
            : 'learner-ai-verification-gap'
          : 'learner-ai-not-used'
        : learnerAiEventCount > 0
        ? hasLearnerExplainBackEvent
          ? 'learner-ai-verified'
          : 'learner-ai-verification-gap'
        : hasAiFeedbackSignal
        ? 'educator-feedback-ai'
        : matchingMissionAttempts.length > 0
        ? 'no-learner-ai-signal'
        : 'not-available';
      const matchingGrowthByRecency = [...matchingGrowth].sort((left, right) => {
        const leftTime = parseDateFromUnknown(left.createdAt)?.getTime() ?? 0;
        const rightTime = parseDateFromUnknown(right.createdAt)?.getTime() ?? 0;
        return rightTime - leftTime;
      });
      const latestGrowth = matchingGrowthByRecency[0];
      const latestMissionAttempt = matchingMissionAttempts[0];
      const latestPortfolio = [...matchingPortfolio].sort((left, right) => {
        const leftTime = parseDateFromUnknown(left.updatedAt ?? left.createdAt)?.getTime() ?? 0;
        const rightTime = parseDateFromUnknown(right.updatedAt ?? right.createdAt)?.getTime() ?? 0;
        return rightTime - leftTime;
      })[0];
      const proofBundleId = typeof latestPortfolio?.proofBundleId === 'string' && latestPortfolio.proofBundleId.trim()
        ? latestPortfolio.proofBundleId.trim()
        : typeof latestMissionAttempt?.proofBundleId === 'string' && latestMissionAttempt.proofBundleId.trim()
        ? latestMissionAttempt.proofBundleId.trim()
        : '';
      const proofBundle = proofBundleId ? proofBundleDetails[proofBundleId] : undefined;
      const proofCheckpoints = buildProofCheckpoints(proofBundle);
      const proofCheckpointCount = matchingMissionAttempts
        .map((entry) => {
          const summary = entry.proofBundleSummary as Record<string, unknown> | undefined;
          return typeof summary?.checkpointCount === 'number' ? summary.checkpointCount : 0;
        })
        .reduce((max, value) => Math.max(max, value), 0);
      const reviewerId = latestGrowth
        ? (typeof latestGrowth.educatorId === 'string' ? latestGrowth.educatorId.trim() : '')
        : typeof latestPortfolio?.educatorId === 'string' && latestPortfolio.educatorId.trim()
        ? latestPortfolio.educatorId.trim()
        : typeof latestMissionAttempt?.reviewedBy === 'string' && latestMissionAttempt.reviewedBy.trim()
        ? latestMissionAttempt.reviewedBy.trim()
        : '';
      const reviewerName = reviewerId ? reviewerNames[reviewerId] ?? null : null;
      const reviewedAt = latestGrowth
        ? parseDateFromUnknown(latestGrowth.createdAt)?.toISOString() ?? null
        : parseDateFromUnknown(latestPortfolio?.updatedAt ?? latestPortfolio?.reviewedAt ?? latestMissionAttempt?.reviewedAt)?.toISOString() ?? null;
      const rubricRawScore = latestGrowth
        ? (typeof latestGrowth.rawScore === 'number' && Number.isFinite(latestGrowth.rawScore) ? latestGrowth.rawScore : null)
        : typeof latestPortfolio?.rubricTotalScore === 'number' && Number.isFinite(latestPortfolio.rubricTotalScore)
        ? latestPortfolio.rubricTotalScore
        : typeof latestMissionAttempt?.rubricTotalScore === 'number' && Number.isFinite(latestMissionAttempt.rubricTotalScore)
        ? latestMissionAttempt.rubricTotalScore
        : null;
      const rubricMaxScore = latestGrowth
        ? (typeof latestGrowth.maxScore === 'number' && Number.isFinite(latestGrowth.maxScore) ? latestGrowth.maxScore : null)
        : typeof latestPortfolio?.rubricMaxScore === 'number' && Number.isFinite(latestPortfolio.rubricMaxScore)
        ? latestPortfolio.rubricMaxScore
        : typeof latestMissionAttempt?.rubricMaxScore === 'number' && Number.isFinite(latestMissionAttempt.rubricMaxScore)
        ? latestMissionAttempt.rubricMaxScore
        : null;
      const aiFeedbackEducatorId = typeof latestPortfolio?.aiFeedbackBy === 'string' && latestPortfolio.aiFeedbackBy.trim()
        ? latestPortfolio.aiFeedbackBy.trim()
        : typeof latestMissionAttempt?.aiFeedbackBy === 'string' && latestMissionAttempt.aiFeedbackBy.trim()
        ? latestMissionAttempt.aiFeedbackBy.trim()
        : '';
      const aiFeedbackEducatorName = aiFeedbackEducatorId
        ? reviewerNames[aiFeedbackEducatorId] ?? reviewerName
        : hasAiFeedbackSignal
        ? reviewerName
        : null;
      const aiFeedbackAt = parseDateFromUnknown(latestPortfolio?.aiFeedbackAt ?? latestMissionAttempt?.aiFeedbackAt)?.toISOString()
        ?? (hasAiFeedbackSignal ? reviewedAt : null);
      const aiAssistanceDetails = typeof latestPortfolio?.aiAssistanceDetails === 'string' && latestPortfolio.aiAssistanceDetails.trim()
        ? latestPortfolio.aiAssistanceDetails.trim()
        : typeof latestMissionAttempt?.aiAssistanceDetails === 'string' && latestMissionAttempt.aiAssistanceDetails.trim()
        ? latestMissionAttempt.aiAssistanceDetails.trim()
        : typeof proofBundle?.aiAssistanceDetails === 'string' && proofBundle.aiAssistanceDetails.trim()
        ? proofBundle.aiAssistanceDetails.trim()
        : null;
      const progressionDescriptors = stringListFromUnknown(latestPortfolio?.progressionDescriptors).length > 0
        ? stringListFromUnknown(latestPortfolio?.progressionDescriptors)
        : stringListFromUnknown(latestGrowth?.progressionDescriptors);
      const checkpointMappings = checkpointMappingsFromUnknown(latestPortfolio?.checkpointMappings).length > 0
        ? checkpointMappingsFromUnknown(latestPortfolio?.checkpointMappings)
        : checkpointMappingsFromUnknown(latestGrowth?.checkpointMappings);
      return {
        capabilityId,
        title: String(title),
        pillar: parentPillarLabelFromCodes([row.pillarCode]),
        latestLevel,
        evidenceCount: matchingEvidence.length,
        verifiedArtifactCount,
        evidenceRecordIds: matchingEvidence
          .map((entry) => (typeof entry.id === 'string' ? entry.id : ''))
          .filter(Boolean),
        portfolioItemIds: matchingPortfolio
          .map((entry) => (typeof entry.id === 'string' ? entry.id : ''))
          .filter(Boolean),
        missionAttemptIds: Array.from(missionAttemptIds),
        progressionDescriptors,
        checkpointMappings,
        proofOfLearningStatus,
        aiDisclosureStatus,
        latestEvidenceAt: latestEvidenceAt?.toISOString() ?? null,
        verificationStatus: verifiedArtifactCount > 0 ? 'reviewed' : matchingEvidence.length > 0 ? 'captured' : null,
        proofHasExplainItBack: hasExplainItBack,
        proofHasOralCheck: hasOralCheck,
        proofHasMiniRebuild: hasMiniRebuild,
        proofCheckpointCount,
        proofExplainItBackExcerpt:
          typeof proofBundle?.explainItBack === 'string' && proofBundle.explainItBack.trim()
            ? proofBundle.explainItBack.trim()
            : null,
        proofOralCheckExcerpt:
          typeof proofBundle?.oralCheckResponse === 'string' && proofBundle.oralCheckResponse.trim()
            ? proofBundle.oralCheckResponse.trim()
            : null,
        proofMiniRebuildExcerpt:
          typeof proofBundle?.miniRebuildPlan === 'string' && proofBundle.miniRebuildPlan.trim()
            ? proofBundle.miniRebuildPlan.trim()
            : null,
        proofCheckpoints,
        aiHasLearnerDisclosure: hasLearnerAiDisclosure,
        aiLearnerDeclaredUsed: learnerAiDeclaredUsed,
        aiHelpEventCount: learnerAiEventCount,
        aiHasExplainItBackEvidence: hasExplainItBack || hasLearnerExplainBackEvent,
        aiHasEducatorAiFeedback: hasAiFeedbackSignal,
        aiAssistanceDetails,
        reviewingEducatorName: reviewerName,
        reviewedAt,
        rubricRawScore,
        rubricMaxScore,
        aiFeedbackEducatorName,
        aiFeedbackAt,
      };
    })
    .filter((value): value is NonNullable<typeof value> => value !== null)
    .sort((left, right) => {
      const levelDiff = Number(right.latestLevel ?? 0) - Number(left.latestLevel ?? 0);
      if (levelDiff !== 0) return levelDiff;
      return Number(right.evidenceCount ?? 0) - Number(left.evidenceCount ?? 0);
    });
  const ideationPassport: Record<string, unknown> = {
    missionAttempts: missionAttemptRows.length,
    completedMissions: missionAttemptRows.filter((row) => {
      const status = typeof row.status === 'string' ? row.status.trim().toLowerCase() : '';
      return status === 'completed' || status === 'reviewed' || status === 'approved';
    }).length,
    reflectionsSubmitted: reflectionRows.length,
    voiceInteractions: missionAttemptRows.filter((row) => {
      const summary = row.proofBundleSummary as Record<string, unknown> | undefined;
      return summary?.hasOralCheck === true;
    }).length,
    collaborationSignals: reflectionRows.filter((row) => {
      const reflectionType = typeof row.reflectionType === 'string' ? row.reflectionType.trim().toLowerCase() : '';
      return reflectionType === 'shout_out' || reflectionType === 'weekly_review';
    }).length,
    lastReflectionAt: reflectionDates[0]?.toISOString() ?? null,
    generatedAt: now.toISOString(),
    summary: passportClaims.length
      ? `${passportClaims.length} capability claims are backed by reviewed evidence and reviewed or verified artifacts.`
      : 'No capability claims backed by reviewed evidence are available yet.',
    claims: passportClaims,
  };

  const growthTimeline = growthRows
    .map((row) => {
      const capabilityId = typeof row.capabilityId === 'string' ? row.capabilityId.trim() : '';
      if (!capabilityId) {
        return null;
      }
      const reviewerId = typeof row.educatorId === 'string' ? row.educatorId.trim() : '';
      return {
        capabilityId,
        title: capabilityTitlesById.get(capabilityId) ?? capabilityId,
        pillar: parentPillarLabelFromCodes([row.pillarCode]),
        level: typeof row.level === 'number' && Number.isFinite(row.level) ? row.level : 0,
        linkedEvidenceRecordIds: Array.isArray(row.linkedEvidenceRecordIds)
          ? row.linkedEvidenceRecordIds.filter((value): value is string => typeof value === 'string')
          : [],
        linkedPortfolioItemIds: Array.isArray(row.linkedPortfolioItemIds)
          ? row.linkedPortfolioItemIds.filter((value): value is string => typeof value === 'string')
          : [],
        proofOfLearningStatus:
          typeof row.proofOfLearningStatus === 'string' && row.proofOfLearningStatus.trim()
            ? row.proofOfLearningStatus.trim()
            : null,
        occurredAt: parseDateFromUnknown(row.createdAt)?.toISOString() ?? null,
        reviewingEducatorName: reviewerId ? reviewerNames[reviewerId] ?? null : null,
        rubricRawScore: typeof row.rawScore === 'number' && Number.isFinite(row.rawScore) ? row.rawScore : null,
        rubricMaxScore: typeof row.maxScore === 'number' && Number.isFinite(row.maxScore) ? row.maxScore : null,
        missionAttemptId: typeof row.missionAttemptId === 'string' && row.missionAttemptId.trim() ? row.missionAttemptId.trim() : null,
      };
    })
    .filter((value): value is NonNullable<typeof value> => value !== null)
    .sort((left, right) => Date.parse(String(right.occurredAt ?? now.toISOString())) - Date.parse(String(left.occurredAt ?? now.toISOString())));

  const currentLevel = resolveParentCurrentLevel(averageLevel);
  const totalXp =
    typeof progressData.totalXp === 'number' && Number.isFinite(progressData.totalXp)
      ? Math.round(progressData.totalXp)
      : null;
  const missionsCompleted =
    typeof ideationPassport.completedMissions === 'number'
      ? ideationPassport.completedMissions
      : typeof progressData.missionsCompleted === 'number' && Number.isFinite(progressData.missionsCompleted)
      ? Math.round(progressData.missionsCompleted)
      : null;
  const currentStreak =
    typeof progressData.currentStreak === 'number' && Number.isFinite(progressData.currentStreak)
      ? Math.round(progressData.currentStreak)
      : null;

  return {
    learnerId,
    learnerName:
      typeof learnerData.displayName === 'string' && learnerData.displayName.trim().length > 0
        ? learnerData.displayName.trim()
        : typeof learnerData.email === 'string' && learnerData.email.trim().length > 0
        ? learnerData.email.trim()
        : null,
    photoUrl: null,
    currentLevel,
    totalXp,
    missionsCompleted,
    currentStreak,
    attendanceRate,
    pillarProgress: {
      futureSkills,
      leadership,
      impact,
    },
    capabilitySnapshot: {
      futureSkills,
      leadership,
      impact,
      overall: capabilityOverall,
      band: capabilityBand,
    },
    evidenceSummary,
    growthSummary,
    growthTimeline,
    portfolioSnapshot,
    portfolioItemsPreview,
    ideationPassport,
    recentActivities,
    upcomingEvents,
  };
}

async function loadParentUpcomingEvents(params: {
  learnerId: string;
  siteId?: string;
  now: Date;
}): Promise<Array<Record<string, unknown>>> {
  const { learnerId, siteId, now } = params;
  try {
    const enrollmentsSnap = await admin
      .firestore()
      .collection('enrollments')
      .where('learnerId', '==', learnerId)
      .where('status', '==', 'active')
      .get();
    const sessionIds = Array.from(
      new Set(
        enrollmentsSnap.docs
          .map((doc) => (typeof doc.data().sessionId === 'string' ? doc.data().sessionId.trim() : ''))
          .filter((sessionId) => sessionId.length > 0),
      ),
    );

    const occurrenceEvents: Array<Record<string, unknown> & { timestamp: number }> = [];
    for (const sessionId of sessionIds) {
      const occurrencesSnap = await admin
        .firestore()
        .collection('sessionOccurrences')
        .where('sessionId', '==', sessionId)
        .limit(20)
        .get();
      for (const doc of occurrencesSnap.docs) {
        const data = doc.data() as Record<string, unknown>;
        const start = parseDateFromUnknown(data.startTime ?? data.date);
        if (!start || start < now) continue;
        if (siteId && typeof data.siteId === 'string' && data.siteId.trim().length > 0) {
          if (data.siteId.trim() !== siteId) continue;
        }
        occurrenceEvents.push({
          id: doc.id,
          title:
            typeof data.title === 'string' && data.title.trim().length > 0
              ? data.title
              : typeof data.sessionTitle === 'string' && data.sessionTitle.trim().length > 0
              ? data.sessionTitle
              : 'Session',
          description: typeof data.description === 'string' ? data.description : null,
          dateTime: start.toISOString(),
          type: 'session',
          location:
            typeof data.roomName === 'string' && data.roomName.trim().length > 0
              ? data.roomName
              : typeof data.location === 'string'
              ? data.location
              : null,
          timestamp: start.getTime(),
        });
      }
    }

    if (occurrenceEvents.length > 0) {
      return occurrenceEvents
        .sort((left, right) => left.timestamp - right.timestamp)
        .slice(0, 5)
        .map(({ timestamp, ...event }) => event);
    }
  } catch {
    // Fall through to legacy events lookup.
  }

  try {
    const eventsSnap = await admin
      .firestore()
      .collection('events')
      .where('learnerId', '==', learnerId)
      .where('dateTime', '>=', Timestamp.fromDate(now))
      .orderBy('dateTime')
      .limit(5)
      .get();
    return eventsSnap.docs.map((doc) => {
      const data = doc.data() as Record<string, unknown>;
      return {
        id: doc.id,
        title: typeof data.title === 'string' ? data.title : 'Session',
        description: typeof data.description === 'string' ? data.description : null,
        dateTime: parseDateFromUnknown(data.dateTime)?.toISOString() ?? now.toISOString(),
        type: typeof data.type === 'string' ? data.type : 'event',
        location: typeof data.location === 'string' ? data.location : null,
      };
    });
  } catch {
    return [];
  }
}

export const getParentDashboardBundle = onCall(async (request: CallableRequest<{
  siteId?: string;
  locale?: string;
  range?: string;
  parentId?: string;
}>) => {
  const authUid = request.auth?.uid;
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const actorProfile = await getUserProfile(authUid);
  const actorRole = normalizeRoleValue(actorProfile?.role);
  if (!actorProfile || !actorRole || !['parent', 'site', 'hq'].includes(actorRole)) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }

  const requestedSiteId =
    typeof request.data?.siteId === 'string' && request.data.siteId.trim().length > 0
      ? request.data.siteId.trim()
      : undefined;
  const siteId = resolveRoleSiteId(actorProfile, actorRole, requestedSiteId);

  const parentIdInput =
    typeof request.data?.parentId === 'string' && request.data.parentId.trim().length > 0
      ? request.data.parentId.trim()
      : undefined;
  const parentId = actorRole === 'parent' ? authUid : parentIdInput;
  if (!parentId) {
    throw new HttpsError('invalid-argument', 'parentId is required for non-parent actors.');
  }

  const learnerIds = await collectParentLinkedLearnerIds({ parentId, siteId });
  const learnerSummaries = (
    await Promise.all(
      learnerIds.map((learnerId) => buildParentLearnerSummary({ learnerId, siteId })),
    )
  ).filter((summary): summary is Record<string, unknown> => summary !== null);

  return {
    parentId,
    siteId: siteId ?? null,
    locale: normalizeTelemetryLocale(request.data?.locale),
    range:
      typeof request.data?.range === 'string' && request.data.range.trim().length > 0
        ? request.data.range.trim()
        : 'week',
    linkedLearnerCount: learnerSummaries.length,
    learners: learnerSummaries,
  };
});

async function computeRoleDashboardStats(params: {
  role: Role;
  uid: string;
  siteId?: string;
  profile: UserRecord;
}): Promise<Array<Record<string, unknown>>> {
  const { role, uid, siteId, profile } = params;
  const db = admin.firestore();
  const now = new Date();
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

  if (role === 'learner') {
    let activeSessions = 0;
    let activeMissions = 0;
    let unreadMessages = 0;

    try {
      const enrollments = await db
        .collection('enrollments')
        .where('learnerId', '==', uid)
        .where('status', '==', 'active')
        .get();
      activeSessions = enrollments.size;
    } catch {
      activeSessions = 0;
    }

    try {
      const assignments = await db
        .collection('missionAssignments')
        .where('learnerId', '==', uid)
        .get();
      activeMissions = assignments.docs.filter((doc) => doc.data().status !== 'completed').length;
    } catch {
      activeMissions = 0;
    }

    try {
      const messages = await db
        .collection('messages')
        .where('recipientId', '==', uid)
        .where('isRead', '==', false)
        .get();
      unreadMessages = messages.size;
    } catch {
      unreadMessages = 0;
    }

    return [
      { label: 'Active Sessions', value: String(activeSessions), icon: 'event', color: 'info' },
      { label: 'Active Missions', value: String(activeMissions), icon: 'rocket', color: 'primary' },
      { label: 'Unread Messages', value: String(unreadMessages), icon: 'mail', color: 'warning' },
    ];
  }

  if (role === 'educator') {
    let studentsToday = 0;
    let attendanceRate: number | null = null;
    let toReview = 0;

    try {
      const occurrences = await db
        .collection('sessionOccurrences')
        .where('educatorId', '==', uid)
        .get();
      let present = 0;
      let total = 0;
      for (const doc of occurrences.docs) {
        const data = doc.data();
        const start = parseDateFromUnknown(data.startTime ?? data.date);
        if (!start || start < startOfDay || start >= endOfDay) continue;
        const enrolledCount = typeof data.enrolledCount === 'number' ? data.enrolledCount : 0;
        const presentCount = typeof data.presentCount === 'number' ? data.presentCount : 0;
        studentsToday += enrolledCount;
        total += enrolledCount;
        present += presentCount;
      }
      attendanceRate = total > 0 ? (present / total) * 100 : null;
    } catch {
      studentsToday = 0;
      attendanceRate = null;
    }

    try {
      const attempts = await db
        .collection('missionAttempts')
        .where('educatorId', '==', uid)
        .get();
      toReview = attempts.docs.filter((doc) => {
        const status = typeof doc.data().status === 'string' ? doc.data().status : '';
        return status === 'submitted' || status === 'pending_review';
      }).length;
    } catch {
      toReview = 0;
    }

    return [
      { label: 'Students Today', value: String(studentsToday), icon: 'people', color: 'info' },
      {
        label: 'Attendance',
        value: attendanceRate != null ? `${Math.round(attendanceRate)}%` : 'Evidence unavailable',
        icon: 'check_circle',
        color: 'success',
      },
      { label: 'To Review', value: String(toReview), icon: 'rate_review', color: 'warning' },
    ];
  }

  if (role === 'parent') {
    const learnerIds = await collectParentLinkedLearnerIds({
      parentId: uid,
      siteId,
    });
    let upcomingSessions = 0;
    try {
      if (learnerIds.length > 0) {
        let query: FirebaseFirestore.Query = db.collection('events');
        query = query.where('dateTime', '>=', Timestamp.fromDate(now));
        const events = await query.get();
        upcomingSessions = events.docs.filter((doc) => learnerIds.includes(String(doc.data().learnerId || ''))).length;
      }
    } catch {
      upcomingSessions = 0;
    }

    return [
      { label: 'Linked Learners', value: String(learnerIds.length), icon: 'people', color: 'primary' },
      { label: 'Upcoming Sessions', value: String(upcomingSessions), icon: 'event', color: 'info' },
      { label: 'Alerts', value: 'Evidence unavailable', icon: 'warning', color: 'warning' },
    ];
  }

  if (role === 'site') {
    if (!siteId) {
      throw new HttpsError('invalid-argument', 'siteId is required for site dashboard snapshot.');
    }

    let onSite = 0;
    let checkedIn = 0;
    let openIncidents = 0;

    try {
      const users = await db
        .collection(USERS_COLLECTION)
        .where('siteIds', 'array-contains', siteId)
        .get();
      onSite = users.docs.filter((doc) => normalizeRoleValue(doc.data().role) === 'learner').length;
    } catch {
      onSite = 0;
    }

    try {
      const records = await db
        .collection('checkins')
        .where('siteId', '==', siteId)
        .where('type', '==', 'checkin')
        .where('timestamp', '>=', Timestamp.fromDate(startOfDay))
        .where('timestamp', '<', Timestamp.fromDate(endOfDay))
        .get();
      checkedIn = records.size;
    } catch {
      checkedIn = 0;
    }

    try {
      const incidents = await db
        .collection('incidents')
        .where('siteId', '==', siteId)
        .where('status', '==', 'open')
        .get();
      openIncidents = incidents.size;
    } catch {
      openIncidents = 0;
    }

    return [
      { label: 'On Site', value: String(onSite), icon: 'location_on', color: 'info' },
      { label: 'Checked In', value: String(checkedIn), icon: 'login', color: 'success' },
      { label: 'Open Incidents', value: String(openIncidents), icon: 'warning', color: 'error' },
    ];
  }

  if (role === 'partner') {
    const partnerSiteIds = profile.siteIds ?? [];
    let learnersSupported = 0;
    try {
      const users = await db
        .collection(USERS_COLLECTION)
        .where('siteIds', 'array-contains-any', partnerSiteIds.slice(0, 10))
        .get();
      learnersSupported = users.docs.filter((doc) => normalizeRoleValue(doc.data().role) === 'learner').length;
    } catch {
      learnersSupported = 0;
    }

    return [
      { label: 'Associated Sites', value: String(partnerSiteIds.length), icon: 'business', color: 'primary' },
      { label: 'Learners Supported', value: formatCompactCount(learnersSupported), icon: 'people', color: 'info' },
      { label: 'Active Programs', value: String(partnerSiteIds.length), icon: 'event', color: 'success' },
    ];
  }

  let activeSites = 0;
  let totalUsers = 0;
  let pending = 0;
  try {
    const sites = await db.collection('sites').get();
    activeSites = sites.docs.filter((doc) => String(doc.data().status || 'active') !== 'inactive').length;
  } catch {
    activeSites = 0;
  }
  try {
    totalUsers = (await db.collection(USERS_COLLECTION).get()).size;
  } catch {
    totalUsers = 0;
  }
  try {
    pending = (await db.collection('approvals').where('status', '==', 'pending').get()).size;
  } catch {
    pending = 0;
  }

  return [
    { label: 'Active Sites', value: String(activeSites), icon: 'business', color: 'primary' },
    { label: 'Total Users', value: formatCompactCount(totalUsers), icon: 'people', color: 'info' },
    { label: 'Pending', value: String(pending), icon: 'pending_actions', color: 'warning' },
  ];
}

export const getRoleDashboardSnapshot = onCall(async (request: CallableRequest<{
  role?: string;
  siteId?: string;
  period?: string;
}>) => {
  const authUid = request.auth?.uid;
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const profile = await getUserProfile(authUid);
  const actorRole = normalizeRoleValue(profile?.role);
  if (!profile || !actorRole) {
    throw new HttpsError('permission-denied', 'User profile missing role.');
  }

  const requestedRole = normalizeRoleValue(request.data?.role) ?? actorRole;
  if (actorRole !== 'hq' && requestedRole !== actorRole) {
    throw new HttpsError('permission-denied', 'Cannot request dashboard for another role.');
  }

  const requestedSiteId =
    typeof request.data?.siteId === 'string' && request.data.siteId.trim().length > 0
      ? request.data.siteId.trim()
      : undefined;
  const siteId = resolveRoleSiteId(profile, actorRole, requestedSiteId);
  const stats = await computeRoleDashboardStats({
    role: requestedRole,
    uid: authUid,
    siteId,
    profile,
  });

  return {
    role: requestedRole,
    siteId: siteId ?? null,
    period:
      typeof request.data?.period === 'string' && request.data.period.trim().length > 0
        ? request.data.period.trim()
        : 'week',
    stats,
  };
});

export const getRoleLinkedRoster = onCall(async (request: CallableRequest<{
  role?: string;
  siteId?: string;
  parentId?: string;
  educatorId?: string;
}>) => {
  const authUid = request.auth?.uid;
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const profile = await getUserProfile(authUid);
  const actorRole = normalizeRoleValue(profile?.role);
  if (!profile || !actorRole) {
    throw new HttpsError('permission-denied', 'User profile missing role.');
  }

  const requestedRole = normalizeRoleValue(request.data?.role) ?? actorRole;
  if (actorRole !== 'hq' && requestedRole !== actorRole) {
    throw new HttpsError('permission-denied', 'Cannot request roster for another role.');
  }

  const requestedSiteId =
    typeof request.data?.siteId === 'string' && request.data.siteId.trim().length > 0
      ? request.data.siteId.trim()
      : undefined;
  const siteId = resolveRoleSiteId(profile, actorRole, requestedSiteId);
  const db = admin.firestore();

  let learners: Array<Record<string, unknown>> = [];
  let parents: Array<Record<string, unknown>> = [];
  let educators: Array<Record<string, unknown>> = [];

  if (requestedRole === 'parent') {
    const parentId =
      actorRole === 'parent'
        ? authUid
        : typeof request.data?.parentId === 'string'
        ? request.data.parentId.trim()
        : '';
    if (!parentId) {
      throw new HttpsError('invalid-argument', 'parentId is required for non-parent actors.');
    }
    const learnerIds = await collectParentLinkedLearnerIds({ parentId, siteId });
    learners = (await fetchUsersByIds(learnerIds)).map((item) => toRosterItem(item.id, item.data));
    const parentDoc = await db.collection(USERS_COLLECTION).doc(parentId).get();
    if (parentDoc.exists) {
      parents = [toRosterItem(parentDoc.id, parentDoc.data() as UserRecord)];
    }
  } else if (requestedRole === 'educator') {
    const educatorId =
      actorRole === 'educator'
        ? authUid
        : typeof request.data?.educatorId === 'string'
        ? request.data.educatorId.trim()
        : '';
    if (!educatorId) {
      throw new HttpsError('invalid-argument', 'educatorId is required for non-educator actors.');
    }

    const learnerIdSet = new Set<string>();
    try {
      let linksQuery: FirebaseFirestore.Query = db
        .collection('educatorLearnerLinks')
        .where('educatorId', '==', educatorId);
      if (siteId) {
        linksQuery = linksQuery.where('siteId', '==', siteId);
      }
      const links = await linksQuery.get();
      for (const doc of links.docs) {
        const learnerId = typeof doc.data().learnerId === 'string' ? doc.data().learnerId.trim() : '';
        if (learnerId) learnerIdSet.add(learnerId);
      }
    } catch {
      // Continue with fallback sources.
    }

    try {
      const usersByEducator = await db
        .collection(USERS_COLLECTION)
        .where('educatorIds', 'array-contains', educatorId)
        .get();
      for (const doc of usersByEducator.docs) {
        if (normalizeRoleValue(doc.data().role) === 'learner') {
          learnerIdSet.add(doc.id);
        }
      }
    } catch {
      // Keep deterministic output.
    }

    learners = (await fetchUsersByIds(Array.from(learnerIdSet.values()))).map((item) =>
      toRosterItem(item.id, item.data),
    );
    const educatorDoc = await db.collection(USERS_COLLECTION).doc(educatorId).get();
    if (educatorDoc.exists) {
      educators = [toRosterItem(educatorDoc.id, educatorDoc.data() as UserRecord)];
    }
  } else {
    if (!siteId) {
      throw new HttpsError('invalid-argument', 'siteId is required for this roster view.');
    }
    const users = await db
      .collection(USERS_COLLECTION)
      .where('siteIds', 'array-contains', siteId)
      .get();
    for (const doc of users.docs) {
      const userData = doc.data() as UserRecord;
      const normalizedRole = normalizeRoleValue(userData.role);
      if (normalizedRole === 'learner') learners.push(toRosterItem(doc.id, userData));
      if (normalizedRole === 'parent') parents.push(toRosterItem(doc.id, userData));
      if (normalizedRole === 'educator') educators.push(toRosterItem(doc.id, userData));
    }
  }

  return {
    role: requestedRole,
    siteId: siteId ?? null,
    learners,
    parents,
    educators,
    counts: {
      learners: learners.length,
      parents: parents.length,
      educators: educators.length,
    },
  };
});

export const listUsers = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);

  const role = normalizeRoleValue(request.data?.role);
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId : undefined;
  const searchEmail = typeof request.data?.email === 'string' ? request.data.email.toLowerCase() : undefined;
  const limit = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100 ? request.data.limit : 50;

  let query: FirebaseFirestore.Query = admin.firestore().collection(USERS_COLLECTION).limit(limit);

  if (role) {
    query = query.where('role', '==', role);
  }
  if (siteId) {
    query = query.where('siteIds', 'array-contains', siteId);
  }
  if (searchEmail) {
    query = query.where('email', '==', searchEmail);
  }

  const snap = await query.get();
  const users = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() as UserRecord) }));
  return { users };
});

export const updateUserRoles = onCall(async (request: CallableRequest) => {
  const { uid: actorId } = await requireHq(request.auth?.uid);

  const targetUid = typeof request.data?.uid === 'string' ? request.data.uid : undefined;
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'uid is required');
  }

  const nextRole = normalizeRoleValue(request.data?.role) ?? undefined;
  const siteIds = toStringArray(request.data?.siteIds);
  const activeSiteId = typeof request.data?.activeSiteId === 'string' ? request.data.activeSiteId : undefined;
  const isActive = typeof request.data?.isActive === 'boolean' ? request.data.isActive : undefined;

  const updates: Partial<UserRecord> = {};
  if (nextRole) updates.role = nextRole;
  if (siteIds.length) updates.siteIds = siteIds;
  if (activeSiteId) updates.activeSiteId = activeSiteId;
  if (isActive !== undefined) updates.isActive = isActive;

  updates.updatedAt = FieldValue.serverTimestamp();

  await admin.firestore().runTransaction(async (tx) => {
    const ref = admin.firestore().collection(USERS_COLLECTION).doc(targetUid);
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError('not-found', 'User not found');
    }
    const before = doc.data() as UserRecord;

    if (activeSiteId && siteIds.length && !siteIds.includes(activeSiteId)) {
      throw new HttpsError('failed-precondition', 'activeSiteId must be included in siteIds');
    }

    tx.update(ref, updates);

    const auditRef = admin.firestore().collection(AUDIT_COLLECTION).doc();
    tx.set(auditRef, {
      actorId,
      actorRole: 'hq',
      action: 'updateUserRoles',
      entityType: 'user',
      entityId: targetUid,
      details: { before, updates },
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return { status: 'ok' };
});

export const processCheckout = onCall(async (request: CallableRequest) => {
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const targetUserId = typeof request.data?.userId === 'string' ? request.data.userId.trim() : '';
  const productId = typeof request.data?.productId === 'string' ? request.data.productId.trim() : '' as ProductId;

  if (!siteId || !targetUserId) throw new HttpsError('invalid-argument', 'siteId and userId are required');
  if (!(productId in PRODUCT_CATALOG)) throw new HttpsError('invalid-argument', 'Unknown productId');

  const actor = await requireRoleAndSite(request.auth?.uid, ['hq', 'site'], siteId);

  const product = PRODUCT_CATALOG[productId as ProductId];
  const roles = product.roles;

  // Deprecated direct checkout; prefer createCheckoutIntent + completeCheckout.
  const orderRef = admin.firestore().collection(ORDERS_COLLECTION).doc();
  await admin.firestore().runTransaction(async (tx) => {
    tx.set(orderRef, {
      siteId,
      userId: targetUserId,
      productId,
      amount: product.amount,
      currency: product.currency,
      status: 'paid',
      entitlementRoles: roles,
      createdAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      actorId: actor.uid,
      actorRole: actor.role,
    });
  });

  await persistTelemetryEvent({
    event: 'order.paid',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: { orderId: orderRef.id, productId, targetUserId, amount: product.amount, currency: product.currency },
  });

  return { orderId: orderRef.id, amount: product.amount, currency: product.currency, roles };
});

export const requestNotificationSend = onCall(async (request: CallableRequest) => {
  const channel = typeof request.data?.channel === 'string' ? request.data.channel.trim() : '';
  const threadId = typeof request.data?.threadId === 'string' ? request.data.threadId.trim() : '';
  const messageId = typeof request.data?.messageId === 'string' ? request.data.messageId.trim() : '';
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';

  const allowedChannels = new Set(['email', 'sms', 'push']);
  if (!channel || !allowedChannels.has(channel)) {
    throw new HttpsError('invalid-argument', 'Invalid channel');
  }
  if (!threadId || !messageId || !siteId) {
    throw new HttpsError('invalid-argument', 'threadId, messageId, and siteId are required');
  }

  const actor = await requireRoleAndSite(request.auth?.uid, ['educator', 'site', 'hq'], siteId);

  const docRef = admin.firestore().collection(NOTIFICATION_REQUESTS_COLLECTION).doc();
  await docRef.set({
    channel,
    threadId,
    messageId,
    siteId,
    requestedBy: actor.uid,
    role: actor.role,
    rateKey: `${actor.uid}:${channel}`,
    createdAt: FieldValue.serverTimestamp(),
    status: 'pending',
  });

  await persistTelemetryEvent({
    event: 'notification.requested',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: { channel, threadId, messageId },
  });

  return { status: 'queued', id: docRef.id };
});

export const syncLearnerReminderPreference = onCall(async (request: CallableRequest) => {
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const schedule = typeof request.data?.schedule === 'string' ? request.data.schedule.trim() : '';
  const weeklyTargetMinutes =
    typeof request.data?.weeklyTargetMinutes === 'number' ? request.data.weeklyTargetMinutes : 0;
  const localeCode = typeof request.data?.localeCode === 'string' ? request.data.localeCode.trim() : 'en';
  const timeZone = typeof request.data?.timeZone === 'string' ? request.data.timeZone.trim() : 'auto';
  const valuePrompt = typeof request.data?.valuePrompt === 'string' ? request.data.valuePrompt.trim() : '';

  if (!siteId) {
    throw new HttpsError('invalid-argument', 'siteId is required');
  }
  if (!new Set(['off', 'daily', 'weekdays', 'weekends']).has(schedule)) {
    throw new HttpsError('invalid-argument', 'Invalid schedule');
  }

  const actor = await requireRoleAndSite(request.auth?.uid, ['learner', 'educator', 'site', 'hq'], siteId);
  const docRef = admin.firestore()
    .collection(LEARNER_REMINDER_PREFERENCES_COLLECTION)
    .doc(`${siteId}_${actor.uid}`);
  const enabled = schedule !== 'off' && weeklyTargetMinutes > 0;
  await docRef.set({
    learnerId: actor.uid,
    siteId,
    schedule,
    weeklyTargetMinutes,
    localeCode,
    timeZone,
    valuePrompt,
    enabled,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await persistTelemetryEvent({
    event: 'notification.requested',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: {
      channel: 'push',
      type: 'learner_goal_reminder.preference_sync',
      schedule,
      enabled,
    },
  });

  return { status: enabled ? 'enabled' : 'disabled' };
});

export const resetUserPassword = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);
  const email = typeof request.data?.email === 'string' ? request.data.email : undefined;
  if (!email) {
    throw new HttpsError('invalid-argument', 'email is required');
  }
  const link = await admin.auth().generatePasswordResetLink(email);
  return { link };
});

export const listAuditLogs = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);
  const limit = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100 ? request.data.limit : 50;
  const filters = normalizeAuditLogFilters((request.data || {}) as Record<string, unknown>);

  const applyFilters = (baseQuery: FirebaseFirestore.Query): FirebaseFirestore.Query => {
    let nextQuery = baseQuery;
    if (filters.entityId) {
      nextQuery = nextQuery.where('entityId', '==', filters.entityId);
    }
    if (filters.entityType) {
      nextQuery = nextQuery.where('entityType', '==', filters.entityType);
    }
    if (filters.actions.length === 1) {
      nextQuery = nextQuery.where('action', '==', filters.actions[0]);
    } else if (filters.actions.length > 1) {
      nextQuery = nextQuery.where('action', 'in', filters.actions);
    }
    return nextQuery;
  };

  const orderedQuery = admin.firestore().collection(AUDIT_COLLECTION).orderBy('createdAt', 'desc');
  let logs: Array<Record<string, unknown>>;
  try {
    const snap = await applyFilters(orderedQuery).limit(limit).get();
    logs = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  } catch {
    const fallbackSnap = await orderedQuery.limit(Math.min(limit * 5, 500)).get();
    logs = fallbackSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((entry) => matchesAuditLogFilters(entry, filters))
      .slice(0, limit);
  }

  return { logs };
});

export const listAnalyticsRepairRuns = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);
  const limit = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 120 ? request.data.limit : 60;
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';

  let logs: Array<Record<string, unknown>>;
  try {
    let query: FirebaseFirestore.Query = admin.firestore().collection(AUDIT_COLLECTION)
      .where('action', 'in', [...ANALYTICS_REPAIR_AUDIT_ACTIONS])
      .orderBy('createdAt', 'desc')
      .limit(limit);
    if (siteId) {
      query = query.where('siteId', '==', siteId);
    }
    const snap = await query.get();
    logs = snap.docs.map((doc): Record<string, unknown> => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }));
  } catch {
    const snap = await admin.firestore().collection(AUDIT_COLLECTION)
      .orderBy('createdAt', 'desc')
      .limit(Math.min(limit * 5, 500))
      .get();
    logs = snap.docs
      .map((doc): Record<string, unknown> => ({ id: doc.id, ...(doc.data() as Record<string, unknown>) }))
      .filter((entry) => {
        if (typeof entry.action !== 'string') {
          return false;
        }
        return ANALYTICS_REPAIR_AUDIT_ACTIONS.includes(
          entry.action as typeof ANALYTICS_REPAIR_AUDIT_ACTIONS[number],
        );
      })
      .filter((entry) => !siteId || entry.siteId === siteId)
      .slice(0, limit);
  }

  return {
    runs: logs
      .map((entry) => buildAnalyticsRepairRunRecord(entry as { id: string; [key: string]: unknown }))
      .filter((entry): entry is NonNullable<typeof entry> => entry !== null),
  };
});

export const recordLogoutAudit = onCall(async (request: CallableRequest) => {
  const requestedSiteId = typeof request.data?.siteId === 'string'
    ? request.data.siteId.trim()
    : '';
  const actor = await requireRoleAndSite(
    request.auth?.uid,
    ['learner', 'educator', 'parent', 'site', 'partner', 'hq'],
    requestedSiteId || undefined,
  );
  const source = typeof request.data?.source === 'string'
    && request.data.source.trim().length > 0
    ? request.data.source.trim()
    : 'unknown';
  const impersonatingRole = typeof request.data?.impersonatingRole === 'string'
    && request.data.impersonatingRole.trim().length > 0
    ? request.data.impersonatingRole.trim().toLowerCase()
    : undefined;
  const siteId = requestedSiteId || actor.profile.activeSiteId || undefined;

  const id = await persistLogoutAuditRecord({
    actorId: actor.uid,
    actorRole: actor.role,
    source,
    siteId,
    impersonatingRole,
    collectionName: AUDIT_COLLECTION,
  });

  return { status: 'ok', id };
});

export const processNotificationRequests = onSchedule('every 5 minutes', async () => {
  const db = admin.firestore();
  const pendingSnap = await db
    .collection(NOTIFICATION_REQUESTS_COLLECTION)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'asc')
    .limit(10)
    .get();

  const now = Timestamp.now();

  for (const docSnap of pendingSnap.docs) {
    const data = docSnap.data();
    const rateKey = (data.rateKey as string | undefined) ?? 'global';
    const rateRef = db.collection(NOTIFICATION_RATE_COLLECTION).doc(rateKey);
    const rateSnap = await rateRef.get();
    const last = rateSnap.exists ? (rateSnap.data()?.lastProcessedAt as Timestamp | undefined) : undefined;
    if (last && now.toMillis() - last.toMillis() < 60_000) {
      // Skip due to rate limit
      continue;
    }

    await rateRef.set({ lastProcessedAt: now }, { merge: true });
    try {
      const result = await sendNotification({
        channel: data.channel as string,
        threadId: data.threadId as string | undefined,
        messageId: data.messageId as string | undefined,
        siteId: data.siteId as string | undefined,
        userId: data.userId as string | undefined,
        type: data.type as string | undefined,
        data: data.data as Record<string, unknown> | undefined,
      });
      await docSnap.ref.set({ status: 'sent', processedAt: now, providerMessageId: result.providerMessageId }, { merge: true });
      await persistTelemetryEvent({
        event: 'notification.requested',
        userId: (data.requestedBy as string | undefined) ?? 'system',
        role: data.role as Role | undefined,
        siteId: data.siteId as string | undefined,
        metadata: {
          channel: data.channel,
          threadId: data.threadId,
          messageId: data.messageId,
          type: data.type,
          userId: data.userId,
          processed: true,
        },
      });
      const auditRef = db.collection(AUDIT_COLLECTION).doc();
      await auditRef.set({
        actorId: 'notifier',
        actorRole: 'hq',
        action: 'notification.sent',
        entityType: 'notificationRequest',
        entityId: docSnap.id,
        siteId: data.siteId,
        details: {
          channel: data.channel,
          threadId: data.threadId,
          messageId: data.messageId,
          type: data.type,
          userId: data.userId,
        },
        createdAt: now,
      });
    } catch (e) {
      await docSnap.ref.set({ status: 'error', processedAt: now, error: (e as Error).message }, { merge: true });
    }
  }
});

export const scheduleLearnerGoalReminders = onSchedule('every 6 hours', async () => {
  const db = admin.firestore();
  await enqueueLearnerGoalReminders({
    db,
    reminderPreferencesCollection: LEARNER_REMINDER_PREFERENCES_COLLECTION,
    notificationRequestsCollection: NOTIFICATION_REQUESTS_COLLECTION,
    persistTelemetryEvent,
  });
});

export const createCheckoutIntent = onCall(async (request: CallableRequest) => {
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const targetUserId = typeof request.data?.userId === 'string' ? request.data.userId.trim() : '';
  const productId = typeof request.data?.productId === 'string' ? request.data.productId.trim() : '' as ProductId;
  const listingId = typeof request.data?.listingId === 'string' ? request.data.listingId.trim() : '';
  const idempotencyKey = typeof request.data?.idempotencyKey === 'string' ? request.data.idempotencyKey.trim() : '';

  if (!siteId || !targetUserId) throw new HttpsError('invalid-argument', 'siteId and userId are required');
  if (!(productId in PRODUCT_CATALOG)) throw new HttpsError('invalid-argument', 'Unknown productId');
  if (!idempotencyKey || idempotencyKey.length < 8) throw new HttpsError('invalid-argument', 'idempotencyKey required');

  const actor = await requireRoleAndSite(request.auth?.uid, ['hq', 'site'], siteId);

  const product = PRODUCT_CATALOG[productId as ProductId];

  const existing = await admin
    .firestore()
    .collection(CHECKOUT_INTENTS_COLLECTION)
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();
  if (!existing.empty) {
    const doc = existing.docs[0];
    return {
      intentId: doc.id,
      orderId: doc.id,
      amount: doc.data().amount,
      currency: doc.data().currency,
      status: doc.data().status,
    };
  }

  const intentRef = admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc();
  await intentRef.set({
    siteId,
    userId: targetUserId,
    productId,
    idempotencyKey,
    amount: product.amount,
    currency: product.currency,
    status: 'intent',
    actorId: actor.uid,
    actorRole: actor.role,
    listingId: listingId || null,
    createdAt: FieldValue.serverTimestamp(),
  });

  await persistTelemetryEvent({
    event: 'order.intent',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: {
      productId,
      targetUserId,
      ...(listingId ? { listingId } : {}),
    },
  });

  return {
    intentId: intentRef.id,
    orderId: intentRef.id,
    amount: product.amount,
    currency: product.currency,
    status: 'intent',
  };
});

export const completeCheckout = onCall(async (request: CallableRequest) => {
  const intentId = typeof request.data?.intentId === 'string' ? request.data.intentId.trim() : '';
  const amountPaid = typeof request.data?.amount === 'string' ? request.data.amount.trim() : '';
  const currencyPaid = typeof request.data?.currency === 'string' ? request.data.currency.trim() : '';
  if (!intentId) throw new HttpsError('invalid-argument', 'intentId required');

  const actor = await requireRoleAndSite(request.auth?.uid, ['hq', 'site'], undefined);

  const intentSnap = await admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId).get();
  if (!intentSnap.exists) throw new HttpsError('not-found', 'Intent not found');
  const intent = intentSnap.data() as any;
  if (intent.status === 'paid') {
    return { orderId: intentId, entitlementId: intent.entitlementId, status: 'paid' };
  }

  const productId = intent.productId as ProductId;
  if (!(productId in PRODUCT_CATALOG)) throw new HttpsError('failed-precondition', 'Intent product missing');
  const product = PRODUCT_CATALOG[productId];
  if (amountPaid && amountPaid != product.amount) throw new HttpsError('invalid-argument', 'Amount mismatch');
  if (currencyPaid && currencyPaid != product.currency) throw new HttpsError('invalid-argument', 'Currency mismatch');

  const orderRef = admin.firestore().collection(ORDERS_COLLECTION).doc(intentId);
  const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();
  const fulfillmentRef = admin.firestore().collection(FULFILLMENTS_COLLECTION).doc();

  await admin.firestore().runTransaction(async (tx) => {
    const intentDoc = await tx.get(intentSnap.ref);
    const current = intentDoc.data();
    if (!current) throw new HttpsError('not-found', 'Intent missing');
    if (current.status === 'paid') return;

    tx.set(intentSnap.ref, {
      status: 'paid',
      paidAt: FieldValue.serverTimestamp(),
      entitlementId: entitlementRef.id,
    }, { merge: true });

    tx.set(orderRef, {
      siteId: current.siteId,
      userId: current.userId,
      productId,
      amount: product.amount,
      currency: product.currency,
      status: 'paid',
      entitlementRoles: product.roles,
      actorId: actor.uid,
      actorRole: actor.role,
      listingId: current.listingId ?? null,
      createdAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(entitlementRef, {
      userId: current.userId,
      siteId: current.siteId,
      productId,
      roles: product.roles,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (typeof current.listingId === 'string' && current.listingId.trim().length > 0) {
      tx.set(fulfillmentRef, {
        orderId: orderRef.id,
        listingId: current.listingId.trim(),
        userId: current.userId,
        siteId: current.siteId,
        status: 'pending',
        note: 'Awaiting partner fulfillment',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
    tx.set(
      userRef,
      {
        roles: FieldValue.arrayUnion(...product.roles),
        entitlements: FieldValue.arrayUnion(...product.roles),
        siteIds: FieldValue.arrayUnion(current.siteId),
        primarySiteId: current.siteId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const auditRef = admin.firestore().collection(AUDIT_COLLECTION).doc();
    tx.set(auditRef, {
      actorId: actor.uid,
      actorRole: actor.role,
      action: 'checkout.completed',
      entityType: 'order',
      entityId: intentId,
      siteId: current.siteId,
      details: { productId, amount: product.amount, currency: product.currency, roles: product.roles },
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  await persistTelemetryEvent({
    event: 'order.paid',
    userId: actor.uid,
    role: actor.role,
    siteId: intent.siteId as string,
    metadata: {
      orderId: orderRef.id,
      productId,
      targetUserId: intent.userId,
      amount: product.amount,
      currency: product.currency,
      ...(
        typeof intent.listingId === 'string' && intent.listingId.trim().length > 0
            ? { listingId: intent.listingId }
            : {}
      ),
    },
  });

  return {
    orderId: orderRef.id,
    entitlementId: entitlementRef.id,
    status: 'paid',
    amount: product.amount,
    currency: product.currency,
    listingId: intent.listingId ?? null,
  };
});

export const completeCheckoutWebhook = onRequest(async (req, res) => {
  const secret = req.headers['x-webhook-secret'];
  const signature = req.headers['x-webhook-signature'];
  const payload = JSON.stringify(req.body ?? {});
  const webhookSecretVal = stripeWebhookSecret.value();
  const expectedSig = webhookSecretVal ? createHmac('sha256', webhookSecretVal).update(payload).digest('hex') : '';
  if (!webhookSecretVal || secret !== webhookSecretVal || signature !== expectedSig) {
    res.status(401).send('unauthorized');
    return;
  }

  const intentId = typeof req.body?.intentId === 'string' ? req.body.intentId.trim() : '';
  const amountPaid = typeof req.body?.amount === 'string' ? req.body.amount.trim() : '';
  const currencyPaid = typeof req.body?.currency === 'string' ? req.body.currency.trim() : '';
  if (!intentId) {
    res.status(400).send('intentId required');
    return;
  }

  try {
    const intentSnap = await admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId).get();
    if (!intentSnap.exists) {
      res.status(404).send('intent not found');
      return;
    }
    const intent = intentSnap.data() as any;
    if (intent.status === 'paid') {
      res.status(200).send({ status: 'paid', orderId: intentId, entitlementId: intent.entitlementId });
      return;
    }

    const productId = intent.productId as ProductId;
    if (!(productId in PRODUCT_CATALOG)) throw new Error('Unknown product');
    const product = PRODUCT_CATALOG[productId];
    if (amountPaid && amountPaid != product.amount) throw new Error('Amount mismatch');
    if (currencyPaid && currencyPaid != product.currency) throw new Error('Currency mismatch');

    const orderRef = admin.firestore().collection(ORDERS_COLLECTION).doc(intentId);
    const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();
    const fulfillmentRef = admin.firestore().collection(FULFILLMENTS_COLLECTION).doc();

    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(intentSnap.ref);
      const current = snap.data();
      if (!current) throw new Error('Intent missing');
      if (current.status === 'paid') return;

      tx.set(intentSnap.ref, {
        status: 'paid',
        paidAt: FieldValue.serverTimestamp(),
        entitlementId: entitlementRef.id,
      }, { merge: true });

      tx.set(orderRef, {
        siteId: current.siteId,
        userId: current.userId,
        productId,
        amount: product.amount,
        currency: product.currency,
        status: 'paid',
        entitlementRoles: product.roles,
        actorId: current.actorId ?? 'webhook',
        actorRole: current.actorRole ?? 'hq',
        listingId: current.listingId ?? null,
        createdAt: FieldValue.serverTimestamp(),
        paidAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      tx.set(entitlementRef, {
        userId: current.userId,
        siteId: current.siteId,
        productId,
        roles: product.roles,
        createdAt: FieldValue.serverTimestamp(),
      });

      if (typeof current.listingId === 'string' && current.listingId.trim().length > 0) {
        tx.set(fulfillmentRef, {
          orderId: orderRef.id,
          listingId: current.listingId.trim(),
          userId: current.userId,
          siteId: current.siteId,
          status: 'pending',
          note: 'Awaiting partner fulfillment',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
      tx.set(
        userRef,
        {
          roles: FieldValue.arrayUnion(...product.roles),
          entitlements: FieldValue.arrayUnion(...product.roles),
          siteIds: FieldValue.arrayUnion(current.siteId),
          primarySiteId: current.siteId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const auditRef = admin.firestore().collection(AUDIT_COLLECTION).doc();
      tx.set(auditRef, {
        actorId: 'webhook',
        actorRole: 'hq',
        action: 'checkout.completed',
        entityType: 'order',
        entityId: intentId,
        siteId: current.siteId,
        details: { productId, amount: product.amount, currency: product.currency, roles: product.roles, via: 'webhook' },
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    await persistTelemetryEvent({
      event: 'order.paid',
      userId: (intent.actorId as string | undefined) ?? 'system',
      role: intent.actorRole as Role | undefined,
      siteId: intent.siteId as string,
      metadata: {
        orderId: orderRef.id,
        productId,
        targetUserId: intent.userId,
        amount: product.amount,
        currency: product.currency,
        via: 'webhook',
        ...(
          typeof intent.listingId === 'string' && intent.listingId.trim().length > 0
              ? { listingId: intent.listingId }
              : {}
        ),
      },
    });

    res.status(200).send({
      status: 'paid',
      orderId: orderRef.id,
      entitlementId: entitlementRef.id,
      listingId: intent.listingId ?? null,
    });
  } catch (e: any) {
    res.status(500).send(e?.message ?? 'error');
  }
});

// ============================================================================
// STRIPE PAYMENT INTEGRATION
// ============================================================================

/**
 * Get or create a Stripe customer for a user
 */
async function getOrCreateStripeCustomer(userId: string, email: string, name?: string, stripeInstance?: Stripe): Promise<string> {
  const stripeClient = stripeInstance || getStripe();
  if (!stripeClient) throw new HttpsError('failed-precondition', 'Stripe not configured');

  const customerRef = admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(userId);
  const customerSnap = await customerRef.get();

  if (customerSnap.exists) {
    const data = customerSnap.data();
    if (data?.stripeCustomerId) {
      return data.stripeCustomerId as string;
    }
  }

  // Create new Stripe customer
  const customer = await stripeClient.customers.create({
    email,
    name: name ?? undefined,
    metadata: {
      firebaseUserId: userId,
    },
  });

  await customerRef.set({
    stripeCustomerId: customer.id,
    email,
    name,
    createdAt: FieldValue.serverTimestamp(),
  });

  return customer.id;
}

/**
 * Create a Stripe Checkout Session for purchasing a product
 */
export const createStripeCheckoutSession = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');

  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const targetUserId = typeof request.data?.userId === 'string' ? request.data.userId.trim() : '';
  const productId = typeof request.data?.productId === 'string' ? request.data.productId.trim() : '' as ProductId;
  const successUrl = typeof request.data?.successUrl === 'string' ? request.data.successUrl : '';
  const cancelUrl = typeof request.data?.cancelUrl === 'string' ? request.data.cancelUrl : '';

  if (!siteId || !targetUserId) throw new HttpsError('invalid-argument', 'siteId and userId are required');
  if (!(productId in PRODUCT_CATALOG)) throw new HttpsError('invalid-argument', 'Unknown productId');
  if (!successUrl || !cancelUrl) throw new HttpsError('invalid-argument', 'successUrl and cancelUrl are required');

  const actor = await requireRoleAndSite(request.auth?.uid, ['hq', 'site', 'parent', 'learner'], siteId);

  // Get target user email
  const targetUserSnap = await admin.firestore().collection(USERS_COLLECTION).doc(targetUserId).get();
  if (!targetUserSnap.exists) throw new HttpsError('not-found', 'Target user not found');
  const targetUser = targetUserSnap.data() as UserRecord;
  if (!targetUser.email) throw new HttpsError('failed-precondition', 'Target user has no email');

  const product = PRODUCT_CATALOG[productId as ProductId];
  const priceId = getStripePriceIds()[productId as ProductId];

  // Get or create Stripe customer
  const stripeCustomerId = await getOrCreateStripeCustomer(
    targetUserId,
    targetUser.email,
    targetUser.displayName,
    stripeInstance
  );

  // Create checkout intent record for tracking
  const intentRef = admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc();
  await intentRef.set({
    siteId,
    userId: targetUserId,
    productId,
    amount: product.amount,
    currency: product.currency,
    status: 'pending_stripe',
    actorId: actor.uid,
    actorRole: actor.role,
    stripeCustomerId,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Create Stripe Checkout Session
  const session = await stripeInstance.checkout.sessions.create({
    customer: stripeCustomerId,
    payment_method_types: ['card'],
    line_items: [
      {
        price: priceId,
        quantity: 1,
      },
    ],
    mode: 'payment', // Use 'subscription' for recurring
    success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}&intent_id=${intentRef.id}`,
    cancel_url: cancelUrl,
    metadata: {
      firebaseIntentId: intentRef.id,
      siteId,
      targetUserId,
      productId,
      actorId: actor.uid,
    },
    client_reference_id: intentRef.id,
  });

  // Update intent with session ID
  await intentRef.update({
    stripeSessionId: session.id,
    stripeSessionUrl: session.url,
  });

  await persistTelemetryEvent({
    event: 'order.intent',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: { productId, targetUserId, stripeSessionId: session.id },
  });

  return {
    sessionId: session.id,
    sessionUrl: session.url,
    intentId: intentRef.id,
    amount: product.amount,
    currency: product.currency,
  };
});

/**
 * Create a Stripe Checkout Session for subscriptions
 */
export const createStripeSubscription = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');

  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const productId = typeof request.data?.productId === 'string' ? request.data.productId.trim() : '' as ProductId;
  const successUrl = typeof request.data?.successUrl === 'string' ? request.data.successUrl : '';
  const cancelUrl = typeof request.data?.cancelUrl === 'string' ? request.data.cancelUrl : '';

  if (!siteId) throw new HttpsError('invalid-argument', 'siteId is required');
  if (!(productId in PRODUCT_CATALOG)) throw new HttpsError('invalid-argument', 'Unknown productId');
  if (!successUrl || !cancelUrl) throw new HttpsError('invalid-argument', 'successUrl and cancelUrl are required');

  const actor = await requireRoleAndSite(request.auth?.uid, ['hq', 'site'], siteId);

  const actorProfile = await getUserProfile(actor.uid);
  if (!actorProfile?.email) throw new HttpsError('failed-precondition', 'User has no email');

  const product = PRODUCT_CATALOG[productId as ProductId];
  const priceId = getStripePriceIds()[productId as ProductId];

  const stripeCustomerId = await getOrCreateStripeCustomer(
    actor.uid,
    actorProfile.email,
    actorProfile.displayName
  );

  // Create subscription record
  const subRef = admin.firestore().collection(SUBSCRIPTIONS_COLLECTION).doc();
  await subRef.set({
    siteId,
    userId: actor.uid,
    productId,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  const session = await stripeInstance.checkout.sessions.create({
    customer: stripeCustomerId,
    payment_method_types: ['card'],
    line_items: [
      {
        price: priceId,
        quantity: 1,
      },
    ],
    mode: 'subscription',
    success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}&subscription_id=${subRef.id}`,
    cancel_url: cancelUrl,
    metadata: {
      firebaseSubscriptionId: subRef.id,
      siteId,
      userId: actor.uid,
      productId,
    },
    client_reference_id: subRef.id,
  });

  await subRef.update({
    stripeSessionId: session.id,
  });

  return {
    sessionId: session.id,
    sessionUrl: session.url,
    subscriptionId: subRef.id,
    amount: product.amount,
    currency: product.currency,
  };
});

/**
 * Stripe Webhook Handler - processes all payment events comprehensively
 * 
 * Supported Events:
 * - checkout.session.completed: One-time payment or subscription checkout completed
 * - checkout.session.expired: Checkout session expired without completion
 * - invoice.paid: Subscription invoice paid successfully
 * - invoice.payment_failed: Subscription invoice payment failed
 * - invoice.upcoming: Invoice will be created soon (for notifications)
 * - customer.subscription.created: New subscription created
 * - customer.subscription.updated: Subscription status changed
 * - customer.subscription.deleted: Subscription cancelled/ended
 * - customer.subscription.trial_will_end: Trial ending soon (3 days before)
 * - payment_intent.succeeded: One-time payment succeeded
 * - payment_intent.payment_failed: One-time payment failed
 * - payment_method.attached: New payment method added
 * - payment_method.detached: Payment method removed
 * - charge.refunded: Payment was refunded
 * - charge.dispute.created: Customer disputed a charge
 * - charge.dispute.closed: Dispute was resolved
 */
export const stripeWebhook = onRequest({ 
  cors: false,
  secrets: [stripeSecretKey, stripeWebhookSecret],
}, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const stripeInstance = getStripe();
  const webhookSecret = stripeWebhookSecret.value();

  if (!stripeInstance || !webhookSecret) {
    console.error('Stripe not configured - missing secrets');
    res.status(500).send('Stripe not configured');
    return;
  }

  const sig = req.headers['stripe-signature'];
  if (!sig) {
    res.status(400).send('Missing stripe-signature header');
    return;
  }

  let event: Stripe.Event;
  try {
    const rawBody = req.rawBody;
    event = stripeInstance.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err: any) {
    console.error('Webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Log all webhook events for audit trail
  await logWebhookEvent(event);

  try {
    switch (event.type) {
      // ============= CHECKOUT EVENTS =============
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutSessionCompleted(session);
        break;
      }

      case 'checkout.session.expired': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutSessionExpired(session);
        break;
      }

      // ============= INVOICE EVENTS =============
      case 'invoice.paid': {
        const invoice = event.data.object as Stripe.Invoice;
        await handleInvoicePaid(invoice);
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice;
        await handleInvoicePaymentFailed(invoice);
        break;
      }

      case 'invoice.upcoming': {
        const invoice = event.data.object as Stripe.Invoice;
        await handleInvoiceUpcoming(invoice);
        break;
      }

      case 'invoice.finalized': {
        const invoice = event.data.object as Stripe.Invoice;
        console.log('Invoice finalized:', invoice.id);
        break;
      }

      // ============= SUBSCRIPTION EVENTS =============
      case 'customer.subscription.created': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionCreated(subscription);
        break;
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionUpdated(subscription);
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionDeleted(subscription);
        break;
      }

      case 'customer.subscription.trial_will_end': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleTrialWillEnd(subscription);
        break;
      }

      // ============= PAYMENT INTENT EVENTS =============
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentIntentSucceeded(paymentIntent);
        break;
      }

      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentIntentFailed(paymentIntent);
        break;
      }

      case 'payment_intent.canceled': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log('Payment intent canceled:', paymentIntent.id);
        break;
      }

      // ============= PAYMENT METHOD EVENTS =============
      case 'payment_method.attached': {
        const paymentMethod = event.data.object as Stripe.PaymentMethod;
        await handlePaymentMethodAttached(paymentMethod);
        break;
      }

      case 'payment_method.detached': {
        const paymentMethod = event.data.object as Stripe.PaymentMethod;
        await handlePaymentMethodDetached(paymentMethod);
        break;
      }

      // ============= CHARGE/REFUND EVENTS =============
      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge;
        await handleChargeRefunded(charge);
        break;
      }

      case 'charge.dispute.created': {
        const dispute = event.data.object as Stripe.Dispute;
        await handleDisputeCreated(dispute);
        break;
      }

      case 'charge.dispute.closed': {
        const dispute = event.data.object as Stripe.Dispute;
        await handleDisputeClosed(dispute);
        break;
      }

      // ============= CUSTOMER EVENTS =============
      case 'customer.updated': {
        const customer = event.data.object as Stripe.Customer;
        await handleCustomerUpdated(customer);
        break;
      }

      case 'customer.deleted': {
        const customer = event.data.object as unknown as Stripe.DeletedCustomer;
        await handleCustomerDeleted(customer);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.status(200).json({ received: true, type: event.type });
  } catch (err: any) {
    console.error('Error processing webhook:', err);
    // Return 200 to prevent Stripe retries for non-retryable errors
    // But log for investigation
    res.status(200).json({ received: true, error: err.message });
  }
});

/**
 * Log all webhook events for audit and debugging
 */
async function logWebhookEvent(event: Stripe.Event) {
  try {
    await admin.firestore().collection('stripeWebhookLogs').add({
      eventId: event.id,
      eventType: event.type,
      livemode: event.livemode,
      created: new Date(event.created * 1000),
      receivedAt: FieldValue.serverTimestamp(),
      objectId: (event.data.object as any).id,
    });
  } catch (err) {
    console.error('Failed to log webhook event:', err);
  }
}

/**
 * Handle expired checkout sessions
 */
async function handleCheckoutSessionExpired(session: Stripe.Checkout.Session) {
  const intentId = session.metadata?.firebaseIntentId || session.client_reference_id;
  if (!intentId) return;

  const intentRef = admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId);
  const intentSnap = await intentRef.get();
  
  if (intentSnap.exists && intentSnap.data()?.status === 'pending') {
    await intentRef.update({
      status: 'expired',
      expiredAt: FieldValue.serverTimestamp(),
    });
    console.log('Checkout session expired:', intentId);
  }
}

/**
 * Handle upcoming invoice notification
 */
async function handleInvoiceUpcoming(invoice: Stripe.Invoice) {
  const invoiceData = invoice as any;
  const customerId = typeof invoiceData.customer === 'string' ? invoiceData.customer : invoiceData.customer?.id;
  if (!customerId) return;

  // Find user by Stripe customer ID
  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .where('stripeCustomerId', '==', customerId)
    .limit(1)
    .get();

  if (customerSnap.empty) return;

  const userId = customerSnap.docs[0].id;

  // Create notification for upcoming invoice
  await admin.firestore().collection(NOTIFICATION_REQUESTS_COLLECTION).add({
    userId,
    type: 'invoice_upcoming',
    channel: 'email',
    status: 'pending',
    data: {
      amount: invoiceData.amount_due,
      currency: invoiceData.currency,
      dueDate: invoiceData.due_date ? new Date(invoiceData.due_date * 1000) : null,
      invoiceUrl: invoiceData.hosted_invoice_url,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Upcoming invoice notification created for user:', userId);
}

/**
 * Handle new subscription created
 */
async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const subData = subscription as any;
  const customerId = typeof subData.customer === 'string' ? subData.customer : subData.customer?.id;
  if (!customerId) return;

  // Check if we already have this subscription
  const existingSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscription.id)
    .limit(1)
    .get();

  if (!existingSnap.empty) {
    console.log('Subscription already exists:', subscription.id);
    return;
  }

  // Find user by Stripe customer ID
  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .where('stripeCustomerId', '==', customerId)
    .limit(1)
    .get();

  if (customerSnap.empty) {
    console.log('No user found for customer:', customerId);
    return;
  }

  const userId = customerSnap.docs[0].id;
  const productId = subscription.metadata?.productId as ProductId;
  const siteId = subscription.metadata?.siteId || '';

  // Create subscription record
  await admin.firestore().collection(SUBSCRIPTIONS_COLLECTION).add({
    userId,
    siteId,
    productId,
    stripeSubscriptionId: subscription.id,
    stripeCustomerId: customerId,
    status: subscription.status,
    currentPeriodStart: subData.current_period_start ? new Date(subData.current_period_start * 1000) : null,
    currentPeriodEnd: subData.current_period_end ? new Date(subData.current_period_end * 1000) : null,
    cancelAtPeriodEnd: subData.cancel_at_period_end,
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Subscription created:', subscription.id, 'for user:', userId);
}

/**
 * Handle trial ending notification
 */
async function handleTrialWillEnd(subscription: Stripe.Subscription) {
  const subData = subscription as any;
  const subSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscription.id)
    .limit(1)
    .get();

  if (subSnap.empty) return;

  const subDoc = subSnap.docs[0];
  const sub = subDoc.data();

  // Create notification for trial ending
  await admin.firestore().collection(NOTIFICATION_REQUESTS_COLLECTION).add({
    userId: sub.userId,
    type: 'trial_ending',
    channel: 'email',
    status: 'pending',
    data: {
      trialEnd: subData.trial_end ? new Date(subData.trial_end * 1000) : null,
      productId: sub.productId,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Trial ending notification created for subscription:', subscription.id);
}

/**
 * Handle successful payment intent (one-time payments)
 */
async function handlePaymentIntentSucceeded(paymentIntent: Stripe.PaymentIntent) {
  const intentId = paymentIntent.metadata?.firebaseIntentId;
  if (!intentId) {
    console.log('No Firebase intent ID in payment intent:', paymentIntent.id);
    return;
  }

  // This might already be handled by checkout.session.completed
  // but we handle it here for direct payment intents
  const intentRef = admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId);
  const intentSnap = await intentRef.get();

  if (!intentSnap.exists) return;

  const intent = intentSnap.data() as any;
  if (intent.status === 'paid') return;

  await intentRef.update({
    status: 'paid',
    stripePaymentIntentId: paymentIntent.id,
    paidAt: FieldValue.serverTimestamp(),
  });

  console.log('Payment intent succeeded:', paymentIntent.id);
}

/**
 * Handle failed payment intent
 */
async function handlePaymentIntentFailed(paymentIntent: Stripe.PaymentIntent) {
  const intentId = paymentIntent.metadata?.firebaseIntentId;
  if (!intentId) return;

  const intentRef = admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId);
  const intentSnap = await intentRef.get();

  if (!intentSnap.exists) return;

  const piData = paymentIntent as any;
  await intentRef.update({
    status: 'failed',
    failureReason: piData.last_payment_error?.message || 'Payment failed',
    failedAt: FieldValue.serverTimestamp(),
  });

  // Create notification for failed payment
  const intent = intentSnap.data() as any;
  if (intent.userId) {
    await admin.firestore().collection(NOTIFICATION_REQUESTS_COLLECTION).add({
      userId: intent.userId,
      type: 'payment_failed',
      channel: 'email',
      status: 'pending',
      data: {
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        reason: piData.last_payment_error?.message,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  console.log('Payment intent failed:', paymentIntent.id);
}

/**
 * Handle payment method attached to customer
 */
async function handlePaymentMethodAttached(paymentMethod: Stripe.PaymentMethod) {
  const pmData = paymentMethod as any;
  const customerId = typeof pmData.customer === 'string' ? pmData.customer : pmData.customer?.id;
  if (!customerId) return;

  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .where('stripeCustomerId', '==', customerId)
    .limit(1)
    .get();

  if (customerSnap.empty) return;

  const customerDoc = customerSnap.docs[0];
  await customerDoc.ref.update({
    paymentMethods: FieldValue.arrayUnion({
      id: paymentMethod.id,
      type: paymentMethod.type,
      last4: pmData.card?.last4 || null,
      brand: pmData.card?.brand || null,
      addedAt: new Date(),
    }),
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log('Payment method attached:', paymentMethod.id);
}

/**
 * Handle payment method detached from customer
 */
async function handlePaymentMethodDetached(paymentMethod: Stripe.PaymentMethod) {
  // Find customer record with this payment method
  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .get();

  for (const doc of customerSnap.docs) {
    const data = doc.data();
    const paymentMethods = data.paymentMethods || [];
    const filtered = paymentMethods.filter((pm: any) => pm.id !== paymentMethod.id);
    
    if (filtered.length !== paymentMethods.length) {
      await doc.ref.update({
        paymentMethods: filtered,
        updatedAt: FieldValue.serverTimestamp(),
      });
      console.log('Payment method detached:', paymentMethod.id);
      break;
    }
  }
}

/**
 * Handle charge refunded
 */
async function handleChargeRefunded(charge: Stripe.Charge) {
  const chargeData = charge as any;
  const paymentIntentId = typeof chargeData.payment_intent === 'string' 
    ? chargeData.payment_intent 
    : chargeData.payment_intent?.id;

  // Find the order/intent by payment intent ID
  const intentSnap = await admin.firestore()
    .collection(CHECKOUT_INTENTS_COLLECTION)
    .where('stripePaymentIntentId', '==', paymentIntentId)
    .limit(1)
    .get();

  if (intentSnap.empty) {
    console.log('No intent found for refunded charge:', charge.id);
    return;
  }

  const intentDoc = intentSnap.docs[0];
  const intent = intentDoc.data();

  await intentDoc.ref.update({
    refundedAt: FieldValue.serverTimestamp(),
    refundAmount: chargeData.amount_refunded,
    refundStatus: charge.refunded ? 'full' : 'partial',
  });

  // Log audit event
  await admin.firestore().collection(AUDIT_COLLECTION).add({
    actorId: 'stripe_webhook',
    actorRole: 'system',
    action: 'stripe.charge.refunded',
    entityType: 'order',
    entityId: intentDoc.id,
    siteId: intent.siteId,
    details: {
      chargeId: charge.id,
      amountRefunded: chargeData.amount_refunded,
      currency: charge.currency,
      refundReason: chargeData.refunds?.data?.[0]?.reason || 'unknown',
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  // Optionally revoke entitlements on full refund
  if (charge.refunded && intent.entitlementId) {
    await admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc(intent.entitlementId).update({
      revokedAt: FieldValue.serverTimestamp(),
      revokeReason: 'refunded',
    });
  }

  console.log('Charge refunded:', charge.id);
}

/**
 * Handle dispute created
 */
async function handleDisputeCreated(dispute: Stripe.Dispute) {
  const disputeData = dispute as any;
  const chargeId = typeof disputeData.charge === 'string' ? disputeData.charge : disputeData.charge?.id;

  await admin.firestore().collection('stripeDisputes').add({
    disputeId: dispute.id,
    chargeId,
    amount: dispute.amount,
    currency: dispute.currency,
    reason: dispute.reason,
    status: dispute.status,
    evidenceDueBy: disputeData.evidence_details?.due_by ? new Date(disputeData.evidence_details.due_by * 1000) : null,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Alert HQ about the dispute
  await admin.firestore().collection(AUDIT_COLLECTION).add({
    actorId: 'stripe_webhook',
    actorRole: 'system',
    action: 'stripe.dispute.created',
    entityType: 'dispute',
    entityId: dispute.id,
    details: {
      chargeId,
      amount: dispute.amount,
      currency: dispute.currency,
      reason: dispute.reason,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Dispute created:', dispute.id, 'reason:', dispute.reason);
}

/**
 * Handle dispute closed
 */
async function handleDisputeClosed(dispute: Stripe.Dispute) {
  const disputeSnap = await admin.firestore()
    .collection('stripeDisputes')
    .where('disputeId', '==', dispute.id)
    .limit(1)
    .get();

  if (disputeSnap.empty) return;

  await disputeSnap.docs[0].ref.update({
    status: dispute.status,
    closedAt: FieldValue.serverTimestamp(),
  });

  // Log outcome
  await admin.firestore().collection(AUDIT_COLLECTION).add({
    actorId: 'stripe_webhook',
    actorRole: 'system',
    action: 'stripe.dispute.closed',
    entityType: 'dispute',
    entityId: dispute.id,
    details: {
      status: dispute.status,
      won: dispute.status === 'won',
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log('Dispute closed:', dispute.id, 'status:', dispute.status);
}

/**
 * Handle customer updated
 */
async function handleCustomerUpdated(customer: Stripe.Customer) {
  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .where('stripeCustomerId', '==', customer.id)
    .limit(1)
    .get();

  if (customerSnap.empty) return;

  const customerDoc = customerSnap.docs[0];
  await customerDoc.ref.update({
    email: customer.email,
    name: customer.name,
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log('Customer updated:', customer.id);
}

/**
 * Handle customer deleted
 */
async function handleCustomerDeleted(customer: Stripe.DeletedCustomer) {
  const customerSnap = await admin.firestore()
    .collection(STRIPE_CUSTOMERS_COLLECTION)
    .where('stripeCustomerId', '==', customer.id)
    .limit(1)
    .get();

  if (customerSnap.empty) return;

  const customerDoc = customerSnap.docs[0];
  await customerDoc.ref.update({
    deleted: true,
    deletedAt: FieldValue.serverTimestamp(),
  });

  console.log('Customer deleted:', customer.id);
}

/**
 * Handle successful checkout session completion
 */
async function handleCheckoutSessionCompleted(session: Stripe.Checkout.Session) {
  const intentId = session.metadata?.firebaseIntentId || session.client_reference_id;
  if (!intentId) {
    console.error('No intent ID in session metadata');
    return;
  }

  const intentSnap = await admin.firestore().collection(CHECKOUT_INTENTS_COLLECTION).doc(intentId).get();
  if (!intentSnap.exists) {
    console.error('Intent not found:', intentId);
    return;
  }

  const intent = intentSnap.data() as any;
  if (intent.status === 'paid') {
    console.log('Intent already paid:', intentId);
    return;
  }

  const productId = intent.productId as ProductId;
  if (!(productId in PRODUCT_CATALOG)) {
    console.error('Unknown product:', productId);
    return;
  }

  const product = PRODUCT_CATALOG[productId];
  const orderRef = admin.firestore().collection(ORDERS_COLLECTION).doc(intentId);
  const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();
  const fulfillmentRef = admin.firestore().collection(FULFILLMENTS_COLLECTION).doc();

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(intentSnap.ref);
    const current = snap.data();
    if (!current || current.status === 'paid') return;

    // Update intent
    tx.set(intentSnap.ref, {
      status: 'paid',
      paidAt: FieldValue.serverTimestamp(),
      entitlementId: entitlementRef.id,
      stripePaymentIntentId: session.payment_intent,
      stripePaymentStatus: session.payment_status,
    }, { merge: true });

    tx.set(orderRef, {
      siteId: current.siteId,
      userId: current.userId,
      productId,
      amount: product.amount,
      currency: product.currency,
      status: 'paid',
      entitlementRoles: product.roles,
      actorId: current.actorId ?? 'stripe_webhook',
      actorRole: current.actorRole ?? 'system',
      listingId: current.listingId ?? null,
      stripeSessionId: session.id,
      stripePaymentIntentId: session.payment_intent,
      createdAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // Create entitlement
    tx.set(entitlementRef, {
      userId: current.userId,
      siteId: current.siteId,
      productId,
      roles: product.roles,
      stripeSessionId: session.id,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (typeof current.listingId === 'string' && current.listingId.trim().length > 0) {
      tx.set(fulfillmentRef, {
        orderId: orderRef.id,
        listingId: current.listingId.trim(),
        userId: current.userId,
        siteId: current.siteId,
        status: 'pending',
        note: 'Awaiting partner fulfillment',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Update user roles
    const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
    tx.set(
      userRef,
      {
        roles: FieldValue.arrayUnion(...product.roles),
        entitlements: FieldValue.arrayUnion(...product.roles),
        siteIds: FieldValue.arrayUnion(current.siteId),
        primarySiteId: current.siteId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // Audit log
    const auditRef = admin.firestore().collection(AUDIT_COLLECTION).doc();
    tx.set(auditRef, {
      actorId: 'stripe_webhook',
      actorRole: 'system',
      action: 'stripe.checkout.completed',
      entityType: 'order',
      entityId: intentId,
      siteId: current.siteId,
      details: {
        productId,
        amount: session.amount_total,
        currency: session.currency,
        roles: product.roles,
        stripeSessionId: session.id,
        stripePaymentIntent: session.payment_intent,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  await persistTelemetryEvent({
    event: 'order.paid',
    userId: intent.actorId ?? 'system',
    role: intent.actorRole as Role | undefined,
    siteId: intent.siteId as string,
    metadata: {
      orderId: orderRef.id,
      productId,
      targetUserId: intent.userId,
      amount: session.amount_total,
      currency: session.currency,
      via: 'stripe_webhook',
      stripeSessionId: session.id,
      ...(
        typeof intent.listingId === 'string' && intent.listingId.trim().length > 0
            ? { listingId: intent.listingId }
            : {}
      ),
    },
  });

  console.log('Checkout completed for intent:', intentId);
}

/**
 * Handle subscription invoice paid
 */
async function handleInvoicePaid(invoice: Stripe.Invoice) {
  const invoiceData = invoice as any;
  const subscriptionId = typeof invoiceData.subscription === 'string' 
    ? invoiceData.subscription 
    : invoiceData.subscription?.id;
  if (!subscriptionId) return;

  const subSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscriptionId)
    .limit(1)
    .get();

  if (subSnap.empty) {
    console.log('No local subscription found for:', subscriptionId);
    return;
  }

  const subDoc = subSnap.docs[0];
  await subDoc.ref.update({
    status: 'active',
    currentPeriodEnd: invoice.period_end ? new Date(invoice.period_end * 1000) : null,
    lastInvoiceId: invoice.id,
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log('Subscription invoice paid:', subscriptionId);
}

/**
 * Handle subscription invoice payment failed
 */
async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  const invoiceData = invoice as any;
  const subscriptionId = typeof invoiceData.subscription === 'string' 
    ? invoiceData.subscription 
    : invoiceData.subscription?.id;
  if (!subscriptionId) return;

  const subSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscriptionId)
    .limit(1)
    .get();

  if (subSnap.empty) return;

  const subDoc = subSnap.docs[0];
  const subData = subDoc.data();
  
  await subDoc.ref.update({
    status: 'past_due',
    lastPaymentError: invoice.last_finalization_error?.message ?? 'Payment failed',
    failedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Send notification to user about failed payment
  if (subData.userId) {
    await admin.firestore().collection(NOTIFICATION_REQUESTS_COLLECTION).add({
      userId: subData.userId,
      type: 'subscription_payment_failed',
      channel: 'email',
      status: 'pending',
      data: {
        subscriptionId: subDoc.id,
        productId: subData.productId,
        amount: invoiceData.amount_due,
        currency: invoiceData.currency,
        invoiceUrl: invoiceData.hosted_invoice_url,
        errorMessage: invoice.last_finalization_error?.message ?? 'Payment failed',
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    // Log audit event for payment failure
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: 'stripe_webhook',
      actorRole: 'system',
      action: 'subscription.payment_failed',
      entityType: 'subscription',
      entityId: subDoc.id,
      siteId: subData.siteId,
      details: {
        stripeSubscriptionId: subscriptionId,
        invoiceId: invoice.id,
        amount: invoiceData.amount_due,
        currency: invoiceData.currency,
        error: invoice.last_finalization_error?.message,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  console.log('Subscription payment failed:', subscriptionId);
}

/**
 * Handle subscription updated
 */
async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const subData = subscription as any;
  const subSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscription.id)
    .limit(1)
    .get();

  if (subSnap.empty) {
    // This might be a new subscription from checkout
    const sessionId = subscription.metadata?.firebaseSubscriptionId;
    if (sessionId) {
      const intentSnap = await admin.firestore().collection(SUBSCRIPTIONS_COLLECTION).doc(sessionId).get();
      if (intentSnap.exists) {
        await intentSnap.ref.update({
          stripeSubscriptionId: subscription.id,
          status: subscription.status,
          currentPeriodEnd: subData.current_period_end ? new Date(subData.current_period_end * 1000) : null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    return;
  }

  const subDoc = subSnap.docs[0];
  await subDoc.ref.update({
    status: subscription.status,
    currentPeriodEnd: subData.current_period_end ? new Date(subData.current_period_end * 1000) : null,
    cancelAtPeriodEnd: subData.cancel_at_period_end,
    updatedAt: FieldValue.serverTimestamp(),
  });

  console.log('Subscription updated:', subscription.id, subscription.status);
}

/**
 * Handle subscription deleted/cancelled
 */
async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  const subSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('stripeSubscriptionId', '==', subscription.id)
    .limit(1)
    .get();

  if (subSnap.empty) return;

  const subDoc = subSnap.docs[0];
  const subData = subDoc.data();

  await subDoc.ref.update({
    status: 'cancelled',
    cancelledAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Optionally revoke entitlements
  if (subData.productId) {
    const product = PRODUCT_CATALOG[subData.productId as ProductId];
    if (product && subData.userId) {
      // Note: In production, you might want to keep entitlements until period end
      console.log('Subscription cancelled for user:', subData.userId);
    }
  }
}

/**
 * Get Stripe Customer Portal URL for managing subscriptions
 */
export const createStripePortalSession = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const returnUrl = typeof request.data?.returnUrl === 'string' ? request.data.returnUrl : '';
  if (!returnUrl) throw new HttpsError('invalid-argument', 'returnUrl is required');

  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(request.auth.uid).get();
  if (!customerSnap.exists) throw new HttpsError('not-found', 'No Stripe customer found');

  const stripeCustomerId = customerSnap.data()?.stripeCustomerId;
  if (!stripeCustomerId) throw new HttpsError('not-found', 'No Stripe customer ID');

  const portalSession = await stripeInstance.billingPortal.sessions.create({
    customer: stripeCustomerId,
    return_url: returnUrl,
  });

  return { url: portalSession.url };
});

/**
 * Get user's active subscriptions
 */
export const getUserSubscriptions = onCall(async (request: CallableRequest) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const userId = typeof request.data?.userId === 'string' ? request.data.userId : request.auth.uid;

  // Only allow viewing own subscriptions unless HQ
  if (userId !== request.auth.uid) {
    await requireHq(request.auth.uid);
  }

  const subsSnap = await admin.firestore()
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('userId', '==', userId)
    .where('status', 'in', ['active', 'trialing', 'past_due'])
    .get();

  const subscriptions = subsSnap.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));

  return { subscriptions };
});

/**
 * Get user's entitlements
 */
export const getUserEntitlements = onCall(async (request: CallableRequest) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const userId = typeof request.data?.userId === 'string' ? request.data.userId : request.auth.uid;

  // Only allow viewing own entitlements unless HQ
  if (userId !== request.auth.uid) {
    await requireHq(request.auth.uid);
  }

  const entSnap = await admin.firestore()
    .collection(ENTITLEMENTS_COLLECTION)
    .where('userId', '==', userId)
    .get();

  const entitlements = entSnap.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));

  return { entitlements };
});

// ============================================================================
// PRODUCTION HEALTH & MAINTENANCE FUNCTIONS
// ============================================================================

/**
 * Health check endpoint for load balancers and monitoring
 */
export const healthCheck = onRequest({ 
  cors: true,
  secrets: [stripeSecretKey],
}, async (_req, res) => {
  try {
    // Check Stripe configuration first since that's the main concern
    const stripeInstance = getStripe();
    let stripeStatus = 'not_configured';
    if (stripeInstance) {
      try {
        // Verify Stripe connectivity with a simple API call
        await stripeInstance.balance.retrieve();
        stripeStatus = 'connected';
      } catch (stripeErr: any) {
        stripeStatus = `error: ${stripeErr.message}`;
      }
    }

    // Try to verify Firestore connectivity (non-critical)
    let firestoreStatus = 'unknown';
    try {
      await admin.firestore().listCollections();
      firestoreStatus = 'ok';
    } catch {
      firestoreStatus = 'limited';
    }
    
    // Verify Auth connectivity (don't fail if user doesn't exist)
    const authStatus = 'ok';
    try {
      await admin.auth().getUser('health-check-dummy');
    } catch {
      // Expected - user doesn't exist, but auth service is working
    }

    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.K_REVISION || 'local',
      services: {
        firestore: firestoreStatus,
        auth: authStatus,
        stripe: stripeStatus,
      },
    });
  } catch (err: any) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: err.message,
    });
  }
});

/**
 * Scheduled job to check for expiring subscriptions and send reminders
 * Runs daily at 9 AM UTC
 */
export const checkExpiringSubscriptions = onSchedule('0 9 * * *', async () => {
  const db = admin.firestore();
  const now = new Date();
  const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // Find subscriptions expiring in the next 7 days
  const expiringSnap = await db
    .collection(SUBSCRIPTIONS_COLLECTION)
    .where('status', '==', 'active')
    .where('currentPeriodEnd', '<=', sevenDaysFromNow)
    .where('currentPeriodEnd', '>', now)
    .get();

  for (const doc of expiringSnap.docs) {
    const sub = doc.data();
    const periodEnd = sub.currentPeriodEnd?.toDate?.() ?? sub.currentPeriodEnd;
    if (!periodEnd || !sub.userId) continue;

    const daysUntilExpiry = Math.ceil((periodEnd.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));
    
    // Check if we already sent a reminder for this period
    const existingReminder = await db
      .collection(NOTIFICATION_REQUESTS_COLLECTION)
      .where('userId', '==', sub.userId)
      .where('type', '==', 'subscription_expiring')
      .where('data.subscriptionId', '==', doc.id)
      .where('createdAt', '>', new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000))
      .limit(1)
      .get();

    if (!existingReminder.empty) continue;

    // Send reminder at 7 days and 3 days before expiry
    if (daysUntilExpiry <= 3 || daysUntilExpiry === 7) {
      await db.collection(NOTIFICATION_REQUESTS_COLLECTION).add({
        userId: sub.userId,
        type: 'subscription_expiring',
        channel: 'email',
        status: 'pending',
        data: {
          subscriptionId: doc.id,
          productId: sub.productId,
          expiresAt: periodEnd,
          daysUntilExpiry,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      console.log(`Sent expiring subscription reminder to user ${sub.userId}, expires in ${daysUntilExpiry} days`);
    }
  }
});

/**
 * Scheduled job to archive old telemetry data (older than 90 days)
 * Runs weekly on Sundays at 3 AM UTC
 */
export const archiveOldTelemetry = onSchedule('0 3 * * 0', async () => {
  const db = admin.firestore();
  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

  // Get old telemetry events
  const oldEventsSnap = await db
    .collection(TELEMETRY_COLLECTION)
    .where('timestamp', '<', ninetyDaysAgo)
    .limit(500)
    .get();

  if (oldEventsSnap.empty) {
    console.log('No old telemetry events to archive');
    return;
  }

  const batch = db.batch();
  let count = 0;

  for (const doc of oldEventsSnap.docs) {
    // Move to archive collection
    const archiveRef = db.collection('telemetryArchive').doc(doc.id);
    batch.set(archiveRef, {
      ...doc.data(),
      archivedAt: FieldValue.serverTimestamp(),
    });
    batch.delete(doc.ref);
    count++;
  }

  await batch.commit();
  console.log(`Archived ${count} telemetry events`);
});

/**
 * Scheduled job to clean up expired checkout intents (older than 24 hours)
 * Runs every 6 hours
 */
export const cleanupExpiredIntents = onSchedule('0 */6 * * *', async () => {
  const db = admin.firestore();
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const expiredIntentsSnap = await db
    .collection(CHECKOUT_INTENTS_COLLECTION)
    .where('status', '==', 'intent')
    .where('createdAt', '<', oneDayAgo)
    .limit(100)
    .get();

  if (expiredIntentsSnap.empty) {
    console.log('No expired checkout intents to clean up');
    return;
  }

  const batch = db.batch();
  let count = 0;

  for (const doc of expiredIntentsSnap.docs) {
    batch.update(doc.ref, {
      status: 'expired',
      expiredAt: FieldValue.serverTimestamp(),
    });
    count++;
  }

  await batch.commit();
  console.log(`Marked ${count} checkout intents as expired`);
});

/**
 * Cancel a subscription (user-initiated)
 */
export const cancelSubscription = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const subscriptionId = typeof request.data?.subscriptionId === 'string' ? request.data.subscriptionId : '';
  const cancelAtPeriodEnd = request.data?.cancelAtPeriodEnd !== false; // Default to cancel at period end

  if (!subscriptionId) throw new HttpsError('invalid-argument', 'subscriptionId is required');

  // Get the subscription from Firestore
  const subSnap = await admin.firestore().collection(SUBSCRIPTIONS_COLLECTION).doc(subscriptionId).get();
  if (!subSnap.exists) throw new HttpsError('not-found', 'Subscription not found');

  const sub = subSnap.data() as any;
  
  // Verify user owns this subscription or is HQ
  if (sub.userId !== request.auth.uid) {
    await requireHq(request.auth.uid);
  }

  if (!sub.stripeSubscriptionId) {
    throw new HttpsError('failed-precondition', 'No Stripe subscription linked');
  }

  try {
    // Cancel in Stripe
    const stripeSubscription = await stripeInstance.subscriptions.update(sub.stripeSubscriptionId, {
      cancel_at_period_end: cancelAtPeriodEnd,
    });

    // Update local record
    await subSnap.ref.update({
      cancelAtPeriodEnd,
      cancelledAt: cancelAtPeriodEnd ? null : FieldValue.serverTimestamp(),
      status: cancelAtPeriodEnd ? 'active' : 'cancelled',
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth.uid,
      actorRole: sub.userId === request.auth.uid ? 'user' : 'hq',
      action: cancelAtPeriodEnd ? 'subscription.scheduled_cancel' : 'subscription.cancelled',
      entityType: 'subscription',
      entityId: subscriptionId,
      siteId: sub.siteId,
      details: {
        stripeSubscriptionId: sub.stripeSubscriptionId,
        cancelAtPeriodEnd,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      cancelAtPeriodEnd,
      currentPeriodEnd: stripeSubscription.items?.data?.[0]?.current_period_end
        ? new Date(stripeSubscription.items.data[0].current_period_end * 1000).toISOString()
        : null,
    };
  } catch (err: any) {
    console.error('Error cancelling subscription:', err);
    throw new HttpsError('internal', err.message || 'Failed to cancel subscription');
  }
});

/**
 * Resume a cancelled subscription (if cancelled with cancel_at_period_end)
 */
export const resumeSubscription = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const subscriptionId = typeof request.data?.subscriptionId === 'string' ? request.data.subscriptionId : '';
  if (!subscriptionId) throw new HttpsError('invalid-argument', 'subscriptionId is required');

  const subSnap = await admin.firestore().collection(SUBSCRIPTIONS_COLLECTION).doc(subscriptionId).get();
  if (!subSnap.exists) throw new HttpsError('not-found', 'Subscription not found');

  const sub = subSnap.data() as any;

  if (sub.userId !== request.auth.uid) {
    await requireHq(request.auth.uid);
  }

  if (!sub.stripeSubscriptionId) {
    throw new HttpsError('failed-precondition', 'No Stripe subscription linked');
  }

  if (!sub.cancelAtPeriodEnd) {
    throw new HttpsError('failed-precondition', 'Subscription is not scheduled for cancellation');
  }

  try {
    await stripeInstance.subscriptions.update(sub.stripeSubscriptionId, {
      cancel_at_period_end: false,
    });

    await subSnap.ref.update({
      cancelAtPeriodEnd: false,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth.uid,
      actorRole: sub.userId === request.auth.uid ? 'user' : 'hq',
      action: 'subscription.resumed',
      entityType: 'subscription',
      entityId: subscriptionId,
      siteId: sub.siteId,
      details: { stripeSubscriptionId: sub.stripeSubscriptionId },
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (err: any) {
    console.error('Error resuming subscription:', err);
    throw new HttpsError('internal', err.message || 'Failed to resume subscription');
  }
});

/**
 * Update payment method for a subscription
 */
export const updateSubscriptionPaymentMethod = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const paymentMethodId = typeof request.data?.paymentMethodId === 'string' ? request.data.paymentMethodId : '';
  if (!paymentMethodId) throw new HttpsError('invalid-argument', 'paymentMethodId is required');

  // Get user's Stripe customer
  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(request.auth.uid).get();
  if (!customerSnap.exists) throw new HttpsError('not-found', 'No Stripe customer found');

  const customerId = customerSnap.data()?.stripeCustomerId;
  if (!customerId) throw new HttpsError('not-found', 'No Stripe customer ID');

  try {
    // Attach payment method to customer
    await stripeInstance.paymentMethods.attach(paymentMethodId, { customer: customerId });

    // Set as default payment method
    await stripeInstance.customers.update(customerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });

    return { success: true };
  } catch (err: any) {
    console.error('Error updating payment method:', err);
    throw new HttpsError('internal', err.message || 'Failed to update payment method');
  }
});

/**
 * Get invoice history for a user
 */
export const getInvoiceHistory = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const userId = typeof request.data?.userId === 'string' ? request.data.userId : request.auth.uid;

  if (userId !== request.auth.uid) {
    await requireHq(request.auth.uid);
  }

  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(userId).get();
  if (!customerSnap.exists) return { invoices: [] };

  const customerId = customerSnap.data()?.stripeCustomerId;
  if (!customerId) return { invoices: [] };

  try {
    const invoices = await stripeInstance.invoices.list({
      customer: customerId,
      limit: 50,
    });

    return {
      invoices: invoices.data.map(inv => ({
        id: inv.id,
        number: inv.number,
        status: inv.status,
        amount: inv.amount_paid,
        currency: inv.currency,
        created: inv.created ? new Date(inv.created * 1000).toISOString() : null,
        hostedInvoiceUrl: inv.hosted_invoice_url,
        invoicePdf: inv.invoice_pdf,
      })),
    };
  } catch (err: any) {
    console.error('Error fetching invoices:', err);
    throw new HttpsError('internal', err.message || 'Failed to fetch invoices');
  }
});

/**
 * Retry a failed invoice payment
 */
export const retryInvoicePayment = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  const stripeInstance = getStripe();
  if (!stripeInstance) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const invoiceId = typeof request.data?.invoiceId === 'string' ? request.data.invoiceId : '';
  if (!invoiceId) throw new HttpsError('invalid-argument', 'invoiceId is required');

  // Verify user owns this invoice
  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(request.auth.uid).get();
  if (!customerSnap.exists) throw new HttpsError('not-found', 'No Stripe customer found');

  const customerId = customerSnap.data()?.stripeCustomerId;

  try {
    const invoice = await stripeInstance.invoices.retrieve(invoiceId);
    
    if (invoice.customer !== customerId) {
      await requireHq(request.auth.uid);
    }

    if (invoice.status !== 'open') {
      throw new HttpsError('failed-precondition', 'Invoice is not payable');
    }

    const paidInvoice = await stripeInstance.invoices.pay(invoiceId);

    return {
      success: true,
      status: paidInvoice.status,
      amountPaid: paidInvoice.amount_paid,
    };
  } catch (err: any) {
    console.error('Error retrying payment:', err);
    throw new HttpsError('internal', err.message || 'Failed to retry payment');
  }
});

/**
 * Monitor webhook failures - runs daily at 9 AM UTC
 * Checks for failed webhook events and alerts admins
 */
export const monitorWebhookHealth = onSchedule('0 9 * * *', async () => {
  const oneDayAgo = new Date();
  oneDayAgo.setDate(oneDayAgo.getDate() - 1);

  // Get recent webhook logs
  const logsSnap = await admin.firestore()
    .collection('stripeWebhookLogs')
    .where('timestamp', '>=', Timestamp.fromDate(oneDayAgo))
    .get();

  const logs = logsSnap.docs.map(doc => doc.data());
  const failedEvents = logs.filter(log => log.status === 'error' || log.status === 'failed');
  const successfulEvents = logs.filter(log => log.status === 'success' || log.status === 'processed');

  const summary = {
    totalEvents: logs.length,
    successfulEvents: successfulEvents.length,
    failedEvents: failedEvents.length,
    successRate: logs.length > 0 
      ? ((successfulEvents.length / logs.length) * 100).toFixed(2) + '%'
      : 'N/A',
    failuresByType: failedEvents.reduce((acc: Record<string, number>, log) => {
      acc[log.eventType || 'unknown'] = (acc[log.eventType || 'unknown'] || 0) + 1;
      return acc;
    }, {}),
  };

  // Log to audit for tracking
  await admin.firestore().collection(AUDIT_COLLECTION).add({
    actorId: 'system',
    actorRole: 'system',
    action: 'webhook.health.report',
    entityType: 'system',
    entityId: 'stripe-webhooks',
    details: summary,
    createdAt: FieldValue.serverTimestamp(),
  });

  // If failure rate is high, create an alert
  if (failedEvents.length > 0 && (failedEvents.length / logs.length) > 0.1) {
    await admin.firestore().collection('alerts').add({
      type: 'webhook_failures',
      severity: 'high',
      title: 'High Stripe Webhook Failure Rate',
      message: `${failedEvents.length} of ${logs.length} webhook events failed in the last 24 hours`,
      details: summary,
      acknowledged: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  console.log('Webhook health report:', JSON.stringify(summary));
});

/**
 * Process refund requests - callable by HQ only
 */
export const processRefund = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  paymentIntentId: string;
  amount?: number;
  reason?: string;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { paymentIntentId, amount, reason } = request.data;

  if (!paymentIntentId) {
    throw new HttpsError('invalid-argument', 'paymentIntentId is required');
  }

  try {
    // Create the refund
    const refundParams: Stripe.RefundCreateParams = {
      payment_intent: paymentIntentId,
      reason: (reason as Stripe.RefundCreateParams.Reason) || 'requested_by_customer',
    };

    if (amount) {
      refundParams.amount = amount; // Amount in cents
    }

    const refund = await stripeInstance.refunds.create(refundParams);

    // Log the refund
    await admin.firestore().collection('refunds').add({
      stripeRefundId: refund.id,
      paymentIntentId,
      amount: refund.amount,
      currency: refund.currency,
      status: refund.status,
      reason: reason || 'requested_by_customer',
      processedBy: request.auth!.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'refund.processed',
      entityType: 'payment',
      entityId: paymentIntentId,
      details: {
        refundId: refund.id,
        amount: refund.amount,
        reason,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      refundId: refund.id,
      status: refund.status,
      amount: refund.amount,
    };
  } catch (err: any) {
    console.error('Error processing refund:', err);
    throw new HttpsError('internal', err.message || 'Failed to process refund');
  }
});

/**
 * Get webhook logs for monitoring dashboard - HQ only
 */
export const getWebhookLogs = onCall(async (request: CallableRequest<{
  limit?: number;
  status?: string;
  eventType?: string;
}>) => {
  await requireHq(request.auth?.uid);

  const { limit = 50, status, eventType } = request.data;

  let query = admin.firestore()
    .collection('stripeWebhookLogs')
    .orderBy('timestamp', 'desc')
    .limit(limit);

  if (status) {
    query = query.where('status', '==', status);
  }

  if (eventType) {
    query = query.where('eventType', '==', eventType);
  }

  const snapshot = await query.get();
  const logs = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate?.()?.toISOString(),
  }));

  return { logs };
});

/**
 * Get Stripe dashboard metrics - HQ only
 */
export const getStripeMetrics = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  try {
    // Get subscription counts
    const subscriptionsSnap = await admin.firestore()
      .collection(SUBSCRIPTIONS_COLLECTION)
      .get();

    const subscriptions = subscriptionsSnap.docs.map(doc => doc.data());
    
    const metrics = {
      totalSubscriptions: subscriptions.length,
      activeSubscriptions: subscriptions.filter(s => s.status === 'active').length,
      trialingSubscriptions: subscriptions.filter(s => s.status === 'trialing').length,
      canceledSubscriptions: subscriptions.filter(s => s.status === 'cancelled').length,
      pendingCancellations: subscriptions.filter(s => s.cancelAtPeriodEnd).length,
      byProduct: subscriptions.reduce((acc: Record<string, number>, s) => {
        acc[s.productId || 'unknown'] = (acc[s.productId || 'unknown'] || 0) + 1;
        return acc;
      }, {}),
    };

    // Get recent revenue from Stripe (last 30 days)
    const thirtyDaysAgo = Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60);
    const charges = await stripeInstance.charges.list({
      created: { gte: thirtyDaysAgo },
      limit: 100,
    });

    const revenue = charges.data
      .filter(c => c.paid && !c.refunded)
      .reduce((sum, c) => sum + c.amount, 0);

    return {
      ...metrics,
      last30DaysRevenue: revenue,
      last30DaysRevenueFormatted: `$${(revenue / 100).toFixed(2)}`,
    };
  } catch (err: any) {
    console.error('Error getting Stripe metrics:', err);
    throw new HttpsError('internal', err.message || 'Failed to get metrics');
  }
});

/**
 * Get all Stripe products and prices - HQ only
 */
export const getStripeProducts = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  try {
    // Get all products
    const products = await stripeInstance.products.list({
      limit: 100,
      active: undefined, // Get both active and inactive
    });

    // Get all prices
    const prices = await stripeInstance.prices.list({
      limit: 100,
      active: undefined,
    });

    // Map prices to products
    const productsWithPrices = products.data.map(product => {
      const productPrices = prices.data.filter(p => p.product === product.id);
      return {
        id: product.id,
        name: product.name,
        description: product.description,
        active: product.active,
        metadata: product.metadata,
        images: product.images,
        created: product.created,
        updated: product.updated,
        prices: productPrices.map(price => ({
          id: price.id,
          active: price.active,
          currency: price.currency,
          unitAmount: price.unit_amount,
          unitAmountFormatted: price.unit_amount 
            ? `$${(price.unit_amount / 100).toFixed(2)}`
            : 'Free',
          recurring: price.recurring ? {
            interval: price.recurring.interval,
            intervalCount: price.recurring.interval_count,
          } : null,
          type: price.type,
          nickname: price.nickname,
          metadata: price.metadata,
        })),
      };
    });

    return { products: productsWithPrices };
  } catch (err: any) {
    console.error('Error getting Stripe products:', err);
    throw new HttpsError('internal', err.message || 'Failed to get products');
  }
});

/**
 * Create a new Stripe product - HQ only
 */
export const createStripeProduct = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  name: string;
  description?: string;
  metadata?: Record<string, string>;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { name, description, metadata } = request.data;

  if (!name) {
    throw new HttpsError('invalid-argument', 'Product name is required');
  }

  try {
    const product = await stripeInstance.products.create({
      name,
      description: description || undefined,
      metadata: metadata || undefined,
    });

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'stripe.product.created',
      entityType: 'stripeProduct',
      entityId: product.id,
      details: { name, description },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      product: {
        id: product.id,
        name: product.name,
        description: product.description,
        active: product.active,
      },
    };
  } catch (err: any) {
    console.error('Error creating Stripe product:', err);
    throw new HttpsError('internal', err.message || 'Failed to create product');
  }
});

/**
 * Update a Stripe product - HQ only
 */
export const updateStripeProduct = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  productId: string;
  name?: string;
  description?: string;
  active?: boolean;
  metadata?: Record<string, string>;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { productId, name, description, active, metadata } = request.data;

  if (!productId) {
    throw new HttpsError('invalid-argument', 'Product ID is required');
  }

  try {
    const updateParams: Stripe.ProductUpdateParams = {};
    if (name !== undefined) updateParams.name = name;
    if (description !== undefined) updateParams.description = description;
    if (active !== undefined) updateParams.active = active;
    if (metadata !== undefined) updateParams.metadata = metadata;

    const product = await stripeInstance.products.update(productId, updateParams);

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'stripe.product.updated',
      entityType: 'stripeProduct',
      entityId: productId,
      details: updateParams,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      product: {
        id: product.id,
        name: product.name,
        description: product.description,
        active: product.active,
      },
    };
  } catch (err: any) {
    console.error('Error updating Stripe product:', err);
    throw new HttpsError('internal', err.message || 'Failed to update product');
  }
});

/**
 * Create a new price for a product - HQ only
 */
export const createStripePrice = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  productId: string;
  unitAmount: number;
  currency?: string;
  recurring?: {
    interval: 'day' | 'week' | 'month' | 'year';
    intervalCount?: number;
  };
  nickname?: string;
  metadata?: Record<string, string>;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { productId, unitAmount, currency = 'usd', recurring, nickname, metadata } = request.data;

  if (!productId) {
    throw new HttpsError('invalid-argument', 'Product ID is required');
  }

  if (unitAmount === undefined || unitAmount < 0) {
    throw new HttpsError('invalid-argument', 'Valid unit amount is required (in cents)');
  }

  try {
    const priceParams: Stripe.PriceCreateParams = {
      product: productId,
      unit_amount: unitAmount,
      currency,
      nickname: nickname || undefined,
      metadata: metadata || undefined,
    };

    if (recurring) {
      priceParams.recurring = {
        interval: recurring.interval,
        interval_count: recurring.intervalCount || 1,
      };
    }

    const price = await stripeInstance.prices.create(priceParams);

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'stripe.price.created',
      entityType: 'stripePrice',
      entityId: price.id,
      details: { productId, unitAmount, currency, recurring, nickname },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      price: {
        id: price.id,
        active: price.active,
        unitAmount: price.unit_amount,
        currency: price.currency,
        recurring: price.recurring,
        nickname: price.nickname,
      },
    };
  } catch (err: any) {
    console.error('Error creating Stripe price:', err);
    throw new HttpsError('internal', err.message || 'Failed to create price');
  }
});

/**
 * Update a price (can only deactivate, cannot change amount) - HQ only
 */
export const updateStripePrice = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  priceId: string;
  active?: boolean;
  nickname?: string;
  metadata?: Record<string, string>;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { priceId, active, nickname, metadata } = request.data;

  if (!priceId) {
    throw new HttpsError('invalid-argument', 'Price ID is required');
  }

  try {
    const updateParams: Stripe.PriceUpdateParams = {};
    if (active !== undefined) updateParams.active = active;
    if (nickname !== undefined) updateParams.nickname = nickname;
    if (metadata !== undefined) updateParams.metadata = metadata;

    const price = await stripeInstance.prices.update(priceId, updateParams);

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'stripe.price.updated',
      entityType: 'stripePrice',
      entityId: priceId,
      details: updateParams,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      price: {
        id: price.id,
        active: price.active,
        unitAmount: price.unit_amount,
        currency: price.currency,
        nickname: price.nickname,
      },
    };
  } catch (err: any) {
    console.error('Error updating Stripe price:', err);
    throw new HttpsError('internal', err.message || 'Failed to update price');
  }
});

/**
 * Archive (deactivate) a Stripe product - HQ only
 */
export const archiveStripeProduct = onCall({
  secrets: [stripeSecretKey],
}, async (request: CallableRequest<{
  productId: string;
}>) => {
  await requireHq(request.auth?.uid);

  const stripeInstance = getStripe();
  if (!stripeInstance) {
    throw new HttpsError('unavailable', 'Stripe is not configured');
  }

  const { productId } = request.data;

  if (!productId) {
    throw new HttpsError('invalid-argument', 'Product ID is required');
  }

  try {
    // First deactivate all prices for this product
    const prices = await stripeInstance.prices.list({
      product: productId,
      active: true,
    });

    for (const price of prices.data) {
      await stripeInstance.prices.update(price.id, { active: false });
    }

    // Then deactivate the product
    const product = await stripeInstance.products.update(productId, { active: false });

    // Audit log
    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth!.uid,
      actorRole: 'hq',
      action: 'stripe.product.archived',
      entityType: 'stripeProduct',
      entityId: productId,
      details: { pricesArchived: prices.data.length },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      product: {
        id: product.id,
        name: product.name,
        active: product.active,
      },
      pricesArchived: prices.data.length,
    };
  } catch (err: any) {
    console.error('Error archiving Stripe product:', err);
    throw new HttpsError('internal', err.message || 'Failed to archive product');
  }
});

// ============================================================================
// MOTIVATION & PERSONALIZATION ENGINE
// ============================================================================

// Motivation types and their characteristics
type MotivationType = 'achievement' | 'social' | 'mastery' | 'autonomy' | 'purpose' | 'competition' | 'creativity';
type EngagementLevel = 'thriving' | 'engaged' | 'coasting' | 'struggling' | 'at-risk';

const MOTIVATION_COLLECTIONS = {
  EDUCATOR_FEEDBACK: 'educatorFeedback',
  MOTIVATION_PROFILES: 'learnerMotivationProfiles',
  LEARNER_INTERACTIONS: 'learnerInteractions',
  SUPPORT_INTERVENTIONS: 'supportInterventions',
  MOTIVATION_NUDGES: 'motivationNudges',
  MOTIVATION_CONFIG: 'configs',
};

/**
 * Submit educator feedback about a learner's engagement and motivation
 */
export const submitEducatorFeedback = onCall(async (request: CallableRequest<{
  learnerId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  engagementLevel: 1 | 2 | 3 | 4 | 5;
  participationType: 'leader' | 'active' | 'quiet' | 'observer' | 'reluctant';
  respondedWellTo: MotivationType[];
  struggledWith?: string;
  effectiveStrategies?: Array<{ type: MotivationType; strategy: string }>;
  notes?: string;
  highlights?: string[];
}>) => {
  const { uid, role } = await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const {
    learnerId,
    siteId,
    sessionOccurrenceId,
    engagementLevel,
    participationType,
    respondedWellTo,
    struggledWith,
    effectiveStrategies,
    notes,
    highlights,
  } = request.data;

  if (!learnerId || !siteId || !engagementLevel || !participationType) {
    throw new HttpsError('invalid-argument', 'Missing required fields');
  }

  // Create the feedback document
  const feedbackRef = await admin.firestore().collection(MOTIVATION_COLLECTIONS.EDUCATOR_FEEDBACK).add({
    learnerId,
    educatorId: uid,
    siteId,
    sessionOccurrenceId: sessionOccurrenceId || null,
    engagementLevel,
    participationType,
    respondedWellTo: respondedWellTo || [],
    struggledWith: struggledWith || null,
    effectiveStrategies: (effectiveStrategies || []).map(s => ({
      type: s.type,
      strategy: s.strategy,
      effectiveness: 0.5, // Default, will be updated based on outcomes
      usageCount: 1,
    })),
    notes: notes || null,
    highlights: highlights || [],
    createdAt: FieldValue.serverTimestamp(),
  });

  // Log telemetry
  await persistTelemetryEvent({
    event: 'educator.feedback.submitted',
    userId: uid,
    role,
    siteId,
    metadata: { learnerId, feedbackId: feedbackRef.id },
  });

  // Trigger async profile update
  await updateLearnerMotivationProfile(learnerId, siteId);

  return { success: true, feedbackId: feedbackRef.id };
});

/**
 * Log a support intervention and its outcome
 */
export const logSupportIntervention = onCall(async (request: CallableRequest<{
  learnerId: string;
  siteId: string;
  sessionOccurrenceId?: string;
  strategyType: MotivationType;
  strategyDescription: string;
  context: 'group' | 'individual' | 'peer-supported';
  triggerReason?: string;
  outcome: 'helped' | 'partial' | 'no-change' | 'backfired';
  learnerResponse?: 'positive' | 'neutral' | 'resistant';
  notes?: string;
  recommendForFuture: boolean;
}>) => {
  const { uid, role } = await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const {
    learnerId,
    siteId,
    sessionOccurrenceId,
    strategyType,
    strategyDescription,
    context,
    triggerReason,
    outcome,
    learnerResponse,
    notes,
    recommendForFuture,
  } = request.data;

  if (!learnerId || !siteId || !strategyType || !strategyDescription || !context || !outcome) {
    throw new HttpsError('invalid-argument', 'Missing required fields');
  }

  const interventionRef = await admin.firestore().collection(MOTIVATION_COLLECTIONS.SUPPORT_INTERVENTIONS).add({
    learnerId,
    educatorId: uid,
    siteId,
    sessionOccurrenceId: sessionOccurrenceId || null,
    strategyType,
    strategyDescription,
    context,
    triggerReason: triggerReason || null,
    outcome,
    learnerResponse: learnerResponse || null,
    notes: notes || null,
    recommendForFuture,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Update effectiveness score in motivation profile
  if (outcome !== 'no-change') {
    await updateStrategyEffectiveness(learnerId, strategyType, outcome);
  }

  // Log telemetry
  await persistTelemetryEvent({
    event: 'support.applied',
    userId: uid,
    role,
    siteId,
    metadata: {
      learnerId,
      interventionId: interventionRef.id,
      strategyType,
      context,
    },
  });

  await persistTelemetryEvent({
    event: 'support.intervention.logged',
    userId: uid,
    role,
    siteId,
    metadata: {
      learnerId,
      interventionId: interventionRef.id,
      outcome,
      strategyType,
      context,
    },
  });

  await persistTelemetryEvent({
    event: 'support.outcome.logged',
    userId: uid,
    role,
    siteId,
    metadata: {
      learnerId,
      interventionId: interventionRef.id,
      outcome,
      learnerResponse: learnerResponse || null,
      recommendForFuture,
    },
  });

  return { success: true, interventionId: interventionRef.id };
});

/**
 * Track learner interaction with the app
 */
export const trackLearnerInteraction = onCall(async (request: CallableRequest<{
  eventType: string;
  siteId: string;
  metadata?: {
    durationSeconds?: number;
    missionId?: string;
    pillarCode?: string;
    difficultyLevel?: string;
    timeToComplete?: number;
    helpType?: string;
    nudgeType?: string;
  };
}>) => {
  const eventType = typeof request.data?.eventType === 'string' ? request.data.eventType.trim() : '';
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const metadata = request.data?.metadata;

  if (!eventType || !siteId) {
    throw new HttpsError('invalid-argument', 'eventType and siteId are required');
  }

  const { uid, role } = await requireRoleAndSite(
    request.auth?.uid,
    ['learner', 'educator', 'parent', 'site', 'partner', 'hq'],
    siteId,
  );

  // Validate event type
  const validEvents = [
    'app.open', 'app.session.end', 'mission.started', 'mission.completed',
    'mission.abandoned', 'reflection.submitted', 'portfolio.item.added',
    'help.requested', 'badge.viewed', 'leaderboard.viewed', 'streak.celebrated',
    'popup.shown', 'popup.dismissed', 'popup.completed',
    'nudge.accepted', 'nudge.dismissed', 'nudge.snoozed',
  ];

  if (!validEvents.includes(eventType)) {
    throw new HttpsError('invalid-argument', `Invalid event type: ${eventType}`);
  }

  // Store interaction
  await admin.firestore().collection(MOTIVATION_COLLECTIONS.LEARNER_INTERACTIONS).add({
    learnerId: uid,
    siteId,
    eventType,
    metadata: metadata || {},
    timestamp: FieldValue.serverTimestamp(),
  });

  // Also log to general telemetry
  await persistTelemetryEvent({
    event: eventType,
    userId: uid,
    role,
    siteId,
    metadata,
  });

  return { success: true };
});

/**
 * Get learner's motivation profile
 */
export const getLearnerMotivationProfile = onCall(async (request: CallableRequest<{
  learnerId: string;
  siteId: string;
}>) => {
  const { uid, role } = await requireRoleAndSite(
    request.auth?.uid, 
    ['learner', 'educator', 'parent', 'hq'], 
    request.data.siteId
  );

  const { learnerId, siteId } = request.data;

  // Learners can only view their own profile, educators/parents can view their assigned learners
  if (role === 'learner' && uid !== learnerId) {
    throw new HttpsError('permission-denied', 'Cannot view other learner profiles');
  }

  // Try to get existing profile
  const profileQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .limit(1)
    .get();

  if (profileQuery.empty) {
    // Create initial profile
    const newProfile = await createInitialMotivationProfile(learnerId, siteId);
    return newProfile;
  }

  const profile = profileQuery.docs[0].data();
  return { id: profileQuery.docs[0].id, ...profile };
});

/**
 * Get personalized motivation nudges for a learner
 */
export const getLearnerNudges = onCall(async (request: CallableRequest<{
  siteId: string;
  limit?: number;
}>) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const { siteId, limit: nudgeLimit } = request.data;
  const maxNudges = Math.min(nudgeLimit || 5, 10);

  // Get pending nudges for this learner
  const nudgesQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_NUDGES)
    .where('learnerId', '==', auth.uid)
    .where('siteId', '==', siteId)
    .where('status', '==', 'pending')
    .orderBy('priority', 'desc')
    .orderBy('createdAt', 'desc')
    .limit(maxNudges)
    .get();

  const nudges = nudgesQuery.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));

  return { nudges };
});

/**
 * Respond to a motivation nudge
 */
export const respondToNudge = onCall(async (request: CallableRequest<{
  nudgeId: string;
  response: 'accepted' | 'dismissed' | 'snoozed';
  snoozeDurationMinutes?: number;
}>) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const { nudgeId, response, snoozeDurationMinutes } = request.data;

  if (!nudgeId || !response) {
    throw new HttpsError('invalid-argument', 'nudgeId and response are required');
  }

  const nudgeRef = admin.firestore().collection(MOTIVATION_COLLECTIONS.MOTIVATION_NUDGES).doc(nudgeId);
  const nudgeDoc = await nudgeRef.get();

  if (!nudgeDoc.exists) {
    throw new HttpsError('not-found', 'Nudge not found');
  }

  const nudgeData = nudgeDoc.data()!;

  // Verify ownership
  if (nudgeData.learnerId !== auth.uid) {
    throw new HttpsError('permission-denied', 'Cannot respond to nudges for other learners');
  }

  // Update nudge status
  const updateData: Record<string, any> = {
    status: response === 'snoozed' ? 'pending' : response,
    respondedAt: FieldValue.serverTimestamp(),
  };

  if (response === 'snoozed' && snoozeDurationMinutes) {
    updateData.scheduledFor = Timestamp.fromMillis(
      Date.now() + snoozeDurationMinutes * 60 * 1000
    );
  }

  await nudgeRef.update(updateData);

  // Track response
  await admin.firestore().collection(MOTIVATION_COLLECTIONS.LEARNER_INTERACTIONS).add({
    learnerId: auth.uid,
    siteId: nudgeData.siteId,
    eventType: `nudge.${response}`,
    metadata: {
      nudgeId,
      nudgeType: nudgeData.type,
      motivationType: nudgeData.motivationTypeTarget,
    },
    timestamp: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Compute motivation signals for a learner (scheduled function or manual trigger)
 */
export const computeMotivationSignals = onCall(async (request: CallableRequest<{
  learnerId: string;
  siteId: string;
}>) => {
  await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const { learnerId, siteId } = request.data;
  await updateLearnerMotivationProfile(learnerId, siteId);

  return { success: true };
});

/**
 * Generate personalized nudges for learners (scheduled function)
 */
export const generateMotivationNudges = onCall(async (request: CallableRequest<{
  siteId: string;
  learnerIds?: string[];
}>) => {
  await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const { siteId, learnerIds } = request.data;

  // Get learners to process
  const learnersQuery: FirebaseFirestore.Query = admin.firestore()
    .collection(USERS_COLLECTION)
    .where('role', '==', 'learner')
    .where('siteIds', 'array-contains', siteId);

  if (learnerIds && learnerIds.length > 0) {
    // Process specific learners only
    const batch = learnerIds.slice(0, 10); // Limit batch size
    for (const learnerId of batch) {
      await generateNudgesForLearner(learnerId, siteId);
    }
    return { success: true, processedCount: batch.length };
  }

  // Process all learners at the site
  const learnersSnap = await learnersQuery.limit(100).get();
  let processed = 0;

  for (const learnerDoc of learnersSnap.docs) {
    try {
      await generateNudgesForLearner(learnerDoc.id, siteId);
      processed++;
    } catch (err) {
      console.error(`Error generating nudges for learner ${learnerDoc.id}:`, err);
    }
  }

  return { success: true, processedCount: processed };
});

/**
 * Get educator insights for a class/session
 */
export const getClassInsights = onCall(async (request: CallableRequest<{
  siteId: string;
  sessionOccurrenceId?: string;
  learnerIds?: string[];
}>) => {
  const { uid, role } = await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const { siteId, learnerIds } = request.data;

  // Build query for motivation profiles
  let profilesQuery: FirebaseFirestore.Query = admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .where('siteId', '==', siteId);

  if (learnerIds && learnerIds.length > 0) {
    // Note: Firestore 'in' limited to 10
    const limitedIds = learnerIds.slice(0, 10);
    profilesQuery = profilesQuery.where('learnerId', 'in', limitedIds);
  }

  const profilesSnap = await profilesQuery.limit(30).get();

  // Build insights summary
  const insights: Array<{
    learnerId: string;
    currentEngagement: EngagementLevel;
    primaryMotivators: MotivationType[];
    suggestedStrategies: Array<{ type: MotivationType; strategy: string }>;
    recentHighlights?: string[];
    needsAttention: boolean;
  }> = [];

  for (const doc of profilesSnap.docs) {
    const profile = doc.data();

    // Get recent educator feedback for highlights
    const recentFeedback = await admin.firestore()
      .collection(MOTIVATION_COLLECTIONS.EDUCATOR_FEEDBACK)
      .where('learnerId', '==', profile.learnerId)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    const highlights = recentFeedback.empty 
      ? [] 
      : (recentFeedback.docs[0].data().highlights || []);

    // Determine if needs attention
    const needsAttention = ['struggling', 'at-risk'].includes(profile.currentEngagement) ||
      profile.engagementTrend === 'declining';

    // Get top effective strategies
    const suggestedStrategies = (profile.effectiveStrategies || [])
      .filter((s: any) => s.effectiveness > 0.5)
      .slice(0, 3)
      .map((s: any) => ({ type: s.type, strategy: s.strategy }));

    insights.push({
      learnerId: profile.learnerId,
      currentEngagement: profile.currentEngagement,
      primaryMotivators: profile.primaryMotivators || [],
      suggestedStrategies,
      recentHighlights: highlights.slice(0, 2),
      needsAttention,
    });
  }

  // Sort by needs attention first
  insights.sort((a, b) => {
    if (a.needsAttention && !b.needsAttention) return -1;
    if (!a.needsAttention && b.needsAttention) return 1;
    return 0;
  });

  const insightMetadata = {
    insightType: 'class_insights',
    sessionOccurrenceId: request.data.sessionOccurrenceId || null,
    requestedLearnerCount: learnerIds?.length || null,
    returnedLearnerCount: insights.length,
  };

  await persistTelemetryEvent({
    event: 'insight.viewed',
    userId: uid,
    role,
    siteId,
    metadata: insightMetadata,
  });

  // Keep legacy telemetry naming until all dashboards have migrated.
  await persistTelemetryEvent({
    event: 'motivation.insight.viewed',
    userId: uid,
    role,
    siteId,
    metadata: insightMetadata,
  });

  return { insights };
});

// ============================================================================
// HELPER FUNCTIONS FOR MOTIVATION ENGINE
// ============================================================================

async function createInitialMotivationProfile(learnerId: string, siteId: string) {
  const defaultProfile = {
    learnerId,
    siteId,
    primaryMotivators: ['mastery', 'achievement'] as MotivationType[],
    motivatorConfidence: {
      achievement: 0.3,
      social: 0.3,
      mastery: 0.3,
      autonomy: 0.3,
      purpose: 0.3,
      competition: 0.3,
      creativity: 0.3,
    },
    currentEngagement: 'engaged' as EngagementLevel,
    engagementTrend: 'stable' as const,
    interactionPatterns: {
      avgSessionDurationMinutes: 0,
      preferredTimeOfDay: 'afternoon' as const,
      mostActiveDay: 1,
      missionsCompletedPerWeek: 0,
      reflectionResponseRate: 0,
      appOpenFrequency: 0,
      streakDays: 0,
      longestStreak: 0,
      pauseBeforeSubmit: false,
      seeksHelpFrequency: 0,
      portfolioContributions: 0,
    },
    effectiveStrategies: [],
    nudgeFrequency: 'moderate' as const,
    respondsToBadges: true,
    respondsToStreaks: true,
    respondsSoSocialProof: true,
    pillarEngagement: {
      FUTURE_SKILLS: { interest: 0.5, performance: 0.5, growth: 0 },
      LEADERSHIP_AGENCY: { interest: 0.5, performance: 0.5, growth: 0 },
      IMPACT_INNOVATION: { interest: 0.5, performance: 0.5, growth: 0 },
    },
    insights: [],
    lastInteractionUpdate: FieldValue.serverTimestamp(),
    lastEducatorFeedback: FieldValue.serverTimestamp(),
    lastComputedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const docRef = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .add(defaultProfile);

  return { id: docRef.id, ...defaultProfile };
}

async function updateLearnerMotivationProfile(learnerId: string, siteId: string) {
  // Get or create profile
  const profileQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .limit(1)
    .get();

  let profileRef: FirebaseFirestore.DocumentReference;
  let existingProfile: Record<string, any>;

  if (profileQuery.empty) {
    const newProfile = await createInitialMotivationProfile(learnerId, siteId);
    profileRef = admin.firestore().collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES).doc(newProfile.id);
    existingProfile = newProfile;
  } else {
    profileRef = profileQuery.docs[0].ref;
    existingProfile = profileQuery.docs[0].data();
  }

  // Compute signals from interactions (last 30 days)
  const thirtyDaysAgo = Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);

  const interactions = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.LEARNER_INTERACTIONS)
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .where('timestamp', '>=', thirtyDaysAgo)
    .orderBy('timestamp', 'desc')
    .limit(500)
    .get();

  // Analyze interaction patterns
  const interactionData = interactions.docs.map(d => d.data());
  const interactionPatterns = computeInteractionPatterns(interactionData);

  // Get educator feedback (last 30 days)
  const feedbackQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.EDUCATOR_FEEDBACK)
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .where('createdAt', '>=', thirtyDaysAgo)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  const feedbackData = feedbackQuery.docs.map(d => d.data());

  // Compute motivation type scores from feedback
  const motivatorScores = computeMotivatorScores(feedbackData, existingProfile.motivatorConfidence || {});

  // Determine engagement level
  const engagementLevel = computeEngagementLevel(interactionPatterns, feedbackData);

  // Determine engagement trend
  const previousEngagement = existingProfile.currentEngagement || 'engaged';
  const engagementTrend = computeEngagementTrend(previousEngagement, engagementLevel);

  // Extract effective strategies from feedback
  const effectiveStrategies = extractEffectiveStrategies(feedbackData, existingProfile.effectiveStrategies || []);

  // Generate insights
  const insights = generateInsights(interactionPatterns, feedbackData, motivatorScores, engagementLevel);

  // Sort motivators by confidence
  const sortedMotivators = Object.entries(motivatorScores)
    .sort(([, a], [, b]) => (b as number) - (a as number))
    .slice(0, 3)
    .map(([type]) => type as MotivationType);

  // Update profile
  await profileRef.update({
    primaryMotivators: sortedMotivators,
    motivatorConfidence: motivatorScores,
    currentEngagement: engagementLevel,
    engagementTrend,
    interactionPatterns,
    effectiveStrategies,
    insights,
    lastComputedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
}

function computeInteractionPatterns(interactions: any[]): Record<string, any> {
  if (interactions.length === 0) {
    return {
      avgSessionDurationMinutes: 0,
      preferredTimeOfDay: 'afternoon',
      mostActiveDay: 1,
      missionsCompletedPerWeek: 0,
      reflectionResponseRate: 0,
      appOpenFrequency: 0,
      streakDays: 0,
      longestStreak: 0,
      pauseBeforeSubmit: false,
      seeksHelpFrequency: 0,
      portfolioContributions: 0,
    };
  }

  // Count events
  const appSessions = interactions.filter(i => i.eventType === 'app.session.end');
  const missionsCompleted = interactions.filter(i => i.eventType === 'mission.completed');
  const reflections = interactions.filter(i => i.eventType === 'reflection.submitted');
  const appOpens = interactions.filter(i => i.eventType === 'app.open');
  const helpRequests = interactions.filter(i => i.eventType === 'help.requested');
  const portfolioAdds = interactions.filter(i => i.eventType === 'portfolio.item.added');

  // Calculate averages
  const avgSessionDuration = appSessions.length > 0
    ? appSessions.reduce((sum, s) => sum + (s.metadata?.durationSeconds || 0), 0) / appSessions.length / 60
    : 0;

  // Determine preferred time of day
  const hours = interactions
    .filter(i => i.timestamp)
    .map(i => new Date(i.timestamp.toMillis ? i.timestamp.toMillis() : i.timestamp).getHours());
  
  const morningCount = hours.filter(h => h >= 6 && h < 12).length;
  const afternoonCount = hours.filter(h => h >= 12 && h < 18).length;
  const eveningCount = hours.filter(h => h >= 18 || h < 6).length;

  let preferredTimeOfDay: 'morning' | 'afternoon' | 'evening' = 'afternoon';
  if (morningCount > afternoonCount && morningCount > eveningCount) preferredTimeOfDay = 'morning';
  else if (eveningCount > afternoonCount && eveningCount > morningCount) preferredTimeOfDay = 'evening';

  // Most active day
  const days = interactions
    .filter(i => i.timestamp)
    .map(i => new Date(i.timestamp.toMillis ? i.timestamp.toMillis() : i.timestamp).getDay());
  const dayCounts = [0, 0, 0, 0, 0, 0, 0];
  days.forEach(d => dayCounts[d]++);
  const mostActiveDay = dayCounts.indexOf(Math.max(...dayCounts));

  // Weekly rates (divide by ~4 weeks)
  const weeksInPeriod = 4;

  return {
    avgSessionDurationMinutes: Math.round(avgSessionDuration * 10) / 10,
    preferredTimeOfDay,
    mostActiveDay,
    missionsCompletedPerWeek: Math.round(missionsCompleted.length / weeksInPeriod * 10) / 10,
    reflectionResponseRate: missionsCompleted.length > 0 
      ? Math.round(reflections.length / missionsCompleted.length * 100) / 100 
      : 0,
    appOpenFrequency: Math.round(appOpens.length / weeksInPeriod * 10) / 10,
    streakDays: 0, // Would need more complex calculation
    longestStreak: 0,
    pauseBeforeSubmit: avgSessionDuration > 15,
    seeksHelpFrequency: Math.round(helpRequests.length / weeksInPeriod * 10) / 10,
    portfolioContributions: portfolioAdds.length,
  };
}

function computeMotivatorScores(
  feedbackData: any[], 
  existingScores: Record<MotivationType, number>
): Record<MotivationType, number> {
  const scores: Record<MotivationType, number> = {
    achievement: existingScores.achievement || 0.3,
    social: existingScores.social || 0.3,
    mastery: existingScores.mastery || 0.3,
    autonomy: existingScores.autonomy || 0.3,
    purpose: existingScores.purpose || 0.3,
    competition: existingScores.competition || 0.3,
    creativity: existingScores.creativity || 0.3,
  };

  if (feedbackData.length === 0) return scores;

  // Count positive responses to each motivation type
  const responseCounts: Record<MotivationType, number> = {
    achievement: 0, social: 0, mastery: 0, autonomy: 0, 
    purpose: 0, competition: 0, creativity: 0,
  };

  feedbackData.forEach(fb => {
    (fb.respondedWellTo || []).forEach((type: MotivationType) => {
      if (responseCounts[type] !== undefined) {
        responseCounts[type]++;
      }
    });
  });

  const totalFeedback = feedbackData.length;

  // Update scores with weighted average (existing 30%, new 70%)
  Object.keys(responseCounts).forEach(type => {
    const key = type as MotivationType;
    const newScore = responseCounts[key] / totalFeedback;
    scores[key] = Math.round((existingScores[key] * 0.3 + newScore * 0.7) * 100) / 100;
  });

  return scores;
}

function computeEngagementLevel(
  patterns: Record<string, any>, 
  feedbackData: any[]
): EngagementLevel {
  // Calculate engagement score (0-100)
  let score = 50; // Base score

  // From interaction patterns
  if (patterns.missionsCompletedPerWeek >= 3) score += 15;
  else if (patterns.missionsCompletedPerWeek >= 1) score += 5;
  else score -= 10;

  if (patterns.reflectionResponseRate >= 0.7) score += 10;
  else if (patterns.reflectionResponseRate >= 0.3) score += 5;

  if (patterns.appOpenFrequency >= 5) score += 10;
  else if (patterns.appOpenFrequency >= 2) score += 5;
  else score -= 5;

  if (patterns.avgSessionDurationMinutes >= 20) score += 10;
  else if (patterns.avgSessionDurationMinutes >= 10) score += 5;

  // From educator feedback
  if (feedbackData.length > 0) {
    const avgEngagement = feedbackData.reduce((sum, fb) => sum + (fb.engagementLevel || 3), 0) / feedbackData.length;
    score += (avgEngagement - 3) * 10; // -20 to +20 adjustment

    // Participation type adjustments
    const recentFeedback = feedbackData[0];
    if (recentFeedback) {
      if (recentFeedback.participationType === 'leader') score += 10;
      else if (recentFeedback.participationType === 'active') score += 5;
      else if (recentFeedback.participationType === 'reluctant') score -= 10;
    }
  }

  // Map score to engagement level
  if (score >= 80) return 'thriving';
  if (score >= 60) return 'engaged';
  if (score >= 40) return 'coasting';
  if (score >= 20) return 'struggling';
  return 'at-risk';
}

function computeEngagementTrend(
  previous: EngagementLevel, 
  current: EngagementLevel
): 'improving' | 'stable' | 'declining' {
  const levels: EngagementLevel[] = ['at-risk', 'struggling', 'coasting', 'engaged', 'thriving'];
  const prevIndex = levels.indexOf(previous);
  const currIndex = levels.indexOf(current);

  if (currIndex > prevIndex) return 'improving';
  if (currIndex < prevIndex) return 'declining';
  return 'stable';
}

function extractEffectiveStrategies(
  feedbackData: any[], 
  existingStrategies: any[]
): any[] {
  const strategyMap = new Map<string, any>();

  // Load existing strategies
  existingStrategies.forEach(s => {
    strategyMap.set(`${s.type}:${s.strategy}`, s);
  });

  // Add new strategies from feedback
  feedbackData.forEach(fb => {
    (fb.effectiveStrategies || []).forEach((s: any) => {
      const key = `${s.type}:${s.strategy}`;
      if (strategyMap.has(key)) {
        const existing = strategyMap.get(key);
        existing.usageCount++;
        // Update effectiveness based on engagement level
        const engagementBonus = (fb.engagementLevel - 3) * 0.1;
        existing.effectiveness = Math.min(1, Math.max(0, 
          (existing.effectiveness + engagementBonus + 0.1) / 2
        ));
      } else {
        strategyMap.set(key, {
          type: s.type,
          strategy: s.strategy,
          effectiveness: 0.5 + ((fb.engagementLevel - 3) * 0.1),
          usageCount: 1,
        });
      }
    });
  });

  return Array.from(strategyMap.values())
    .sort((a, b) => b.effectiveness - a.effectiveness)
    .slice(0, 10);
}

function clampInsightConfidence(value: number): number {
  return Math.max(0.55, Math.min(0.95, Number(value.toFixed(2))));
}

function confidenceAboveThreshold(
  value: number,
  threshold: number,
  scale: number,
  baseline: number,
): number {
  const gap = Math.max(0, value - threshold);
  return clampInsightConfidence(baseline + Math.min(gap / scale, 1) * 0.25);
}

function confidenceBelowThreshold(
  value: number,
  threshold: number,
  scale: number,
  baseline: number,
): number {
  const gap = Math.max(0, threshold - value);
  return clampInsightConfidence(baseline + Math.min(gap / scale, 1) * 0.25);
}

function generateInsights(
  patterns: Record<string, any>,
  feedbackData: any[],
  motivatorScores: Record<MotivationType, number>,
  engagementLevel: EngagementLevel
): any[] {
  const insights: any[] = [];
  const now = Timestamp.now();

  // Strength insights
  const topMotivator = Object.entries(motivatorScores)
    .sort(([, a], [, b]) => (b as number) - (a as number))[0];
  
  if (topMotivator && (topMotivator[1] as number) > 0.6) {
    insights.push({
      id: `strength-${topMotivator[0]}`,
      type: 'strength',
      title: `Strong ${topMotivator[0]} motivation`,
      description: `This learner responds particularly well to ${topMotivator[0]}-based approaches.`,
      confidence: topMotivator[1],
      basedOn: ['educator feedback patterns'],
      suggestedActions: [`Use ${topMotivator[0]}-focused activities`, 'Leverage this in challenging moments'],
      createdAt: now,
    });
  }

  // Celebration insight for high engagement
  if (engagementLevel === 'thriving') {
    insights.push({
      id: 'celebration-thriving',
      type: 'celebration',
      title: 'Exceptional engagement!',
      description: 'This learner is thriving and highly engaged.',
      confidence: confidenceAboveThreshold(feedbackData.length + 1, 1, 4, 0.7),
      basedOn: ['interaction patterns', 'educator feedback'],
      suggestedActions: ['Consider leadership opportunities', 'Encourage peer mentoring'],
      createdAt: now,
    });
  }

  // Warning insights
  if (engagementLevel === 'at-risk' || engagementLevel === 'struggling') {
    const engagementRiskScore = engagementLevel === 'at-risk' ? 1 : 0.6;
    insights.push({
      id: 'warning-engagement',
      type: 'warning',
      title: 'Needs extra support',
      description: `Engagement is ${engagementLevel}. Consider checking in.`,
      confidence: clampInsightConfidence(0.58 + engagementRiskScore * 0.18),
      basedOn: ['interaction patterns', 'engagement metrics'],
      suggestedActions: ['Schedule 1:1 check-in', 'Try different motivation approach'],
      createdAt: now,
    });
  }

  // Opportunity insights
  if (patterns.reflectionResponseRate < 0.3) {
    insights.push({
      id: 'opportunity-reflection',
      type: 'opportunity',
      title: 'Reflection opportunity',
      description: 'Low reflection completion. Could benefit from guided prompts.',
      confidence: confidenceBelowThreshold(patterns.reflectionResponseRate || 0, 0.3, 0.3, 0.56),
      basedOn: ['reflection submission rate'],
      suggestedActions: ['Use simpler reflection prompts', 'Try voice/video reflections'],
      createdAt: now,
    });
  }

  return insights.slice(0, 5); // Limit to 5 insights
}

async function updateStrategyEffectiveness(
  learnerId: string, 
  strategyType: MotivationType, 
  outcome: 'helped' | 'partial' | 'no-change' | 'backfired'
) {
  const profileQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .where('learnerId', '==', learnerId)
    .limit(1)
    .get();

  if (profileQuery.empty) return;

  const profileRef = profileQuery.docs[0].ref;
  const profile = profileQuery.docs[0].data();

  const strategies = profile.effectiveStrategies || [];
  const updated = strategies.map((s: any) => {
    if (s.type === strategyType) {
      let delta = 0;
      if (outcome === 'helped') delta = 0.1;
      else if (outcome === 'partial') delta = 0.05;
      else if (outcome === 'backfired') delta = -0.15;
      
      return {
        ...s,
        effectiveness: Math.min(1, Math.max(0, s.effectiveness + delta)),
        usageCount: s.usageCount + 1,
        lastUsedAt: FieldValue.serverTimestamp(),
      };
    }
    return s;
  });

  await profileRef.update({
    effectiveStrategies: updated,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function generateNudgesForLearner(learnerId: string, siteId: string) {
  // Get learner's motivation profile
  const profileQuery = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_PROFILES)
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .limit(1)
    .get();

  if (profileQuery.empty) {
    await createInitialMotivationProfile(learnerId, siteId);
    return;
  }

  const profile = profileQuery.docs[0].data();
  const primaryMotivator = profile.primaryMotivators?.[0] || 'achievement';

  // Check existing pending nudges
  const existingNudges = await admin.firestore()
    .collection(MOTIVATION_COLLECTIONS.MOTIVATION_NUDGES)
    .where('learnerId', '==', learnerId)
    .where('status', '==', 'pending')
    .get();

  // Don't create too many nudges
  if (existingNudges.size >= 3) return;

  // Generate appropriate nudge based on engagement level and motivation type
  const nudgeTemplates: Record<MotivationType, { title: string; message: string }[]> = {
    achievement: [
      { title: '🎯 Almost there!', message: 'You\'re so close to your next milestone. One more mission to go!' },
      { title: '⭐ Challenge accepted?', message: 'Ready to tackle something new? Your skills are ready for the next level!' },
    ],
    social: [
      { title: '👋 Your team misses you!', message: 'Join your classmates for today\'s group activity!' },
      { title: '🤝 Collaboration time', message: 'A friend could use your help on their project. Ready to team up?' },
    ],
    mastery: [
      { title: '📚 Deep dive time', message: 'Master today\'s skill with focused practice. You\'ve got this!' },
      { title: '🧠 Level up your knowledge', message: 'New learning awaits! Take your time to really understand it.' },
    ],
    autonomy: [
      { title: '🎨 Your choice today', message: 'Pick your own adventure! What skill do you want to work on?' },
      { title: '🚀 Your path, your pace', message: 'Today\'s missions are flexible. Design your learning journey!' },
    ],
    purpose: [
      { title: '🌍 Make an impact', message: 'Your work today can make a real difference. Ready to contribute?' },
      { title: '💡 Meaningful work', message: 'This mission connects to real-world problems. Your ideas matter!' },
    ],
    competition: [
      { title: '🏆 Leaderboard update', message: 'You\'re just 2 points behind! One mission could change that.' },
      { title: '⚡ Quick challenge', message: 'Beat your personal best! Can you complete this faster than last time?' },
    ],
    creativity: [
      { title: '🎨 Creative freedom', message: 'Today\'s mission lets you express yourself. What will you create?' },
      { title: '✨ Imagination station', message: 'No wrong answers today! Let your creativity flow.' },
    ],
  };

  const templates = nudgeTemplates[primaryMotivator as MotivationType] || nudgeTemplates.achievement;
  const template = templates[Math.floor(Math.random() * templates.length)];

  // Determine nudge type based on engagement
  let nudgeType: 'reminder' | 'celebration' | 'challenge' | 'encouragement' | 'tip' = 'encouragement';
  if (profile.currentEngagement === 'thriving') nudgeType = 'challenge';
  else if (profile.currentEngagement === 'struggling' || profile.currentEngagement === 'at-risk') nudgeType = 'encouragement';

  // Create the nudge
  await admin.firestore().collection(MOTIVATION_COLLECTIONS.MOTIVATION_NUDGES).add({
    learnerId,
    siteId,
    type: nudgeType,
    title: template.title,
    message: template.message,
    motivationTypeTarget: primaryMotivator,
    priority: profile.currentEngagement === 'at-risk' ? 'high' : 'medium',
    status: 'pending',
    generatedBy: 'system',
    basedOnInsights: profile.insights?.slice(0, 2).map((i: any) => i.id) || [],
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
  });
}

// ─── Evidence → Rubric → Growth callable ─────────────────────────────────────
// Replicates Flutter's submitReview() chain for the web platform:
// 1. Creates a RubricApplication doc
// 2. For each distinct capabilityId in the scores, creates a CapabilityGrowthEvent
//    and upserts CapabilityMastery
// 3. Links the matching EvidenceRecords (sets rubricStatus + growthStatus)
// Uses a Firestore batch for all-or-nothing atomicity.

interface RubricScoreInput {
  criterionId: string;
  capabilityId: string;
  processDomainId?: string;
  pillarCode: string;
  score: number;
  maxScore: number;
}

export const applyRubricToEvidence = onCall(async (request: CallableRequest<{
  evidenceRecordIds: string[];
  missionAttemptId?: string;
  learnerId: string;
  siteId: string;
  rubricId?: string;
  scores: RubricScoreInput[];
}>) => {
  const educatorId = request.auth?.uid;
  await requireRoleAndSite(educatorId, ['educator', 'siteLead', 'site', 'hq', 'admin'], request.data?.siteId);

  const { evidenceRecordIds, missionAttemptId, learnerId, siteId, rubricId, scores } = request.data ?? {};

  const hasEvidence = Array.isArray(evidenceRecordIds) && evidenceRecordIds.length > 0;
  const hasMission = typeof missionAttemptId === 'string' && missionAttemptId.length > 0;
  if (!hasEvidence && !hasMission) {
    throw new HttpsError('invalid-argument', 'Either evidenceRecordIds or missionAttemptId is required.');
  }
  const safeEvidenceRecordIds = hasEvidence ? evidenceRecordIds : [];
  if (!learnerId || typeof learnerId !== 'string') {
    throw new HttpsError('invalid-argument', 'learnerId is required.');
  }
  if (!siteId || typeof siteId !== 'string') {
    throw new HttpsError('invalid-argument', 'siteId is required.');
  }
  if (!Array.isArray(scores) || scores.length === 0) {
    throw new HttpsError('invalid-argument', 'scores array is required and must be non-empty.');
  }
  for (const s of scores) {
    if (!s.capabilityId || typeof s.score !== 'number' || typeof s.maxScore !== 'number') {
      throw new HttpsError('invalid-argument', 'Each score must have capabilityId, score, and maxScore.');
    }
    if (s.score < 0 || s.maxScore <= 0 || s.score > s.maxScore) {
      throw new HttpsError('invalid-argument', `Invalid score values: ${s.score}/${s.maxScore}`);
    }
  }

  const db = admin.firestore();
  const batch = db.batch();

  // 1. Create the RubricApplication document
  const rubricAppRef = db.collection('rubricApplications').doc();
  batch.set(rubricAppRef, {
    learnerId,
    siteId,
    educatorId,
    rubricId: rubricId ?? null,
    missionAttemptId: missionAttemptId ?? null,
    evidenceRecordIds: safeEvidenceRecordIds,
    scores: scores.map((s) => ({
      criterionId: s.criterionId,
      capabilityId: s.capabilityId,
      processDomainId: s.processDomainId ?? null,
      pillarCode: s.pillarCode,
      score: s.score,
      maxScore: s.maxScore,
    })),
    createdAt: FieldValue.serverTimestamp(),
  });

  // Group scores by capabilityId
  const scoresByCapability = new Map<string, RubricScoreInput[]>();
  for (const s of scores) {
    const existing = scoresByCapability.get(s.capabilityId) ?? [];
    existing.push(s);
    scoresByCapability.set(s.capabilityId, existing);
  }

  const growthEventIds: string[] = [];

  // 2. For each capability: create growth event + upsert mastery
  for (const [capabilityId, capabilityScores] of scoresByCapability) {
    const rawScore = capabilityScores.reduce((sum, s) => sum + s.score, 0);
    const maxScore = capabilityScores.reduce((sum, s) => sum + s.maxScore, 0);
    const pillarCode = capabilityScores.find((s) => s.pillarCode)?.pillarCode ?? '';

    // Level 1-4 from normalized score
    const nextLevel = maxScore <= 0
      ? 0
      : Math.max(1, Math.min(4, Math.ceil((rawScore / maxScore) * 4)));

    // Upsert CapabilityMastery
    const masteryId = `${learnerId}_${capabilityId}`;
    const masteryRef = db.collection('capabilityMastery').doc(masteryId);
    const masterySnap = await masteryRef.get();
    const masteryData = masterySnap.data() ?? {};
    const highestLevel = Math.max(nextLevel, (masteryData.highestLevel as number) ?? 0);
    const priorEvidenceIds: string[] = Array.isArray(masteryData.evidenceIds) ? masteryData.evidenceIds : [];
    const mergedEvidenceIds = [...new Set([...safeEvidenceRecordIds, ...priorEvidenceIds])];

    batch.set(masteryRef, {
      learnerId,
      capabilityId,
      siteId,
      pillarCode,
      latestLevel: nextLevel,
      highestLevel,
      latestEvidenceId: safeEvidenceRecordIds[0] ?? null,
      latestMissionAttemptId: missionAttemptId ?? null,
      evidenceIds: mergedEvidenceIds,
      createdAt: masteryData.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // Create CapabilityGrowthEvent
    const growthEventRef = db.collection('capabilityGrowthEvents').doc();
    growthEventIds.push(growthEventRef.id);
    batch.set(growthEventRef, {
      learnerId,
      capabilityId,
      siteId,
      pillarCode,
      level: nextLevel,
      rawScore,
      maxScore,
      missionAttemptId: missionAttemptId ?? null,
      linkedEvidenceRecordIds: safeEvidenceRecordIds,
      linkedPortfolioItemIds: [],
      rubricApplicationId: rubricAppRef.id,
      educatorId,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  // 2b. For each process domain: create growth event + upsert mastery
  const scoresByProcessDomain = new Map<string, RubricScoreInput[]>();
  for (const s of scores) {
    if (s.processDomainId && typeof s.processDomainId === 'string' && s.processDomainId.trim().length > 0) {
      const existing = scoresByProcessDomain.get(s.processDomainId) ?? [];
      existing.push(s);
      scoresByProcessDomain.set(s.processDomainId, existing);
    }
  }

  for (const [processDomainId, domainScores] of scoresByProcessDomain) {
    const rawScore = domainScores.reduce((sum, s) => sum + s.score, 0);
    const maxScore = domainScores.reduce((sum, s) => sum + s.maxScore, 0);
    const nextLevel = maxScore <= 0
      ? 0
      : Math.max(1, Math.min(4, Math.ceil((rawScore / maxScore) * 4)));

    // Upsert ProcessDomainMastery
    const pdMasteryId = `${learnerId}_${processDomainId}`;
    const pdMasteryRef = db.collection('processDomainMastery').doc(pdMasteryId);
    const pdMasterySnap = await pdMasteryRef.get();
    const pdMasteryData = pdMasterySnap.data() ?? {};
    const pdHighestLevel = Math.max(nextLevel, (pdMasteryData.highestLevel as number) ?? 0);
    const pdPriorEvidenceIds: string[] = Array.isArray(pdMasteryData.evidenceIds) ? pdMasteryData.evidenceIds : [];
    const pdMergedEvidenceIds = [...new Set([...safeEvidenceRecordIds, ...pdPriorEvidenceIds])];

    batch.set(pdMasteryRef, {
      learnerId,
      processDomainId,
      siteId,
      latestLevel: nextLevel,
      highestLevel: pdHighestLevel,
      evidenceIds: pdMergedEvidenceIds,
      createdAt: pdMasteryData.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // Create ProcessDomainGrowthEvent
    const pdGrowthRef = db.collection('processDomainGrowthEvents').doc();
    batch.set(pdGrowthRef, {
      learnerId,
      processDomainId,
      siteId,
      level: nextLevel,
      rawScore,
      maxScore,
      missionAttemptId: missionAttemptId ?? null,
      linkedEvidenceRecordIds: safeEvidenceRecordIds,
      rubricApplicationId: rubricAppRef.id,
      educatorId,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  // 3. Link evidence records
  for (const evidenceId of safeEvidenceRecordIds) {
    const evidenceRef = db.collection('evidenceRecords').doc(evidenceId);
    batch.update(evidenceRef, {
      rubricStatus: 'applied',
      growthStatus: 'recorded',
      rubricApplicationId: rubricAppRef.id,
      growthEventId: growthEventIds[0] ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  // 3b. Update mission attempt if provided
  if (hasMission) {
    const missionRef = db.collection('missionAttempts').doc(missionAttemptId!);
    batch.update(missionRef, {
      status: 'reviewed',
      reviewStatus: 'reviewed',
      reviewedBy: educatorId,
      reviewedAt: FieldValue.serverTimestamp(),
      rubricApplicationId: rubricAppRef.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  // 4. Enrich portfolio — create/update a PortfolioItem linking evidence → capabilities → growth
  const portfolioItemIds: string[] = [];
  const portfolioBatch = db.batch();
  const capabilityIds = Array.from(scoresByCapability.keys());

  // Group pillar codes from scored capabilities
  const pillarCodes = [...new Set(scores.map((s) => s.pillarCode).filter(Boolean))];

  // Read evidence records to extract artifact data for portfolio
  if (safeEvidenceRecordIds.length > 0) {
    const evidenceDocs = await Promise.all(
      safeEvidenceRecordIds.map((id) => db.collection('evidenceRecords').doc(id).get())
    );

    for (const evidenceDoc of evidenceDocs) {
      if (!evidenceDoc.exists) continue;
      const evidenceData = evidenceDoc.data() ?? {};
      const portfolioId = `rubric-${evidenceDoc.id}`;
      const portfolioRef = db.collection('portfolioItems').doc(portfolioId);

      portfolioBatch.set(portfolioRef, {
        learnerId,
        siteId,
        title: typeof evidenceData.description === 'string'
          ? evidenceData.description.slice(0, 100)
          : 'Reviewed evidence',
        description: typeof evidenceData.description === 'string'
          ? evidenceData.description
          : '',
        pillarCodes,
        artifacts: typeof evidenceData.artifactUrl === 'string' ? [evidenceData.artifactUrl] : [],
        evidenceRecordIds: [evidenceDoc.id],
        capabilityIds,
        growthEventIds,
        rubricApplicationId: rubricAppRef.id,
        educatorId,
        verificationStatus: 'reviewed',
        proofOfLearningStatus: evidenceData.portfolioCandidate ? 'partial' : 'not-available',
        aiDisclosureStatus: evidenceData.aiDisclosureStatus ?? 'not-available',
        source: 'rubric_application',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      portfolioItemIds.push(portfolioId);
    }
  }

  // 4b. Create portfolio item from mission attempt if no evidence records
  if (hasMission && safeEvidenceRecordIds.length === 0) {
    const missionDoc = await db.collection('missionAttempts').doc(missionAttemptId!).get();
    const missionData = missionDoc.exists ? (missionDoc.data() ?? {}) : {};
    const missionTitle = typeof missionData.missionTitle === 'string'
      ? missionData.missionTitle
      : 'Mission submission';
    const portfolioId = `rubric-mission-${missionAttemptId}`;
    const portfolioRef = db.collection('portfolioItems').doc(portfolioId);
    const artifacts: string[] = Array.isArray(missionData.attachmentUrls) ? missionData.attachmentUrls : [];

    portfolioBatch.set(portfolioRef, {
      learnerId,
      siteId,
      title: missionTitle.slice(0, 100),
      description: typeof missionData.content === 'string' ? missionData.content : missionTitle,
      pillarCodes,
      artifacts,
      evidenceRecordIds: [],
      missionAttemptId,
      capabilityIds,
      growthEventIds,
      rubricApplicationId: rubricAppRef.id,
      educatorId,
      verificationStatus: 'reviewed',
      proofOfLearningStatus: 'not-available',
      aiDisclosureStatus: 'not-available',
      source: 'mission_rubric_application',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    portfolioItemIds.push(portfolioId);
  }

  // Update growth events with linked portfolio item IDs
  for (const growthEventId of growthEventIds) {
    portfolioBatch.update(db.collection('capabilityGrowthEvents').doc(growthEventId), {
      linkedPortfolioItemIds: portfolioItemIds,
    });
  }

  await portfolioBatch.commit();

  return {
    rubricApplicationId: rubricAppRef.id,
    growthEventIds,
    portfolioItemIds,
    capabilitiesProcessed: scoresByCapability.size,
  };
});

/**
 * Verify Proof-of-Learning for a portfolio item.
 * When verified, creates CapabilityGrowthEvents and updates CapabilityMastery
 * for each linked capability, completing the evidence chain.
 */
export const verifyProofOfLearning = onCall(async (request: CallableRequest<{
  portfolioItemId: string;
  verificationStatus: 'verified' | 'reviewed' | 'pending';
  proofOfLearningStatus: 'verified' | 'partial' | 'missing' | 'not-available';
  proofChecks: { explainItBack: boolean; oralCheck: boolean; miniRebuild: boolean };
  excerpts?: { explainItBack?: string; oralCheck?: string; miniRebuild?: string };
  educatorNotes?: string;
  resubmissionReason?: string;
}>) => {
  const educatorId = request.auth?.uid;
  if (!educatorId) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const {
    portfolioItemId,
    verificationStatus,
    proofOfLearningStatus,
    proofChecks,
    excerpts,
    educatorNotes,
    resubmissionReason,
  } = request.data ?? {};

  if (!portfolioItemId || typeof portfolioItemId !== 'string') {
    throw new HttpsError('invalid-argument', 'portfolioItemId is required.');
  }
  if (!verificationStatus) {
    throw new HttpsError('invalid-argument', 'verificationStatus is required.');
  }

  const db = admin.firestore();

  // Read the portfolio item
  const portfolioRef = db.collection('portfolioItems').doc(portfolioItemId);
  const portfolioSnap = await portfolioRef.get();
  if (!portfolioSnap.exists) {
    throw new HttpsError('not-found', 'Portfolio item not found.');
  }
  const portfolioData = portfolioSnap.data() ?? {};
  const learnerId = portfolioData.learnerId as string;
  const siteId = portfolioData.siteId as string;

  // Verify educator has access to this site
  await requireRoleAndSite(educatorId, ['educator', 'siteLead', 'site', 'hq', 'admin'], siteId);

  const checkpointCount = [proofChecks?.explainItBack, proofChecks?.oralCheck, proofChecks?.miniRebuild]
    .filter(Boolean).length;

  const batch = db.batch();

  // 1. Update the portfolio item
  const portfolioUpdate: Record<string, unknown> = {
    verificationStatus,
    proofOfLearningStatus,
    proofHasExplainItBack: proofChecks?.explainItBack ?? false,
    proofHasOralCheck: proofChecks?.oralCheck ?? false,
    proofHasMiniRebuild: proofChecks?.miniRebuild ?? false,
    proofCheckpointCount: checkpointCount,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (excerpts?.explainItBack) portfolioUpdate.proofExplainItBackExcerpt = excerpts.explainItBack;
  if (excerpts?.oralCheck) portfolioUpdate.proofOralCheckExcerpt = excerpts.oralCheck;
  if (excerpts?.miniRebuild) portfolioUpdate.proofMiniRebuildExcerpt = excerpts.miniRebuild;
  if (educatorNotes) portfolioUpdate.verificationNotes = educatorNotes;
  if (resubmissionReason) {
    portfolioUpdate.verificationPrompt = resubmissionReason;
    portfolioUpdate.verificationPromptSource = 'educator_review';
  }
  batch.update(portfolioRef, portfolioUpdate);

  const growthEventIds: string[] = [];
  const capabilityIds: string[] = Array.isArray(portfolioData.capabilityIds) ? portfolioData.capabilityIds : [];

  // 2. If verified and capabilities are linked, create growth events + update mastery
  if (verificationStatus === 'verified' && capabilityIds.length > 0) {
    for (const capabilityId of capabilityIds) {
      // Read capability to get pillarCode
      const capSnap = await db.collection('capabilities').doc(capabilityId).get();
      const pillarCode = capSnap.exists ? (capSnap.data()?.pillarCode ?? '') : '';

      // Create growth event recording PoL verification
      const growthRef = db.collection('capabilityGrowthEvents').doc();
      growthEventIds.push(growthRef.id);
      batch.set(growthRef, {
        learnerId,
        capabilityId,
        siteId,
        pillarCode,
        level: checkpointCount, // 1-3 based on proof checks passed
        rawScore: checkpointCount,
        maxScore: 3,
        evidenceId: portfolioItemId,
        linkedPortfolioItemIds: [portfolioItemId],
        rubricApplicationId: null,
        educatorId,
        source: 'proof_of_learning',
        createdAt: FieldValue.serverTimestamp(),
      });

      // Upsert CapabilityMastery
      const masteryId = `${learnerId}_${capabilityId}`;
      const masteryRef = db.collection('capabilityMastery').doc(masteryId);
      const masterySnap = await masteryRef.get();
      const masteryData = masterySnap.data() ?? {};
      const priorGrowthEventIds: string[] = Array.isArray(masteryData.growthEventIds) ? masteryData.growthEventIds : [];
      const priorEvidenceIds: string[] = Array.isArray(masteryData.evidenceIds) ? masteryData.evidenceIds : [];

      batch.set(masteryRef, {
        learnerId,
        capabilityId,
        siteId,
        pillarCode,
        latestLevel: Math.max(checkpointCount, (masteryData.latestLevel as number) ?? 0),
        highestLevel: Math.max(checkpointCount, (masteryData.highestLevel as number) ?? 0),
        latestEvidenceId: portfolioItemId,
        evidenceIds: [...new Set([portfolioItemId, ...priorEvidenceIds])],
        growthEventIds: [...new Set([growthRef.id, ...priorGrowthEventIds])],
        proofOfLearningVerified: true,
        createdAt: masteryData.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }

  await batch.commit();

  return {
    portfolioItemId,
    verificationStatus,
    growthEventIds,
    capabilitiesProcessed: capabilityIds.length,
  };
});

// ---------------------------------------------------------------------------
// S3-2: Badge auto-issuance based on capability mastery
// ---------------------------------------------------------------------------

/**
 * Evaluates badge eligibility for a learner when their mastery changes.
 * Checks all site badges against the learner's current mastery levels
 * and auto-awards any badges whose criteria are met.
 */
export const evaluateBadgeEligibility = onCall(async (request: CallableRequest<{
  learnerId: string;
  siteId: string;
  capabilityId?: string;
}>) => {
  const auth = request.auth;
  if (!auth) throw new HttpsError('unauthenticated', 'Must be authenticated');

  const { learnerId, siteId, capabilityId } = request.data;
  if (!learnerId || !siteId) {
    throw new HttpsError('invalid-argument', 'learnerId and siteId required');
  }

  const db = admin.firestore();
  const MASTERY_RANK: Record<string, number> = {
    emerging: 1,
    developing: 2,
    proficient: 3,
    advanced: 4,
  };

  // Load badges for this site
  let badgeQuery = db.collection('recognitionBadges').where('siteId', '==', siteId);
  if (capabilityId) {
    // Optimization: only check badges requiring this specific capability
    badgeQuery = badgeQuery.where('requiredCapabilityId', '==', capabilityId);
  }
  const badgesSnap = await badgeQuery.get();
  if (badgesSnap.empty) return { awarded: [] };

  // Load learner's current mastery levels
  const masterySnap = await db
    .collection('capabilityMastery')
    .where('learnerId', '==', learnerId)
    .get();

  const masteryByCapability = new Map<string, string>();
  masterySnap.docs.forEach((d) => {
    const data = d.data();
    if (data.capabilityId && data.currentLevel) {
      masteryByCapability.set(data.capabilityId, data.currentLevel);
    }
  });

  // Load existing badge awards to avoid duplicates
  const existingAwardsSnap = await db
    .collection('badgeAwards')
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .get();

  const existingBadgeIds = new Set(existingAwardsSnap.docs.map((d) => d.data().badgeId));

  // Load evidence count for microSkill-based badges
  const evidenceSnap = await db
    .collection('skillEvidence')
    .where('learnerId', '==', learnerId)
    .where('siteId', '==', siteId)
    .get();

  const evidenceBySkill = new Map<string, string[]>();
  evidenceSnap.docs.forEach((d) => {
    const data = d.data();
    const skillId = data.microSkillId as string;
    if (skillId) {
      const ids = evidenceBySkill.get(skillId) || [];
      ids.push(d.id);
      evidenceBySkill.set(skillId, ids);
    }
  });

  const awarded: Array<{ badgeId: string; badgeName: string; awardId: string }> = [];
  const batch = db.batch();

  for (const badgeDoc of badgesSnap.docs) {
    const badge = badgeDoc.data();
    if (existingBadgeIds.has(badgeDoc.id)) continue; // Already awarded

    let eligible = true;
    const linkedEvidenceIds: string[] = [];

    // Check capability mastery requirement
    if (badge.requiredCapabilityId && badge.requiredMasteryLevel) {
      const learnerLevel = masteryByCapability.get(badge.requiredCapabilityId);
      if (!learnerLevel || MASTERY_RANK[learnerLevel] < MASTERY_RANK[badge.requiredMasteryLevel]) {
        eligible = false;
      }
    }

    // Check microSkill evidence requirements
    if (eligible && Array.isArray(badge.requiredMicroSkillIds) && badge.requiredMicroSkillIds.length > 0) {
      for (const skillId of badge.requiredMicroSkillIds) {
        const evidence = evidenceBySkill.get(skillId);
        if (!evidence || evidence.length === 0) {
          eligible = false;
          break;
        }
        linkedEvidenceIds.push(...evidence);
      }
    }

    // Check required evidence count
    if (eligible && typeof badge.requiredEvidenceCount === 'number' && badge.requiredEvidenceCount > 0) {
      if (linkedEvidenceIds.length < badge.requiredEvidenceCount) {
        eligible = false;
      }
    }

    if (eligible) {
      const awardRef = db.collection('badgeAwards').doc();
      batch.set(awardRef, {
        badgeId: badgeDoc.id,
        learnerId,
        siteId,
        evidenceIds: linkedEvidenceIds.slice(0, 50), // Cap at 50 references
        awardedAt: FieldValue.serverTimestamp(),
        awardedBy: 'system',
      });
      awarded.push({
        badgeId: badgeDoc.id,
        badgeName: badge.name || 'Badge',
        awardId: awardRef.id,
      });
    }
  }

  if (awarded.length > 0) {
    await batch.commit();
  }

  return { awarded };
});
