/**
 * BOS+MIA Runtime — Server-side orchestration
 *
 * Implements:
 *  1. ingestEvent       — POST /ingest-event  (HOW_TO §1)
 *  2. getOrchState      — GET  /orchestration-state (HOW_TO §2)
 *  3. getIntervention    — POST /get-intervention (HOW_TO §3)
 *  4. scoreMvl           — POST /score-mvl (HOW_TO §4)
 *  5. submitMvlEvidence  — POST /mvl/submit-evidence (HOW_TO §4b)
 *  6. getClassInsights   — GET  /educator/class/:id/insights (HOW_TO §6)
 *  7. teacherOverrideMvl — POST /teacher/override-mvl (HOW_TO §5)
 *  8. contestability     — POST /contestability/request + resolve (HOW_TO §7)
 *
 * Plus:
 *  - FDM (Feature Detection Module) — §2 sense pipeline
 *  - EKF-lite estimator            — §3 state estimator
 *  - Policy engine                 — §4 autonomy-regularized control
 *
 * All write to Firestore collections:
 *   interactionEvents, fdmFeatures, orchestrationStates,
 *   interventions, mvlEpisodes, fairnessAudits, classInsights
 */

import * as admin from 'firebase-admin';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { callInternalInferenceJson, isInternalInferenceRequired } from './internalInferenceGateway';

const db = admin.firestore();
const TELEMETRY_COLLECTION = 'telemetryEvents';
const INTERACTION_COLLECTION = 'interactionEvents';
const BOS_PAYLOAD_KEY_BLOCKLIST = new Set([
  'prompt',
  'response',
  'transcript',
  'text',
  'content',
  'message',
  'question',
  'audio',
  'audiobase64',
  'audiobytes',
  'rawtext',
  'rawprompt',
]);
const BOS_PAYLOAD_MAX_DEPTH = 4;
const BOS_PAYLOAD_MAX_COLLECTION_LENGTH = 40;
const BOS_PAYLOAD_MAX_STRING_LENGTH = 256;
const SUPPORTED_LOCALES = new Set(['en', 'zh-CN', 'zh-TW', 'th']);

// ──────────────────────────────────────────────────────
// §4.2  Grade-band thresholds
// ──────────────────────────────────────────────────────

const M_DAGGER: Record<string, number> = {
  G1_3: 0.55,
  G4_6: 0.60,
  G7_9: 0.65,
  G10_12: 0.70,
};

function normalizeString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  return value as Record<string, unknown>;
}

function normalizeKey(key: string): string {
  return key.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
}

function normalizeBosActorRole(value: unknown): 'learner' | 'educator' | 'admin' {
  const normalized = normalizeString(value)?.toLowerCase();
  if (normalized === 'learner' || normalized === 'student') return 'learner';
  if (normalized === 'educator' || normalized === 'teacher') return 'educator';
  return 'admin';
}

function normalizeBosGradeBand(value: unknown): 'K_5' | 'G6_8' | 'G9_12' {
  const normalized = normalizeString(value)?.toLowerCase() || '';
  if (
    normalized === 'k_5' ||
    normalized === 'k-5' ||
    normalized === 'k5' ||
    normalized === 'g1_3' ||
    normalized === 'g4_6' ||
    normalized === 'grades_1_3' ||
    normalized === 'grades_4_6'
  ) {
    return 'K_5';
  }
  if (normalized === 'g6_8' || normalized === '6-8' || normalized === 'grades_7_9') {
    return 'G6_8';
  }
  if (normalized === 'g9_12' || normalized === '9-12' || normalized === 'grades_10_12') {
    return 'G9_12';
  }
  return 'G6_8';
}

function toCanonicalTelemetryRole(actorRole: 'learner' | 'educator' | 'admin'): 'student' | 'teacher' | 'admin' {
  if (actorRole === 'learner') return 'student';
  if (actorRole === 'educator') return 'teacher';
  return 'admin';
}

function toCanonicalTelemetryGradeBand(gradeBand: 'K_5' | 'G6_8' | 'G9_12'): 'k5' | 'ms' | 'hs' {
  if (gradeBand === 'K_5') return 'k5';
  if (gradeBand === 'G6_8') return 'ms';
  return 'hs';
}

function normalizeLocale(value: unknown): 'en' | 'zh-CN' | 'zh-TW' | 'th' {
  const normalized = normalizeString(value);
  if (!normalized) return 'en';
  if (SUPPORTED_LOCALES.has(normalized)) {
    return normalized as 'en' | 'zh-CN' | 'zh-TW' | 'th';
  }
  const lowered = normalized.toLowerCase();
  if (lowered.startsWith('zh-tw') || lowered.startsWith('zh-hk') || lowered.startsWith('zh-hant')) {
    return 'zh-TW';
  }
  if (lowered.startsWith('zh')) return 'zh-CN';
  if (lowered.startsWith('th')) return 'th';
  return 'en';
}

function resolveTelemetryEnv(): 'dev' | 'staging' | 'prod' {
  const raw = String(process.env.VIBE_ENV || process.env.APP_ENV || process.env.NODE_ENV || '')
    .trim()
    .toLowerCase();
  if (raw === 'production' || raw === 'prod') return 'prod';
  if (raw === 'staging' || raw === 'stage') return 'staging';
  return 'dev';
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

function randomId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
}

function resolveTraceId(request: CallableRequest, data: Record<string, unknown>): string {
  const payload = data.payload && typeof data.payload === 'object' && !Array.isArray(data.payload)
    ? data.payload as Record<string, unknown>
    : {};

  const candidates = [
    normalizeString(data.traceId),
    normalizeString(payload.traceId),
    normalizeString(toHeaderString(request.rawRequest?.headers?.['x-trace-id'] as string | string[] | undefined)),
    extractTraceIdFromHeader(
      toHeaderString(request.rawRequest?.headers?.['x-cloud-trace-context'] as string | string[] | undefined),
    ),
  ];

  for (const candidate of candidates) {
    if (candidate) return candidate;
  }
  return randomId('bos-trace');
}

function resolveRequestId(request: CallableRequest, data: Record<string, unknown>): string {
  const payload = data.payload && typeof data.payload === 'object' && !Array.isArray(data.payload)
    ? data.payload as Record<string, unknown>
    : {};
  return (
    normalizeString(data.requestId) ||
    normalizeString(payload.requestId) ||
    toHeaderString(request.rawRequest?.headers?.['x-request-id'] as string | string[] | undefined) ||
    randomId('bos-request')
  );
}

function shouldRedactBosPayloadKey(pathValue: string): boolean {
  const leaf = pathValue.split('.').pop() ?? pathValue;
  const normalized = normalizeKey(leaf.replace(/\[\d+\]/g, ''));
  return BOS_PAYLOAD_KEY_BLOCKLIST.has(normalized);
}

function sanitizeBosPayloadValue(
  value: unknown,
  pathValue: string,
  depth: number,
  redactedPaths: Set<string>,
): unknown {
  if (depth > BOS_PAYLOAD_MAX_DEPTH) {
    redactedPaths.add(`${pathValue}:depth_limit`);
    return null;
  }

  if (value === null || value === undefined) return null;

  if (typeof value === 'string') {
    if (shouldRedactBosPayloadKey(pathValue)) {
      redactedPaths.add(pathValue);
      return '[redacted]';
    }
    const trimmed = value.trim();
    if (/^data:audio\//i.test(trimmed) || /audio\/(wav|mpeg|mp3|ogg|webm)/i.test(trimmed)) {
      redactedPaths.add(`${pathValue}:audio_marker`);
      return '[redacted_audio]';
    }
    if (trimmed.length > 200 && /\s/.test(trimmed)) {
      redactedPaths.add(`${pathValue}:long_text`);
      return `[redacted_text_len_${trimmed.length}]`;
    }
    return trimmed.length > BOS_PAYLOAD_MAX_STRING_LENGTH
      ? `${trimmed.slice(0, BOS_PAYLOAD_MAX_STRING_LENGTH)}...`
      : trimmed;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value
      .slice(0, BOS_PAYLOAD_MAX_COLLECTION_LENGTH)
      .map((entry, index) => sanitizeBosPayloadValue(entry, `${pathValue}[${index}]`, depth + 1, redactedPaths));
  }

  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    let count = 0;
    for (const [key, nestedValue] of Object.entries(value as Record<string, unknown>)) {
      if (count >= BOS_PAYLOAD_MAX_COLLECTION_LENGTH) break;
      const nestedPath = pathValue ? `${pathValue}.${key}` : key;
      if (shouldRedactBosPayloadKey(nestedPath)) {
        redactedPaths.add(nestedPath);
        continue;
      }
      out[key] = sanitizeBosPayloadValue(nestedValue, nestedPath, depth + 1, redactedPaths);
      count += 1;
    }
    return out;
  }

  return String(value);
}

function sanitizeBosPayload(payload: unknown): { payload: Record<string, unknown>; redactedPaths: string[] } {
  const source = payload && typeof payload === 'object' && !Array.isArray(payload)
    ? payload as Record<string, unknown>
    : {};
  const redactedPaths = new Set<string>();
  const sanitized = sanitizeBosPayloadValue(source, 'payload', 0, redactedPaths);
  if (!sanitized || typeof sanitized !== 'object' || Array.isArray(sanitized)) {
    return { payload: {}, redactedPaths: Array.from(redactedPaths.values()) };
  }
  return {
    payload: sanitized as Record<string, unknown>,
    redactedPaths: Array.from(redactedPaths.values()),
  };
}

// ──────────────────────────────────────────────────────
// §2  FDM — Feature Detection Module (stub)
// ──────────────────────────────────────────────────────

interface FeatureVector {
  cognition: number;
  engagement: number;
  integrity: number;
  quality: { missingness: number; driftFlag: boolean; fusionFamiliesPresent: string[] };
}

interface VoiceUnderstandingObservation {
  intent: string;
  responseMode: string;
  complexity: string;
  emotionalState: string;
  needsScaffold: boolean;
  confidence: number;
}

interface BosLearningSnapshot {
  profileId: string;
  lastIntent: string;
  lastResponseMode: string;
  lastNeedsScaffold: boolean;
  lastEmotionalState: string;
  lastUnderstandingConfidence: number;
  needsScaffoldCount: number;
  frustrationSignalCount: number;
}

function readVoiceUnderstandingObservation(event: FirebaseFirestore.DocumentData): VoiceUnderstandingObservation | null {
  if (!event || typeof event !== 'object') return null;
  const payload = event.payload && typeof event.payload === 'object'
    ? event.payload as Record<string, unknown>
    : {};
  const source = normalizeString(payload.source)?.toLowerCase();
  if (source !== 'voice') return null;

  const confidenceRaw = payload.understandingConfidence;
  const confidence = typeof confidenceRaw === 'number'
    ? clamp(confidenceRaw)
    : clamp(Number(confidenceRaw ?? 0));
  if (!Number.isFinite(confidence) || confidence <= 0) return null;

  const intent = normalizeString(payload.understandingIntent) ?? 'general_support';
  const responseMode = normalizeString(payload.responseMode) ?? 'hint';
  const complexity = normalizeString(payload.complexity) ?? 'medium';
  const emotionalState = normalizeString(payload.emotionalState) ?? 'neutral';
  const needsScaffold = Boolean(payload.needsScaffold);

  return {
    intent,
    responseMode,
    complexity,
    emotionalState,
    needsScaffold,
    confidence,
  };
}

function toFiniteNumber(value: unknown, fallback: number = 0): number {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return numeric;
}

async function loadBosLearningSnapshot(siteId: string, learnerId: string): Promise<BosLearningSnapshot | null> {
  if (!siteId || !learnerId) return null;
  const profileId = `${siteId}__${learnerId}`;
  const snapshot = await db.collection('bosLearningProfiles').doc(profileId).get();
  if (!snapshot.exists) return null;

  const data = snapshot.data() ?? {};
  const learning = asRecord(data.learning) ?? {};
  const metrics = asRecord(data.metrics) ?? {};
  return {
    profileId,
    lastIntent: normalizeString(learning.lastIntent) ?? 'general_support',
    lastResponseMode: normalizeString(learning.lastResponseMode) ?? 'hint',
    lastNeedsScaffold: Boolean(learning.lastNeedsScaffold),
    lastEmotionalState: normalizeString(learning.lastEmotionalState) ?? 'neutral',
    lastUnderstandingConfidence: clamp(toFiniteNumber(learning.lastUnderstandingConfidence, 0)),
    needsScaffoldCount: Math.max(0, Math.floor(toFiniteNumber(metrics.needsScaffoldCount, 0))),
    frustrationSignalCount: Math.max(0, Math.floor(toFiniteNumber(metrics.frustrationSignalCount, 0))),
  };
}

function applyLearningSnapshotToIntervention(
  intervention: InterventionDecision,
  learningSnapshot: BosLearningSnapshot | null,
): InterventionDecision {
  if (!learningSnapshot) return intervention;
  const next: InterventionDecision = {
    ...intervention,
    reasonCodes: Array.from(new Set(intervention.reasonCodes)),
  };
  const persistentSupportNeed = learningSnapshot.lastNeedsScaffold ||
    learningSnapshot.lastEmotionalState === 'frustrated' ||
    learningSnapshot.lastUnderstandingConfidence < 0.58 ||
    learningSnapshot.frustrationSignalCount > 3;
  const autonomyReady = !learningSnapshot.lastNeedsScaffold &&
    learningSnapshot.lastUnderstandingConfidence >= 0.8 &&
    learningSnapshot.lastResponseMode === 'explain';

  if (persistentSupportNeed) {
    next.type = 'scaffold';
    next.mode = 'explain';
    if (next.salience === 'low') next.salience = 'medium';
    next.reasonCodes = Array.from(new Set([...next.reasonCodes, 'voice_learning_needs_scaffold']));
  } else if (autonomyReady) {
    if (next.type === 'scaffold' && next.mode === 'hint') {
      next.mode = 'verify';
    }
    next.reasonCodes = Array.from(new Set([...next.reasonCodes, 'voice_learning_autonomy_ready']));
  }

  return next;
}

/**
 * Extract feature vector from recent interaction events.
 * V1: simple heuristics. V2+: ML pipeline.
 */
async function extractFeatures(
  learnerId: string,
  sessionOccurrenceId: string,
  _windowSeconds: number = 300,
): Promise<FeatureVector> {
  // Query recent interaction events for this learner + session
  const eventsSnap = await db.collection('interactionEvents')
    .where('actorId', '==', learnerId)
    .where('sessionOccurrenceId', '==', sessionOccurrenceId)
    .orderBy('timestamp', 'desc')
    .limit(50)
    .get();

  const events = eventsSnap.docs.map(d => d.data());

  // V1 heuristic feature extraction + voice understanding adaptation
  const totalEvents = events.length;
  const checkpointSubmissions = events.filter(e => e.eventType === 'checkpoint_submitted').length;
  const aiHelpUsed = events.filter(e => e.eventType === 'ai_help_used').length;
  const idleDetected = events.filter(e => e.eventType === 'idle_detected').length;

  const voiceSignals = events
    .map((event) => readVoiceUnderstandingObservation(event))
    .filter((event): event is VoiceUnderstandingObservation => Boolean(event));
  const voiceSignalCount = voiceSignals.length;
  const avgUnderstandingConfidence = voiceSignalCount > 0
    ? voiceSignals.reduce((sum, signal) => sum + signal.confidence, 0) / voiceSignalCount
    : 0;
  const scaffoldSignals = voiceSignals.filter((signal) => signal.needsScaffold).length;
  const frustrationSignals = voiceSignals.filter((signal) => signal.emotionalState === 'frustrated').length;
  const explainSignals = voiceSignals.filter((signal) =>
    signal.intent === 'explain_request' ||
    signal.intent === 'reflection' ||
    signal.responseMode === 'explain',
  ).length;
  const hintSignals = voiceSignals.filter((signal) =>
    signal.intent === 'hint_request' ||
    signal.responseMode === 'hint',
  ).length;

  // Cognition proxy: checkpoint success rate blended with voice understanding confidence.
  let cognition = totalEvents > 0
    ? Math.min(1.0, checkpointSubmissions / Math.max(totalEvents * 0.3, 1))
    : 0.5;
  if (voiceSignalCount > 0) {
    const scaffoldRatio = scaffoldSignals / Math.max(voiceSignalCount, 1);
    cognition = clamp((cognition * 0.75) + (avgUnderstandingConfidence * 0.25) - (scaffoldRatio * 0.12));
  }

  // Engagement proxy: inverse idle rate adjusted with voice frustration and participation.
  let engagement = totalEvents > 0
    ? Math.max(0.0, 1.0 - (idleDetected / Math.max(totalEvents, 1)))
    : 0.5;
  if (voiceSignalCount > 0) {
    const frustrationRatio = frustrationSignals / Math.max(voiceSignalCount, 1);
    const participationBoost = Math.min(0.12, (voiceSignalCount / Math.max(totalEvents, 1)) * 0.12);
    engagement = clamp(engagement + participationBoost - (frustrationRatio * 0.2));
  }

  // Integrity proxy: lower if heavy AI assistance, softened by explain/reflection evidence.
  let integrity = totalEvents > 0
    ? Math.max(0.0, 1.0 - (aiHelpUsed / Math.max(totalEvents * 0.5, 1)))
    : 0.5;
  if (voiceSignalCount > 0) {
    const dependencyRatio = hintSignals / Math.max(voiceSignalCount, 1);
    const independenceRatio = explainSignals / Math.max(voiceSignalCount, 1);
    integrity = clamp(integrity + (independenceRatio * 0.1) - (dependencyRatio * 0.14));
  }

  const fusionFamiliesPresent = totalEvents > 0 ? ['interaction'] : [];
  if (voiceSignalCount > 0) {
    fusionFamiliesPresent.push('voice_understanding');
  }

  return {
    cognition: clamp(cognition),
    engagement: clamp(engagement),
    integrity: clamp(integrity),
    quality: {
      missingness: totalEvents === 0 ? 1.0 : 0.0,
      driftFlag: false,
      fusionFamiliesPresent,
    },
  };
}

// ──────────────────────────────────────────────────────
// §3  EKF-lite State Estimator
// ──────────────────────────────────────────────────────

interface StateEstimate {
  x_hat: { cognition: number; engagement: number; integrity: number };
  P: { diag: number[]; trace: number; confidence: number };
}

/**
 * EKF-lite: simplified Kalman update.
 * x_hat_{t+1} = α * x_hat_t + (1 − α) * y_t
 * P updated via simple decay.
 */
function ekfLiteUpdate(
  prior: StateEstimate | null,
  observation: FeatureVector,
  alpha: number = 0.7,
): StateEstimate {
  if (!prior) {
    // Initialize from first observation
    return {
      x_hat: {
        cognition: observation.cognition,
        engagement: observation.engagement,
        integrity: observation.integrity,
      },
      P: { diag: [0.25, 0.25, 0.25], trace: 0.75, confidence: 0.25 },
    };
  }

  const x = prior.x_hat;
  const y = observation;

  const newCognition = clamp(alpha * x.cognition + (1 - alpha) * y.cognition);
  const newEngagement = clamp(alpha * x.engagement + (1 - alpha) * y.engagement);
  const newIntegrity = clamp(alpha * x.integrity + (1 - alpha) * y.integrity);

  // Uncertainty shrinks with each observation
  const decayFactor = 0.9;
  const newDiag = prior.P.diag.map(d => Math.max(0.01, d * decayFactor));
  const newTrace = newDiag.reduce((a, b) => a + b, 0);
  const newConfidence = 1 - newTrace / 3;

  return {
    x_hat: { cognition: newCognition, engagement: newEngagement, integrity: newIntegrity },
    P: { diag: newDiag, trace: newTrace, confidence: newConfidence },
  };
}

// ──────────────────────────────────────────────────────
// §4  Policy Engine — Autonomy-regularized control
// ──────────────────────────────────────────────────────

interface InterventionDecision {
  type: 'nudge' | 'scaffold' | 'handoff' | 'revisit' | 'pace';
  salience: 'low' | 'medium' | 'high';
  mode?: 'hint' | 'verify' | 'explain' | 'debug';
  reasonCodes: string[];
  policy: { lambda: number; m_dagger: number; highAssist: boolean; omega: number };
  triggerMvl: boolean;
  mvlReason?: string;
}

function computeIntervention(
  state: StateEstimate,
  gradeBand: string,
  lambda: number = 0.5,
): InterventionDecision {
  const x = state.x_hat;
  const mDagger = M_DAGGER[gradeBand] ?? 0.60;
  const reasonCodes: string[] = [];

  // Determine intervention type based on state
  let type: InterventionDecision['type'] = 'nudge';
  let salience: InterventionDecision['salience'] = 'low';
  let mode: InterventionDecision['mode'];
  let triggerMvl = false;
  let mvlReason: string | undefined;

  if (x.cognition < 0.3) {
    type = 'scaffold';
    mode = 'explain';
    salience = 'high';
    reasonCodes.push('low_cognition');
  } else if (x.cognition < 0.5) {
    type = 'scaffold';
    mode = 'hint';
    salience = 'medium';
    reasonCodes.push('moderate_cognition');
  }

  if (x.engagement < 0.3) {
    type = 'pace';
    salience = 'high';
    reasonCodes.push('low_engagement');
  }

  if (x.integrity < mDagger) {
    reasonCodes.push('integrity_below_threshold');
    triggerMvl = true;
    mvlReason = `integrity ${x.integrity.toFixed(2)} < m_dagger ${mDagger.toFixed(2)}`;
  }

  // Compute autonomy cost
  const isHighAssist = salience === 'high' || (type === 'scaffold' && mode === 'hint');
  const omega = isHighAssist ? Math.max(0, mDagger - x.integrity) : 0;

  return {
    type,
    salience,
    mode,
    reasonCodes,
    policy: { lambda, m_dagger: mDagger, highAssist: isHighAssist, omega },
    triggerMvl,
    mvlReason,
  };
}

// ──────────────────────────────────────────────────────
// §8  MVL Scoring
// ──────────────────────────────────────────────────────

async function scoreMvlEpisode(episodeId: string): Promise<string> {
  const doc = await db.collection('mvlEpisodes').doc(episodeId).get();
  if (!doc.exists) throw new HttpsError('not-found', 'MVL episode not found');

  const data = doc.data()!;
  const evidenceIds: string[] = data.evidenceEventIds || [];

  // V1: pass if at least 2 evidence items and resolution not already set
  if (data.resolution) return data.resolution;

  let resolution: string;
  if (evidenceIds.length >= 2) {
    resolution = 'passed';
  } else if (evidenceIds.length >= 1) {
    resolution = 'needs_more_evidence';
  } else {
    resolution = 'failed';
  }

  await db.collection('mvlEpisodes').doc(episodeId).update({
    resolution,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return resolution;
}

// ──────────────────────────────────────────────────────
// §6-§7  Risk Scoring (Reliability + Autonomy)
// ──────────────────────────────────────────────────────

interface AutonomyRiskFromEvents {
  riskType: 'autonomy';
  signals: string[];
  riskScore: number;
  threshold: number;
}

/**
 * Compute autonomy risk from pre-fetched event data (Math Contract §7).
 * Pure function — no I/O.
 */
function computeAutonomyRiskFromEvents(
  _learnerId: string,
  _sessionOccurrenceId: string,
  state: StateEstimate,
  gradeBand: string,
  events: FirebaseFirestore.DocumentData[],
): AutonomyRiskFromEvents {
  const signals: string[] = [];
  let riskScore = 0;
  const totalEvents = events.length;

  if (totalEvents < 3) {
    return { riskType: 'autonomy', signals, riskScore: 0, threshold: 0.5 };
  }

  // Signal 1: Heavy AI use — >40% of events are ai_help_*
  const aiEvents = events.filter(e =>
    e.eventType === 'ai_help_used' || e.eventType === 'ai_help_opened'
  ).length;
  if (aiEvents / totalEvents > 0.4) {
    signals.push('heavy_ai_use');
    riskScore += 0.25;
  }

  // Signal 2: Rapid submit after AI help
  for (let i = 0; i < events.length - 1; i++) {
    if (events[i].eventType === 'checkpoint_submitted' && events[i + 1].eventType === 'ai_help_used') {
      signals.push('rapid_submit');
      riskScore += 0.2;
      break;
    }
  }

  // Signal 3: Verification gap — no explain_it_back after AI use
  const hasExplainBack = events.some(e => e.eventType === 'explain_it_back_submitted');
  if (aiEvents > 0 && !hasExplainBack) {
    signals.push('verification_gap');
    riskScore += 0.15;
  }

  // Signal 4: Repeated hints without independent attempt
  const hintCount = events.filter(e => e.eventType === 'ai_help_used').length;
  const attempts = events.filter(e =>
    e.eventType === 'checkpoint_submitted' || e.eventType === 'artifact_submitted'
  ).length;
  if (hintCount > 3 && attempts === 0) {
    signals.push('repeated_hints_no_attempt');
    riskScore += 0.25;
  }

  // Signal 5: Low integrity state
  const mDagger = M_DAGGER[gradeBand] ?? 0.60;
  if (state.x_hat.integrity < mDagger) {
    signals.push('low_integrity_state');
    riskScore += 0.15;
  }

  return {
    riskType: 'autonomy',
    signals: [...new Set(signals)],
    riskScore: Math.min(1.0, Math.round(riskScore * 1000) / 1000),
    threshold: 0.5,
  };
}

// ──────────────────────────────────────────────────────
// Callable Cloud Functions
// ──────────────────────────────────────────────────────

/**
 * Endpoint 1: Ingest BOS interaction event
 */
export const bosIngestEvent = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const data = request.data && typeof request.data === 'object'
      ? request.data as Record<string, unknown>
      : {};

    const eventType = normalizeString(data.eventType);
    const siteId = normalizeString(data.siteId);
    if (!eventType || !siteId) {
      throw new HttpsError('invalid-argument', 'eventType and siteId required');
    }

    const actorRole = normalizeBosActorRole(data.actorRole);
    const gradeBand = normalizeBosGradeBand(data.gradeBand);
    const locale = normalizeLocale(data.locale ?? (data.payload as Record<string, unknown> | undefined)?.locale);
    const requestId = resolveRequestId(request, data);
    const traceId = resolveTraceId(request, data);
    const telemetryEnv = resolveTelemetryEnv();
    const timestampIso = new Date().toISOString();
    const sessionOccurrenceId = normalizeString(data.sessionOccurrenceId) ?? null;
    const missionId = normalizeString(data.missionId) ?? null;
    const checkpointId = normalizeString(data.checkpointId) ?? null;
    const { payload: sanitizedPayload, redactedPaths } = sanitizeBosPayload(data.payload);

    const eventDoc: Record<string, unknown> = {
      event: eventType,
      eventType,
      requestId,
      traceId,
      service: 'scholesa-ai',
      env: telemetryEnv,
      locale,
      timestampIso,
      actorId: uid,
      actorRole,
      role: toCanonicalTelemetryRole(actorRole),
      siteId,
      gradeBand,
      gradeBandCanonical: toCanonicalTelemetryGradeBand(gradeBand),
      sessionOccurrenceId,
      missionId,
      checkpointId,
      payload: sanitizedPayload,
      context: {
        source: 'bos-runtime',
        locale,
        requestId,
        traceId,
      },
      redactionApplied: redactedPaths.length > 0,
      redactedPathCount: redactedPaths.length,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection(INTERACTION_COLLECTION).add(eventDoc);

    await db.collection(TELEMETRY_COLLECTION).add({
      event: eventType,
      eventType,
      userId: uid,
      role: actorRole === 'learner' ? 'learner' : actorRole === 'educator' ? 'educator' : 'site',
      roleCanonical: toCanonicalTelemetryRole(actorRole),
      actorRole,
      service: 'scholesa-ai',
      env: telemetryEnv,
      siteId,
      gradeBand: toCanonicalTelemetryGradeBand(gradeBand),
      locale,
      traceId,
      metadata: {
        requestId,
        traceId,
        service: 'scholesa-ai',
        env: telemetryEnv,
        siteId,
        role: toCanonicalTelemetryRole(actorRole),
        gradeBand: toCanonicalTelemetryGradeBand(gradeBand),
        locale,
        eventType,
        timestamp: timestampIso,
        source: 'bos-runtime',
        sessionOccurrenceId,
        missionId,
        checkpointId,
        redactionApplied: redactedPaths.length > 0,
        redactedPathCount: redactedPaths.length,
      },
      timestampIso,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ok: true,
      traceId,
      requestId,
      locale,
      redactionApplied: redactedPaths.length > 0,
      redactedPathCount: redactedPaths.length,
    };
  }
);

/**
 * Endpoint 2: Get current orchestration state for a learner session
 */
export const bosGetOrchestrationState = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { learnerId, sessionOccurrenceId } = request.data;
    const targetLearnerId = learnerId || uid;
    const docId = `${targetLearnerId}_${sessionOccurrenceId}`;

    const doc = await db.collection('orchestrationStates').doc(docId).get();
    if (!doc.exists) {
      return { state: null, message: 'No orchestration state found' };
    }

    return { state: doc.data() };
  }
);

/**
 * Endpoint 3: Run FDM + Estimator + Policy → return intervention
 */
export const bosGetIntervention = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const requestData = asRecord(request.data) ?? {};
    const learnerId = normalizeString(requestData.learnerId);
    const sessionOccurrenceId = normalizeString(requestData.sessionOccurrenceId);
    const siteId = normalizeString(requestData.siteId);
    const gradeBand = normalizeString(requestData.gradeBand);
    const targetLearnerId = learnerId || uid;
    if (!sessionOccurrenceId || !siteId) {
      throw new HttpsError('invalid-argument', 'sessionOccurrenceId and siteId required');
    }

    // Step 1: Extract features (FDM)
    const features = await extractFeatures(targetLearnerId, sessionOccurrenceId);

    // Save feature snapshot
    await db.collection('fdmFeatures').add({
      siteId,
      learnerId: targetLearnerId,
      sessionOccurrenceId,
      window: '5m',
      features: { cognition: features.cognition, engagement: features.engagement, integrity: features.integrity },
      quality: features.quality,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Step 2: Load prior state & update (Estimator)
    const stateDocId = `${targetLearnerId}_${sessionOccurrenceId}`;
    const priorDoc = await db.collection('orchestrationStates').doc(stateDocId).get();
    const priorState: StateEstimate | null = priorDoc.exists
      ? { x_hat: priorDoc.data()!.x_hat, P: priorDoc.data()!.P }
      : null;

    const newState = ekfLiteUpdate(priorState, features);

    // Save updated state
    await db.collection('orchestrationStates').doc(stateDocId).set({
      siteId,
      learnerId: targetLearnerId,
      sessionOccurrenceId,
      x_hat: newState.x_hat,
      P: newState.P,
      model: { estimator: 'ekf-lite', version: '0.1.0', Q_version: 'v1', R_version: 'v1' },
      fusion: {
        familiesPresent: features.quality.fusionFamiliesPresent,
        sensorFusionMet: features.quality.fusionFamiliesPresent.length >= 2,
      },
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Step 3: Compute intervention (Policy)
    const gBand = gradeBand || 'G4_6';
    const learningSnapshot = await loadBosLearningSnapshot(siteId, targetLearnerId);
    let intervention = applyLearningSnapshotToIntervention(
      computeIntervention(newState, gBand),
      learningSnapshot,
    );
    const traceId = resolveTraceId(request, requestData);
    const requestId = resolveRequestId(request, requestData);
    const tokenClaims = asRecord(request.auth?.token);
    const actorRole = normalizeBosActorRole(tokenClaims?.role ?? requestData.actorRole);
    const locale = normalizeLocale(requestData.locale ?? tokenClaims?.locale);
    const canonicalRole = toCanonicalTelemetryRole(actorRole);
    const canonicalGradeBand = toCanonicalTelemetryGradeBand(normalizeBosGradeBand(gBand));
    let bosModelVersion = 'bos-policy-local-v1';
    let bosInferenceMeta: Record<string, unknown> = {
      service: 'bos',
      route: 'local',
      authMode: 'none',
      reason: 'not_attempted',
    };

    const bosInference = await callInternalInferenceJson<Record<string, unknown>, Record<string, unknown>>({
      service: 'bos',
      body: {
        learnerId: targetLearnerId,
        sessionOccurrenceId,
        siteId,
        gradeBand: gBand,
        state: newState,
        features: {
          cognition: features.cognition,
          engagement: features.engagement,
          integrity: features.integrity,
          quality: features.quality,
        },
        learningSnapshot: learningSnapshot ? {
          lastIntent: learningSnapshot.lastIntent,
          lastResponseMode: learningSnapshot.lastResponseMode,
          lastNeedsScaffold: learningSnapshot.lastNeedsScaffold,
          lastEmotionalState: learningSnapshot.lastEmotionalState,
          lastUnderstandingConfidence: learningSnapshot.lastUnderstandingConfidence,
          needsScaffoldCount: learningSnapshot.needsScaffoldCount,
          frustrationSignalCount: learningSnapshot.frustrationSignalCount,
        } : null,
        policy: intervention,
      },
      context: {
        traceId,
        requestId,
        siteId,
        role: canonicalRole,
        gradeBand: canonicalGradeBand,
        locale,
        policyVersion: 'bos-policy-2026-02-25',
        callerService: 'scholesa-ai',
      },
    });
    if (isInternalInferenceRequired() && !bosInference.ok) {
      throw new HttpsError('unavailable', 'Internal BOS inference is required but unavailable.');
    }

    const inferenceRoot = bosInference.ok ? asRecord(bosInference.data) : undefined;
    if (inferenceRoot) {
      const inferredVersion = normalizeString(
        inferenceRoot.modelVersion ?? inferenceRoot.model ?? asRecord(inferenceRoot.metadata)?.modelVersion,
      );
      if (inferredVersion) {
        bosModelVersion = inferredVersion;
      }
    }

    if (bosInference.ok) {
      const candidate = asRecord(inferenceRoot?.intervention) ??
        asRecord(inferenceRoot?.policy) ??
        asRecord(inferenceRoot?.recommendation) ??
        inferenceRoot;
      if (candidate) {
        const modelConfidence = clamp(toFiniteNumber(
          candidate.confidence ?? asRecord(candidate.metadata)?.confidence,
          0.5,
        ));
        const allowOverride = modelConfidence >= 0.35;
        if (allowOverride) {
          const typeCandidate = normalizeString(candidate.type)?.toLowerCase();
          if (
            typeCandidate === 'nudge' ||
            typeCandidate === 'scaffold' ||
            typeCandidate === 'handoff' ||
            typeCandidate === 'revisit' ||
            typeCandidate === 'pace'
          ) {
            intervention.type = typeCandidate;
          }

          const salienceCandidate = normalizeString(candidate.salience)?.toLowerCase();
          if (salienceCandidate === 'low' || salienceCandidate === 'medium' || salienceCandidate === 'high') {
            intervention.salience = salienceCandidate;
          }

          const modeCandidate = normalizeString(candidate.mode)?.toLowerCase();
          if (
            modeCandidate === 'hint' ||
            modeCandidate === 'verify' ||
            modeCandidate === 'explain' ||
            modeCandidate === 'debug'
          ) {
            intervention.mode = modeCandidate;
          }

          const reasonCodes = Array.isArray(candidate.reasonCodes)
            ? candidate.reasonCodes
              .map((reason) => normalizeString(reason))
              .filter((reason): reason is string => Boolean(reason))
              .slice(0, 6)
            : [];
          if (reasonCodes.length > 0) {
            intervention.reasonCodes = Array.from(new Set([...intervention.reasonCodes, ...reasonCodes]));
          }

          if (candidate.triggerMvl === true) {
            intervention.triggerMvl = true;
          }
          const modelMvlReason = normalizeString(candidate.mvlReason);
          if (modelMvlReason && intervention.triggerMvl) {
            intervention.mvlReason = modelMvlReason.slice(0, 240);
          }
        }

        bosInferenceMeta = {
          service: 'bos',
          route: bosInference.meta.route,
          authMode: bosInference.meta.authMode,
          statusCode: bosInference.meta.statusCode ?? null,
          errorCode: bosInference.errorCode ?? null,
          reason: allowOverride ? 'policy_override_applied' : 'policy_override_skipped_low_confidence',
          modelConfidence,
          endpoint: bosInference.meta.endpoint ?? null,
        };
      } else {
        if (isInternalInferenceRequired()) {
          throw new HttpsError('unavailable', 'Internal BOS policy response did not include an intervention payload.');
        }
        bosInferenceMeta = {
          service: 'bos',
          route: bosInference.meta.route,
          authMode: bosInference.meta.authMode,
          statusCode: bosInference.meta.statusCode ?? null,
          errorCode: bosInference.errorCode ?? null,
          reason: 'no_policy_payload',
          endpoint: bosInference.meta.endpoint ?? null,
        };
      }
    } else {
      bosInferenceMeta = {
        service: 'bos',
        route: bosInference.meta.route,
        authMode: bosInference.meta.authMode,
        statusCode: bosInference.meta.statusCode ?? null,
        errorCode: bosInference.errorCode ?? null,
        reason: 'internal_call_failed',
        endpoint: bosInference.meta.endpoint ?? null,
      };
    }

    // Step 3b: Compute autonomy risk from behavioral signals (Math Contract §7)
    const autonomyRiskResult = computeAutonomyRiskFromEvents(targetLearnerId, sessionOccurrenceId, newState, gBand,
      (await db.collection('interactionEvents')
        .where('actorId', '==', targetLearnerId)
        .where('sessionOccurrenceId', '==', sessionOccurrenceId)
        .orderBy('timestamp', 'desc')
        .limit(20)
        .get()).docs.map(d => d.data()),
    );

    // Step 3c: Compute reliability risk proxy (Math Contract §6)
    const reliabilityRiskResult = {
      riskType: 'reliability' as const,
      method: 'sep' as const,
      K: 1, M: 1, H_sem: 0,
      riskScore: Math.round((1 - newState.P.confidence) * 0.5 * 1000) / 1000,
      threshold: 0.6,
    };

    // Augment intervention with risk data
    const riskSources: string[] = [];
    const mDaggerVal = M_DAGGER[gBand] ?? 0.60;
    if (newState.x_hat.integrity < mDaggerVal) riskSources.push('integrity_below_threshold');
    if (autonomyRiskResult.riskScore > autonomyRiskResult.threshold) riskSources.push('high_autonomy_risk');
    if (reliabilityRiskResult.riskScore > reliabilityRiskResult.threshold) riskSources.push('high_reliability_risk');

    // Sensor fusion: override triggerMvl if ≥2 risk sources (even if policy didn't trigger it)
    const shouldTriggerMvl = intervention.triggerMvl || riskSources.length >= 2;
    const mvlReason = shouldTriggerMvl
      ? (riskSources.length >= 2 ? riskSources.join(' + ') : (intervention.mvlReason || 'policy_triggered'))
      : undefined;

    // Save intervention with risk data
    const interventionDoc = {
      siteId,
      learnerId: targetLearnerId,
      sessionOccurrenceId,
      gradeBand: gBand,
      gradeBandCanonical: canonicalGradeBand,
      roleCanonical: canonicalRole,
      locale,
      traceId,
      requestId,
      ...intervention,
      triggerMvl: shouldTriggerMvl,
      mvlReason,
      policyModelVersion: bosModelVersion,
      inference: bosInferenceMeta,
      learningSignals: learningSnapshot ? {
        profileId: learningSnapshot.profileId,
        lastIntent: learningSnapshot.lastIntent,
        lastResponseMode: learningSnapshot.lastResponseMode,
        lastNeedsScaffold: learningSnapshot.lastNeedsScaffold,
        lastEmotionalState: learningSnapshot.lastEmotionalState,
        lastUnderstandingConfidence: learningSnapshot.lastUnderstandingConfidence,
      } : null,
      autonomyRisk: autonomyRiskResult,
      reliabilityRisk: reliabilityRiskResult,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection('interventions').add(interventionDoc);

    // Step 4: If MVL triggered, create episode with risk data (Math Contract §6-§7)
    let mvlEpisodeId: string | null = null;
    if (shouldTriggerMvl) {
      // Check for existing active MVL before creating a new one
      const existingMvl = await db.collection('mvlEpisodes')
        .where('learnerId', '==', targetLearnerId)
        .where('sessionOccurrenceId', '==', sessionOccurrenceId)
        .where('resolution', '==', null)
        .limit(1)
        .get();

      if (existingMvl.empty) {
        const mvlRef = await db.collection('mvlEpisodes').add({
          siteId,
          learnerId: targetLearnerId,
          sessionOccurrenceId,
          triggerReason: mvlReason || 'policy_triggered',
          riskSources,
          reliability: reliabilityRiskResult,
          autonomy: autonomyRiskResult,
          evidenceEventIds: [],
          resolution: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        mvlEpisodeId = mvlRef.id;
      } else {
        mvlEpisodeId = existingMvl.docs[0].id;
      }
    }

    return {
      intervention: { ...intervention, triggerMvl: shouldTriggerMvl, mvlReason },
      state: newState,
      risk: {
        reliability: reliabilityRiskResult,
        autonomy: autonomyRiskResult,
        riskSources,
      },
      mvlEpisodeId,
      inference: bosInferenceMeta,
      modelVersion: bosModelVersion,
      traceId,
      requestId,
      locale,
      learningSignals: learningSnapshot ? {
        profileId: learningSnapshot.profileId,
        lastIntent: learningSnapshot.lastIntent,
        lastResponseMode: learningSnapshot.lastResponseMode,
        lastNeedsScaffold: learningSnapshot.lastNeedsScaffold,
        lastEmotionalState: learningSnapshot.lastEmotionalState,
        lastUnderstandingConfidence: learningSnapshot.lastUnderstandingConfidence,
      } : null,
    };
  }
);

/**
 * Endpoint 4: Score an MVL episode
 */
export const bosScoreMvl = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { episodeId } = request.data;
    if (!episodeId) throw new HttpsError('invalid-argument', 'episodeId required');

    const resolution = await scoreMvlEpisode(episodeId);
    return { resolution };
  }
);

/**
 * Endpoint 5: Submit evidence to an MVL episode
 */
export const bosSubmitMvlEvidence = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { episodeId, eventIds } = request.data;
    if (!episodeId || !eventIds?.length) {
      throw new HttpsError('invalid-argument', 'episodeId and eventIds required');
    }

    await db.collection('mvlEpisodes').doc(episodeId).update({
      evidenceEventIds: admin.firestore.FieldValue.arrayUnion(...eventIds),
    });

    return { ok: true };
  }
);

/**
 * Endpoint 6: Teacher override MVL
 */
export const bosTeacherOverrideMvl = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { episodeId, resolution, reason } = request.data;
    if (!episodeId || !resolution) {
      throw new HttpsError('invalid-argument', 'episodeId and resolution required');
    }

    await db.collection('mvlEpisodes').doc(episodeId).update({
      resolution,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      teacherOverride: {
        teacherId: uid,
        reason: reason || '',
        overriddenAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    return { ok: true };
  }
);

/**
 * Endpoint 7: Get class insights for an educator
 */
export const bosGetClassInsights = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { sessionOccurrenceId, siteId } = request.data;
    if (!sessionOccurrenceId || !siteId) {
      throw new HttpsError('invalid-argument', 'sessionOccurrenceId and siteId required');
    }

    // Fetch all orchestration states for this session
    const statesSnap = await db.collection('orchestrationStates')
      .where('sessionOccurrenceId', '==', sessionOccurrenceId)
      .where('siteId', '==', siteId)
      .get();

    const learners = statesSnap.docs.map(d => {
      const data = d.data();
      return {
        learnerId: data.learnerId,
        x_hat: data.x_hat,
        P: data.P,
        lastUpdatedAt: data.lastUpdatedAt,
      };
    });

    // Aggregate stats
    const count = learners.length;
    const avgCognition = count > 0 ? learners.reduce((s, l) => s + (l.x_hat?.cognition ?? 0.5), 0) / count : 0;
    const avgEngagement = count > 0 ? learners.reduce((s, l) => s + (l.x_hat?.engagement ?? 0.5), 0) / count : 0;
    const avgIntegrity = count > 0 ? learners.reduce((s, l) => s + (l.x_hat?.integrity ?? 0.5), 0) / count : 0;

    // Fetch active MVL episodes
    const activeMvls = await db.collection('mvlEpisodes')
      .where('sessionOccurrenceId', '==', sessionOccurrenceId)
      .where('siteId', '==', siteId)
      .where('resolution', '==', null)
      .get();

    return {
      sessionOccurrenceId,
      siteId,
      learnerCount: count,
      averages: { cognition: avgCognition, engagement: avgEngagement, integrity: avgIntegrity },
      activeMvlCount: activeMvls.size,
      learners,
    };
  }
);

/**
 * Endpoint 8: Contestability — request + resolve
 */
export const bosContestability = onCall(
  { region: 'us-central1' },
  async (request: CallableRequest) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Auth required');

    const { action, episodeId, reason, resolution } = request.data;

    if (action === 'request') {
      if (!episodeId) throw new HttpsError('invalid-argument', 'episodeId required');

      await db.collection('mvlEpisodes').doc(episodeId).update({
        contestability: {
          requestedBy: uid,
          reason: reason || '',
          requestedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'pending',
        },
      });
      return { ok: true, status: 'pending' };

    } else if (action === 'resolve') {
      if (!episodeId || !resolution) {
        throw new HttpsError('invalid-argument', 'episodeId and resolution required');
      }

      await db.collection('mvlEpisodes').doc(episodeId).update({
        'contestability.status': 'resolved',
        'contestability.resolvedBy': uid,
        'contestability.resolution': resolution,
        'contestability.resolvedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      return { ok: true, status: 'resolved' };

    } else {
      throw new HttpsError('invalid-argument', 'action must be "request" or "resolve"');
    }
  }
);

// ──────────────────────────────────────────────────────
// Utility
// ──────────────────────────────────────────────────────

function clamp(v: number, lo = 0.0, hi = 1.0): number {
  return Math.max(lo, Math.min(hi, v));
}
