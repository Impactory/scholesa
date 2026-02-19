import { createHmac } from 'crypto';
import { onCall, onRequest, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret, defineString } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

admin.initializeApp();

// Export telemetry aggregation functions
export {
  aggregateDailyTelemetry,
  aggregateWeeklyTelemetry,
  triggerTelemetryAggregation,
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
  bosContestability,
} from './bosRuntime';

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
      apiVersion: '2025-12-15.clover', // Latest Stripe API version
      typescript: true,
    });
  }
  return stripeClient;
}

type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';

interface UserRecord {
  email?: string;
  displayName?: string;
  role?: Role;
  siteIds?: string[];
  activeSiteId?: string;
  isActive?: boolean;
  updatedAt?: FirebaseFirestore.FieldValue | number;
}

const USERS_COLLECTION = 'users';
const AUDIT_COLLECTION = 'auditLogs';
const TELEMETRY_COLLECTION = 'telemetryEvents';
const ORDERS_COLLECTION = 'orders';
const ENTITLEMENTS_COLLECTION = 'entitlements';
const NOTIFICATION_REQUESTS_COLLECTION = 'notificationRequests';
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
  'cms.page.viewed',
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
  'nudge.accepted',
  'nudge.dismissed',
  'nudge.snoozed',
  'educator.feedback.submitted',
  'support.intervention.logged',
  'motivation.insight.viewed',
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
]);

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
  if (!data || data.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }
  return { uid: authUid, user: data };
}

async function sendNotification(payload: { channel: string; threadId: string; messageId: string; siteId: string }) {
  const endpoint = notifyEndpoint.value();
  const apiKey = notifyApiKey.value();
  if (!endpoint || !apiKey) {
    throw new Error('Notification provider not configured');
  }

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      channel: payload.channel,
      threadId: payload.threadId,
      messageId: payload.messageId,
      siteId: payload.siteId,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Notify failed: ${response.status} ${text}`);
  }

  const data = (await response.json()) as { providerMessageId?: string };
  return { delivered: true, providerMessageId: data.providerMessageId ?? `prov-${payload.messageId}` };
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((v) => typeof v === 'string') as string[];
}

export const genAiCoach = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const userId = request.auth.uid;
  const profile = await getUserProfile(userId);
  if (!profile || profile.role !== 'learner') {
    throw new HttpsError('permission-denied', 'Learner role required for AI coach.');
  }

  // ── BOS-aware AI Coach ──
  const { mode, siteId, gradeBand, sessionOccurrenceId, missionId, checkpointId, conceptTags, studentInput } = request.data || {};
  const coachMode: string = mode || 'hint';
  const validModes = ['hint', 'verify', 'explain', 'debug'];
  if (!validModes.includes(coachMode)) {
    throw new HttpsError('invalid-argument', `Invalid mode: ${coachMode}. Must be one of: ${validModes.join(', ')}`);
  }

  // Load learner state from orchestrationStates if available
  let learnerState: { cognition: number; engagement: number; integrity: number } | null = null;
  if (sessionOccurrenceId) {
    const stateDocId = `${userId}_${sessionOccurrenceId}`;
    const stateDoc = await admin.firestore().collection('orchestrationStates').doc(stateDocId).get();
    if (stateDoc.exists) {
      learnerState = stateDoc.data()?.x_hat || null;
    }
  }

  // Build contextual response — V1: template-based, V2+: LLM
  const displayName = profile.displayName ?? 'learner';
  const gb = gradeBand || 'G4_6';
  const tags = Array.isArray(conceptTags) ? conceptTags.join(', ') : '';

  let message: string;
  switch (coachMode) {
    case 'hint':
      message = learnerState && learnerState.cognition < 0.4
        ? `${displayName}, it looks like you could use a nudge. Try re-reading the instructions for this checkpoint and focus on the key concepts${tags ? ` (${tags})` : ''}.`
        : `${displayName}, you're making good progress! Think about what you already know and try applying it to this next step${tags ? ` — focus on ${tags}` : ''}.`;
      break;
    case 'verify':
      message = `${displayName}, let's check your work. Can you explain your reasoning for this step? Walk me through what you did and why.`;
      break;
    case 'explain':
      message = `${displayName}, here's a breakdown: ${tags ? `The concepts involved are ${tags}. ` : ''}Take it step by step and focus on understanding the "why" behind each part.`;
      break;
    case 'debug':
      message = `${displayName}, let's troubleshoot. ${studentInput ? `You mentioned: "${studentInput}". ` : ''}Think about what you expected to happen versus what actually happened. Where does the mismatch start?`;
      break;
    default:
      message = `Hello ${displayName}, this is your AI Coach. Focus on your Leadership & Agency pillar this week!`;
  }

  // Log the AI coach interaction event
  if (siteId) {
    await admin.firestore().collection('interactionEvents').add({
      eventType: 'ai_coach_response',
      siteId,
      actorId: userId,
      actorRole: 'learner',
      gradeBand: gb,
      sessionOccurrenceId: sessionOccurrenceId || null,
      missionId: missionId || null,
      checkpointId: checkpointId || null,
      payload: { mode: coachMode, hasLearnerState: !!learnerState },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return {
    message,
    mode: coachMode,
    learnerState,
    meta: {
      version: '0.2.0',
      gradeBand: gb,
      conceptTags: conceptTags || [],
    },
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
  if (!profile || !profile.role || !allowedRoles.includes(profile.role)) {
    throw new HttpsError('permission-denied', 'Insufficient role.');
  }
  if (siteId && siteId.trim().length > 0) {
    const inSites = (profile.siteIds ?? []).includes(siteId) || profile.activeSiteId === siteId;
    if (!inSites) {
      throw new HttpsError('permission-denied', 'Site access denied.');
    }
  }
  return { uid: authUid, role: profile.role, profile };
}

async function persistTelemetryEvent(params: {
  event: string;
  userId: string;
  role?: Role;
  siteId?: string;
  metadata?: Record<string, unknown>;
}) {
  const { event, userId, role, siteId, metadata } = params;
  return admin.firestore().collection(TELEMETRY_COLLECTION).add({
    event,
    userId,
    role,
    siteId,
    metadata: metadata ?? {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function handleTelemetry(request: CallableRequest) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const event = typeof request.data?.event === 'string' ? request.data.event : undefined;
  if (!event || !ALLOWED_TELEMETRY_EVENTS.has(event)) {
    throw new HttpsError('invalid-argument', 'Invalid event name.');
  }

  const metadata = request.data?.metadata;
  if (metadata !== undefined && (typeof metadata !== 'object' || Array.isArray(metadata))) {
    throw new HttpsError('invalid-argument', 'metadata must be an object if provided');
  }

  const userProfile = await getUserProfile(auth.uid);
  if (!userProfile || !userProfile.role) {
    throw new HttpsError('permission-denied', 'User profile missing role.');
  }

  const siteFromRequest = typeof request.data?.siteId === 'string' ? request.data.siteId : undefined;
  if (siteFromRequest) {
    const allowed = (userProfile.siteIds ?? []).includes(siteFromRequest) || userProfile.activeSiteId === siteFromRequest;
    if (!allowed) {
      throw new HttpsError('permission-denied', 'Site access denied.');
    }
  }

  const role = userProfile.role;
  const siteId = siteFromRequest ?? userProfile.activeSiteId ?? (userProfile.siteIds?.[0] ?? undefined);

  await persistTelemetryEvent({
    event,
    userId: auth.uid,
    role,
    siteId,
    metadata: metadata as Record<string, unknown> | undefined,
  });

  return { status: 'ok' };
}

export const logTelemetryEvent = onCall(async (request: CallableRequest) => handleTelemetry(request));

// Backwards compatibility: keep the old callable name pointing to telemetry pipeline.
export const logAnalyticsEvent = onCall(async (request: CallableRequest) => handleTelemetry(request));

export const listUsers = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);

  const role = typeof request.data?.role === 'string' ? (request.data.role as Role) : undefined;
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

  const nextRole = typeof request.data?.role === 'string' ? (request.data.role as Role) : undefined;
  const siteIds = toStringArray(request.data?.siteIds);
  const activeSiteId = typeof request.data?.activeSiteId === 'string' ? request.data.activeSiteId : undefined;
  const isActive = typeof request.data?.isActive === 'boolean' ? request.data.isActive : undefined;

  const updates: Partial<UserRecord> = {};
  if (nextRole) updates.role = nextRole;
  if (siteIds.length) updates.siteIds = siteIds;
  if (activeSiteId) updates.activeSiteId = activeSiteId;
  if (isActive !== undefined) updates.isActive = isActive;

  updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
  let query: FirebaseFirestore.Query = admin.firestore().collection(AUDIT_COLLECTION).orderBy('createdAt', 'desc').limit(limit);

  if (typeof request.data?.entityId === 'string') {
    query = query.where('entityId', '==', request.data.entityId);
  }
  if (typeof request.data?.entityType === 'string') {
    query = query.where('entityType', '==', request.data.entityType);
  }

  const snap = await query.get();
  const logs = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return { logs };
});

export const processNotificationRequests = onSchedule('every 5 minutes', async () => {
  const db = admin.firestore();
  const pendingSnap = await db
    .collection(NOTIFICATION_REQUESTS_COLLECTION)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'asc')
    .limit(10)
    .get();

  const now = admin.firestore.Timestamp.now();

  for (const docSnap of pendingSnap.docs) {
    const data = docSnap.data();
    const rateKey = (data.rateKey as string | undefined) ?? 'global';
    const rateRef = db.collection(NOTIFICATION_RATE_COLLECTION).doc(rateKey);
    const rateSnap = await rateRef.get();
    const last = rateSnap.exists ? (rateSnap.data()?.lastProcessedAt as admin.firestore.Timestamp | undefined) : undefined;
    if (last && now.toMillis() - last.toMillis() < 60_000) {
      // Skip due to rate limit
      continue;
    }

    await rateRef.set({ lastProcessedAt: now }, { merge: true });
    try {
      const result = await sendNotification({
        channel: data.channel as string,
        threadId: data.threadId as string,
        messageId: data.messageId as string,
        siteId: data.siteId as string,
      });
      await docSnap.ref.set({ status: 'sent', processedAt: now, providerMessageId: result.providerMessageId }, { merge: true });
      await persistTelemetryEvent({
        event: 'notification.requested',
        userId: (data.requestedBy as string | undefined) ?? 'system',
        role: data.role as Role | undefined,
        siteId: data.siteId as string | undefined,
        metadata: { channel: data.channel, threadId: data.threadId, messageId: data.messageId, processed: true },
      });
      const auditRef = db.collection(AUDIT_COLLECTION).doc();
      await auditRef.set({
        actorId: 'notifier',
        actorRole: 'hq',
        action: 'notification.sent',
        entityType: 'notificationRequest',
        entityId: docSnap.id,
        siteId: data.siteId,
        details: { channel: data.channel, threadId: data.threadId, messageId: data.messageId },
        createdAt: now,
      });
    } catch (e) {
      await docSnap.ref.set({ status: 'error', processedAt: now, error: (e as Error).message }, { merge: true });
    }
  }
});

export const createCheckoutIntent = onCall(async (request: CallableRequest) => {
  const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : '';
  const targetUserId = typeof request.data?.userId === 'string' ? request.data.userId.trim() : '';
  const productId = typeof request.data?.productId === 'string' ? request.data.productId.trim() : '' as ProductId;
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
    return { orderId: doc.id, amount: doc.data().amount, currency: doc.data().currency, status: doc.data().status };
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await persistTelemetryEvent({
    event: 'order.intent',
    userId: actor.uid,
    role: actor.role,
    siteId,
    metadata: { productId, targetUserId },
  });

  return { orderId: intentRef.id, amount: product.amount, currency: product.currency, status: 'intent' };
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

  const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();

  await admin.firestore().runTransaction(async (tx) => {
    const intentDoc = await tx.get(intentSnap.ref);
    const current = intentDoc.data();
    if (!current) throw new HttpsError('not-found', 'Intent missing');
    if (current.status === 'paid') return;

    tx.set(intentSnap.ref, {
      status: 'paid',
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      entitlementId: entitlementRef.id,
    }, { merge: true });

    tx.set(entitlementRef, {
      userId: current.userId,
      siteId: current.siteId,
      productId,
      roles: product.roles,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
    tx.set(
      userRef,
      {
        roles: admin.firestore.FieldValue.arrayUnion(...product.roles),
        entitlements: admin.firestore.FieldValue.arrayUnion(...product.roles),
        siteIds: admin.firestore.FieldValue.arrayUnion(current.siteId),
        primarySiteId: current.siteId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await persistTelemetryEvent({
    event: 'order.paid',
    userId: actor.uid,
    role: actor.role,
    siteId: intent.siteId as string,
    metadata: { orderId: intentId, productId, targetUserId: intent.userId, amount: product.amount, currency: product.currency },
  });

  return { orderId: intentId, entitlementId: entitlementRef.id, status: 'paid', amount: product.amount, currency: product.currency };
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

    const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();

    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(intentSnap.ref);
      const current = snap.data();
      if (!current) throw new Error('Intent missing');
      if (current.status === 'paid') return;

      tx.set(intentSnap.ref, {
        status: 'paid',
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        entitlementId: entitlementRef.id,
      }, { merge: true });

      tx.set(entitlementRef, {
        userId: current.userId,
        siteId: current.siteId,
        productId,
        roles: product.roles,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
      tx.set(
        userRef,
        {
          roles: admin.firestore.FieldValue.arrayUnion(...product.roles),
          entitlements: admin.firestore.FieldValue.arrayUnion(...product.roles),
          siteIds: admin.firestore.FieldValue.arrayUnion(current.siteId),
          primarySiteId: current.siteId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await persistTelemetryEvent({
      event: 'order.paid',
      userId: (intent.actorId as string | undefined) ?? 'system',
      role: intent.actorRole as Role | undefined,
      siteId: intent.siteId as string,
      metadata: { orderId: intentId, productId, targetUserId: intent.userId, amount: product.amount, currency: product.currency, via: 'webhook' },
    });

    res.status(200).send({ status: 'paid', orderId: intentId, entitlementId: entitlementRef.id });
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
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
    failedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    paymentMethods: admin.firestore.FieldValue.arrayUnion({
      id: paymentMethod.id,
      type: paymentMethod.type,
      last4: pmData.card?.last4 || null,
      brand: pmData.card?.brand || null,
      addedAt: new Date(),
    }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    refundedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Optionally revoke entitlements on full refund
  if (charge.refunded && intent.entitlementId) {
    await admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc(intent.entitlementId).update({
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    closedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
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
  const entitlementRef = admin.firestore().collection(ENTITLEMENTS_COLLECTION).doc();

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(intentSnap.ref);
    const current = snap.data();
    if (!current || current.status === 'paid') return;

    // Update intent
    tx.set(intentSnap.ref, {
      status: 'paid',
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      entitlementId: entitlementRef.id,
      stripePaymentIntentId: session.payment_intent,
      stripePaymentStatus: session.payment_status,
    }, { merge: true });

    // Create entitlement
    tx.set(entitlementRef, {
      userId: current.userId,
      siteId: current.siteId,
      productId,
      roles: product.roles,
      stripeSessionId: session.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update user roles
    const userRef = admin.firestore().collection(USERS_COLLECTION).doc(current.userId as string);
    tx.set(
      userRef,
      {
        roles: admin.firestore.FieldValue.arrayUnion(...product.roles),
        entitlements: admin.firestore.FieldValue.arrayUnion(...product.roles),
        siteIds: admin.firestore.FieldValue.arrayUnion(current.siteId),
        primarySiteId: current.siteId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await persistTelemetryEvent({
    event: 'order.paid',
    userId: intent.actorId ?? 'system',
    role: intent.actorRole as Role | undefined,
    siteId: intent.siteId as string,
    metadata: {
      orderId: intentId,
      productId,
      targetUserId: intent.userId,
      amount: session.amount_total,
      currency: session.currency,
      via: 'stripe_webhook',
      stripeSessionId: session.id,
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    failedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    let authStatus = 'ok';
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      archivedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
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
      cancelledAt: cancelAtPeriodEnd ? null : admin.firestore.FieldValue.serverTimestamp(),
      status: cancelAtPeriodEnd ? 'active' : 'cancelled',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.firestore().collection(AUDIT_COLLECTION).add({
      actorId: request.auth.uid,
      actorRole: sub.userId === request.auth.uid ? 'user' : 'hq',
      action: 'subscription.resumed',
      entityType: 'subscription',
      entityId: subscriptionId,
      siteId: sub.siteId,
      details: { stripeSubscriptionId: sub.stripeSubscriptionId },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(oneDayAgo))
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update effectiveness score in motivation profile
  if (outcome !== 'no-change') {
    await updateStrategyEffectiveness(learnerId, strategyType, outcome);
  }

  // Log telemetry
  await persistTelemetryEvent({
    event: 'support.intervention.logged',
    userId: uid,
    role,
    siteId,
    metadata: { learnerId, interventionId: interventionRef.id, outcome },
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
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const { eventType, siteId, metadata } = request.data;

  if (!eventType || !siteId) {
    throw new HttpsError('invalid-argument', 'eventType and siteId are required');
  }

  // Validate event type
  const validEvents = [
    'app.open', 'app.session.end', 'mission.started', 'mission.completed',
    'mission.abandoned', 'reflection.submitted', 'portfolio.item.added',
    'help.requested', 'badge.viewed', 'leaderboard.viewed', 'streak.celebrated',
    'nudge.accepted', 'nudge.dismissed', 'nudge.snoozed',
  ];

  if (!validEvents.includes(eventType)) {
    throw new HttpsError('invalid-argument', `Invalid event type: ${eventType}`);
  }

  // Store interaction
  await admin.firestore().collection(MOTIVATION_COLLECTIONS.LEARNER_INTERACTIONS).add({
    learnerId: auth.uid,
    siteId,
    eventType,
    metadata: metadata || {},
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Also log to general telemetry
  await persistTelemetryEvent({
    event: eventType,
    userId: auth.uid,
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
    respondedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (response === 'snoozed' && snoozeDurationMinutes) {
    updateData.scheduledFor = admin.firestore.Timestamp.fromMillis(
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
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
  let learnersQuery: FirebaseFirestore.Query = admin.firestore()
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
  const { uid } = await requireRoleAndSite(request.auth?.uid, ['educator', 'hq'], request.data.siteId);

  const { siteId, sessionOccurrenceId, learnerIds } = request.data;

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
    lastInteractionUpdate: admin.firestore.FieldValue.serverTimestamp(),
    lastEducatorFeedback: admin.firestore.FieldValue.serverTimestamp(),
    lastComputedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
  const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);

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
    lastComputedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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

function generateInsights(
  patterns: Record<string, any>,
  feedbackData: any[],
  motivatorScores: Record<MotivationType, number>,
  engagementLevel: EngagementLevel
): any[] {
  const insights: any[] = [];
  const now = admin.firestore.Timestamp.now();

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
      suggestedActions: [`Use ${topMotivator[0]}-focused activities`, `Leverage this in challenging moments`],
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
      confidence: 0.9,
      basedOn: ['interaction patterns', 'educator feedback'],
      suggestedActions: ['Consider leadership opportunities', 'Encourage peer mentoring'],
      createdAt: now,
    });
  }

  // Warning insights
  if (engagementLevel === 'at-risk' || engagementLevel === 'struggling') {
    insights.push({
      id: 'warning-engagement',
      type: 'warning',
      title: 'Needs extra support',
      description: `Engagement is ${engagementLevel}. Consider checking in.`,
      confidence: 0.8,
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
      confidence: 0.7,
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
        lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
    }
    return s;
  });

  await profileRef.update({
    effectiveStrategies: updated,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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

  const templates = nudgeTemplates[primaryMotivator] || nudgeTemplates.achievement;
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
  });
}
