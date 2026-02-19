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

const db = admin.firestore();

// ──────────────────────────────────────────────────────
// §4.2  Grade-band thresholds
// ──────────────────────────────────────────────────────

const M_DAGGER: Record<string, number> = {
  G1_3: 0.55,
  G4_6: 0.60,
  G7_9: 0.65,
  G10_12: 0.70,
};

// ──────────────────────────────────────────────────────
// §2  FDM — Feature Detection Module (stub)
// ──────────────────────────────────────────────────────

interface FeatureVector {
  cognition: number;
  engagement: number;
  integrity: number;
  quality: { missingness: number; driftFlag: boolean; fusionFamiliesPresent: string[] };
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

  // V1 heuristic feature extraction
  const totalEvents = events.length;
  const checkpointSubmissions = events.filter(e => e.eventType === 'checkpoint_submitted').length;
  const aiHelpUsed = events.filter(e => e.eventType === 'ai_help_used').length;
  const idleDetected = events.filter(e => e.eventType === 'idle_detected').length;

  // Cognition proxy: checkpoint success rate
  const cognition = totalEvents > 0
    ? Math.min(1.0, checkpointSubmissions / Math.max(totalEvents * 0.3, 1))
    : 0.5;

  // Engagement proxy: inverse idle rate
  const engagement = totalEvents > 0
    ? Math.max(0.0, 1.0 - (idleDetected / Math.max(totalEvents, 1)))
    : 0.5;

  // Integrity proxy: lower if heavy AI assistance
  const integrity = totalEvents > 0
    ? Math.max(0.0, 1.0 - (aiHelpUsed / Math.max(totalEvents * 0.5, 1)))
    : 0.5;

  return {
    cognition: clamp(cognition),
    engagement: clamp(engagement),
    integrity: clamp(integrity),
    quality: {
      missingness: totalEvents === 0 ? 1.0 : 0.0,
      driftFlag: false,
      fusionFamiliesPresent: totalEvents > 0 ? ['interaction'] : [],
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

    const { eventType, siteId, actorRole, gradeBand, sessionOccurrenceId, missionId, checkpointId, payload } = request.data;
    if (!eventType || !siteId) throw new HttpsError('invalid-argument', 'eventType and siteId required');

    const eventDoc = {
      eventType,
      siteId,
      actorId: uid,
      actorRole: actorRole || 'learner',
      gradeBand: gradeBand || 'G4_6',
      sessionOccurrenceId: sessionOccurrenceId || null,
      missionId: missionId || null,
      checkpointId: checkpointId || null,
      payload: payload || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('interactionEvents').add(eventDoc);

    return { ok: true };
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

    const { learnerId, sessionOccurrenceId, siteId, gradeBand } = request.data;
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
    const intervention = computeIntervention(newState, gBand);

    // Save intervention
    const interventionDoc = {
      siteId,
      learnerId: targetLearnerId,
      sessionOccurrenceId,
      gradeBand: gBand,
      ...intervention,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection('interventions').add(interventionDoc);

    // Step 4: If MVL triggered, create episode
    if (intervention.triggerMvl) {
      await db.collection('mvlEpisodes').add({
        siteId,
        learnerId: targetLearnerId,
        sessionOccurrenceId,
        triggerReason: intervention.mvlReason || 'policy_triggered',
        evidenceEventIds: [],
        resolution: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { intervention, state: newState };
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
