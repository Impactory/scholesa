import { createHmac } from 'crypto';
import { onCall, onRequest, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

admin.initializeApp();

// Initialize Stripe
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const stripe = STRIPE_SECRET_KEY ? new Stripe(STRIPE_SECRET_KEY) : null;

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
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || '';

// Stripe Price IDs - map to your Stripe Dashboard products
const STRIPE_PRICE_IDS: Record<ProductId, string> = {
  'learner-seat': process.env.STRIPE_PRICE_LEARNER || 'price_learner_seat',
  'educator-seat': process.env.STRIPE_PRICE_EDUCATOR || 'price_educator_seat',
  'parent-seat': process.env.STRIPE_PRICE_PARENT || 'price_parent_seat',
  'site-license': process.env.STRIPE_PRICE_SITE || 'price_site_license',
};

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
  const endpoint = process.env.NOTIFY_ENDPOINT;
  const apiKey = process.env.NOTIFY_API_KEY;
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
  return { message: `Hello ${profile.displayName ?? 'learner'}, this is your AI Coach. Focus on your Leadership & Agency pillar this week!` };
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
  const expectedSig = WEBHOOK_SECRET ? createHmac('sha256', WEBHOOK_SECRET).update(payload).digest('hex') : '';
  if (!WEBHOOK_SECRET || secret !== WEBHOOK_SECRET || signature !== expectedSig) {
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
async function getOrCreateStripeCustomer(userId: string, email: string, name?: string): Promise<string> {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');

  const customerRef = admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(userId);
  const customerSnap = await customerRef.get();

  if (customerSnap.exists) {
    const data = customerSnap.data();
    if (data?.stripeCustomerId) {
      return data.stripeCustomerId as string;
    }
  }

  // Create new Stripe customer
  const customer = await stripe.customers.create({
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
export const createStripeCheckoutSession = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');

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
  const priceId = STRIPE_PRICE_IDS[productId as ProductId];

  // Get or create Stripe customer
  const stripeCustomerId = await getOrCreateStripeCustomer(
    targetUserId,
    targetUser.email,
    targetUser.displayName
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
  const session = await stripe.checkout.sessions.create({
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
export const createStripeSubscription = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');

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
  const priceId = STRIPE_PRICE_IDS[productId as ProductId];

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

  const session = await stripe.checkout.sessions.create({
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
 * Stripe Webhook Handler - processes payment events
 */
export const stripeWebhook = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  if (!stripe || !STRIPE_WEBHOOK_SECRET) {
    console.error('Stripe not configured');
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
    // Get raw body for signature verification
    const rawBody = req.rawBody;
    event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
  } catch (err: any) {
    console.error('Webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Handle the event
  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutSessionCompleted(session);
        break;
      }

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

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.status(200).json({ received: true });
  } catch (err: any) {
    console.error('Error processing webhook:', err);
    res.status(500).send(`Webhook processing error: ${err.message}`);
  }
});

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
  await subDoc.ref.update({
    status: 'past_due',
    lastPaymentError: invoice.last_finalization_error?.message ?? 'Payment failed',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // TODO: Send notification to user about failed payment
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
export const createStripePortalSession = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const returnUrl = typeof request.data?.returnUrl === 'string' ? request.data.returnUrl : '';
  if (!returnUrl) throw new HttpsError('invalid-argument', 'returnUrl is required');

  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(request.auth.uid).get();
  if (!customerSnap.exists) throw new HttpsError('not-found', 'No Stripe customer found');

  const stripeCustomerId = customerSnap.data()?.stripeCustomerId;
  if (!stripeCustomerId) throw new HttpsError('not-found', 'No Stripe customer ID');

  const portalSession = await stripe.billingPortal.sessions.create({
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
