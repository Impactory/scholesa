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
    const rawBody = req.rawBody;
    event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
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

// ============================================================================
// PRODUCTION HEALTH & MAINTENANCE FUNCTIONS
// ============================================================================

/**
 * Health check endpoint for load balancers and monitoring
 */
export const healthCheck = onRequest({ cors: true }, async (_req, res) => {
  try {
    // Verify Firestore connectivity
    await admin.firestore().collection('_healthCheck').doc('ping').get();
    
    // Verify Auth connectivity
    await admin.auth().getUser('health-check-dummy').catch(() => {});

    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.K_REVISION || 'local',
      services: {
        firestore: 'ok',
        auth: 'ok',
        stripe: stripe ? 'configured' : 'not_configured',
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
export const cancelSubscription = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
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
    const stripeSubscription = await stripe.subscriptions.update(sub.stripeSubscriptionId, {
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
export const resumeSubscription = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
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
    await stripe.subscriptions.update(sub.stripeSubscriptionId, {
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
export const updateSubscriptionPaymentMethod = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
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
    await stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });

    // Set as default payment method
    await stripe.customers.update(customerId, {
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
export const getInvoiceHistory = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
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
    const invoices = await stripe.invoices.list({
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
export const retryInvoicePayment = onCall(async (request: CallableRequest) => {
  if (!stripe) throw new HttpsError('failed-precondition', 'Stripe not configured');
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const invoiceId = typeof request.data?.invoiceId === 'string' ? request.data.invoiceId : '';
  if (!invoiceId) throw new HttpsError('invalid-argument', 'invoiceId is required');

  // Verify user owns this invoice
  const customerSnap = await admin.firestore().collection(STRIPE_CUSTOMERS_COLLECTION).doc(request.auth.uid).get();
  if (!customerSnap.exists) throw new HttpsError('not-found', 'No Stripe customer found');

  const customerId = customerSnap.data()?.stripeCustomerId;

  try {
    const invoice = await stripe.invoices.retrieve(invoiceId);
    
    if (invoice.customer !== customerId) {
      await requireHq(request.auth.uid);
    }

    if (invoice.status !== 'open') {
      throw new HttpsError('failed-precondition', 'Invoice is not payable');
    }

    const paidInvoice = await stripe.invoices.pay(invoiceId);

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
export const processRefund = onCall(async (request: CallableRequest<{
  paymentIntentId: string;
  amount?: number;
  reason?: string;
}>) => {
  await requireHq(request.auth?.uid);

  if (!stripe) {
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

    const refund = await stripe.refunds.create(refundParams);

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
export const getStripeMetrics = onCall(async (request: CallableRequest) => {
  await requireHq(request.auth?.uid);

  if (!stripe) {
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
    const charges = await stripe.charges.list({
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
