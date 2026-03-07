import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';

const firestoreNamespace = admin.firestore as typeof admin.firestore & {
  FieldValue?: typeof FieldValue;
  Timestamp?: typeof Timestamp;
};
firestoreNamespace.FieldValue ??= FieldValue;
firestoreNamespace.Timestamp ??= Timestamp;

interface UserRecord {
  role?: string;
  siteIds?: string[];
  activeSiteId?: string;
  organizationId?: string;
  learnerIds?: string[];
  parentIds?: string[];
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

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0);
}

async function getActorProfile(authUid: string | undefined): Promise<{ uid: string; role: Role; profile: UserRecord }> {
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const userSnap = await admin.firestore().collection('users').doc(authUid).get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User profile not found.');
  }

  const profile = userSnap.data() as UserRecord;
  const role = normalizeRoleValue(profile.role);
  if (!role) {
    throw new HttpsError('permission-denied', 'User role not recognized.');
  }

  return { uid: authUid, role, profile };
}

function actorCanAccessSite(actor: { role: Role; profile: UserRecord }, siteId: string | undefined): boolean {
  if (!siteId || siteId.trim().length === 0) return true;
  if (actor.role === 'hq') return true;
  const siteIds = toStringArray(actor.profile.siteIds);
  return siteIds.includes(siteId) || actor.profile.activeSiteId === siteId;
}

function stripSecretFields(input: Record<string, unknown>): Record<string, unknown> {
  const denied = new Set([
    'accessToken',
    'refreshToken',
    'oauthToken',
    'oauthRefreshToken',
    'clientSecret',
    'privateKey',
    'password',
  ]);
  const output: Record<string, unknown> = {};
  Object.entries(input).forEach(([key, value]) => {
    if (denied.has(key)) return;
    output[key] = value;
  });
  return output;
}

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function toDateValue(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return new Date(parsed);
  }
  return null;
}

function toIsoString(value: unknown): string | null {
  const asDate = toDateValue(value);
  return asDate ? asDate.toISOString() : null;
}

function periodStart(period: unknown, now: Date): Date {
  const normalized = typeof period === 'string' ? period.trim().toLowerCase() : '';
  if (normalized === 'year') {
    return new Date(now.getFullYear(), 0, 1);
  }
  if (normalized === 'quarter') {
    const quarterStartMonth = Math.floor(now.getMonth() / 3) * 3;
    return new Date(now.getFullYear(), quarterStartMonth, 1);
  }
  return new Date(now.getFullYear(), now.getMonth(), 1);
}

function normalizeSubscriptionStatus(value: unknown): 'active' | 'paused' | 'cancelled' {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'paused' || normalized === 'cancelled') return normalized;
  return 'active';
}

function normalizeInvoiceStatus(value: unknown): 'paid' | 'pending' | 'overdue' {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'approved' || normalized === 'paid' || normalized === 'completed') return 'paid';
  if (normalized === 'overdue') return 'overdue';
  return 'pending';
}

async function buildSiteNameMap(siteIds: string[]): Promise<Record<string, string>> {
  const ids = Array.from(new Set(siteIds.map((value) => value.trim()).filter((value) => value.length > 0)));
  if (ids.length === 0) return {};
  const refs = ids.map((siteId) => admin.firestore().collection('sites').doc(siteId));
  const docs = await admin.firestore().getAll(...refs);
  const output: Record<string, string> = {};
  for (const docSnap of docs) {
    if (!docSnap.exists) continue;
    const data = docSnap.data() as Record<string, unknown>;
    const name = asTrimmedString(data.name);
    output[docSnap.id] = name.length > 0 ? name : docSnap.id;
  }
  return output;
}

async function loadUsersByIds(userIds: string[]): Promise<Array<{ id: string; data: Record<string, unknown> }>> {
  const ids = Array.from(new Set(userIds.map((value) => value.trim()).filter((value) => value.length > 0)));
  if (ids.length === 0) return [];
  const refs = ids.map((userId) => admin.firestore().collection('users').doc(userId));
  const docs = await admin.firestore().getAll(...refs);
  return docs
    .filter((docSnap) => docSnap.exists)
    .map((docSnap) => ({
      id: docSnap.id,
      data: (docSnap.data() || {}) as Record<string, unknown>,
    }));
}

export const listPartnerPayouts = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'partner' && actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'Partner or HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 100;

  let payoutsQuery: FirebaseFirestore.Query = admin.firestore().collection('payouts').limit(limitValue);
  if (actor.role === 'partner') {
    payoutsQuery = payoutsQuery.where('partnerId', '==', actor.uid);
  }

  const snap = await payoutsQuery.get();
  const payouts = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));

  return { payouts };
});

export const listWorkflowApprovals = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 300
    ? request.data.limit
    : 120;

  const [contractsSnap, payoutsSnap] = await Promise.all([
    admin.firestore().collection('partnerContracts').where('status', 'in', ['pending', 'submitted']).limit(limitValue).get()
      .catch(() => admin.firestore().collection('partnerContracts').limit(limitValue).get()),
    admin.firestore().collection('payouts').where('status', 'in', ['pending', 'submitted']).limit(limitValue).get()
      .catch(() => admin.firestore().collection('payouts').limit(limitValue).get()),
  ]);

  const approvals = [
    ...contractsSnap.docs.map((snapDoc) => {
      const data = snapDoc.data() as Record<string, unknown>;
      return {
        id: `partnerContracts:${snapDoc.id}`,
        sourceCollection: 'partnerContracts',
        sourceId: snapDoc.id,
        title: typeof data.title === 'string' ? data.title : `Contract ${snapDoc.id}`,
        summary: typeof data.summary === 'string' ? data.summary : 'Partner contract awaiting review.',
        siteId: typeof data.siteId === 'string' ? data.siteId : null,
        status: typeof data.status === 'string' ? data.status : 'pending',
      };
    }),
    ...payoutsSnap.docs.map((snapDoc) => {
      const data = snapDoc.data() as Record<string, unknown>;
      return {
        id: `payouts:${snapDoc.id}`,
        sourceCollection: 'payouts',
        sourceId: snapDoc.id,
        title: `Payout ${snapDoc.id}`,
        summary: `Amount ${String(data.amount || 0)} ${String(data.currency || 'USD').toUpperCase()}`,
        siteId: typeof data.siteId === 'string' ? data.siteId : null,
        status: typeof data.status === 'string' ? data.status : 'pending',
      };
    }),
  ];

  return { approvals };
});

export const decideWorkflowApproval = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const approvalId = typeof request.data?.id === 'string' ? request.data.id : '';
  const nextStatus = typeof request.data?.status === 'string' ? request.data.status : '';
  if (!approvalId || !nextStatus) {
    throw new HttpsError('invalid-argument', 'id and status are required.');
  }

  const [collectionName, sourceId] = approvalId.split(':');
  if (!collectionName || !sourceId) {
    throw new HttpsError('invalid-argument', 'Invalid approval id format.');
  }
  if (!['partnerContracts', 'payouts'].includes(collectionName)) {
    throw new HttpsError('invalid-argument', 'Unsupported approval source.');
  }

  await admin.firestore().collection(collectionName).doc(sourceId).set({
    status: nextStatus,
    reviewedBy: actor.uid,
    reviewedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    actorId: actor.uid,
    actorRole: actor.role,
    action: 'approval.decision',
    entityType: collectionName,
    entityId: sourceId,
    details: { status: nextStatus },
    createdAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const listSafetyIncidents = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId : undefined;
  const siteId = requestedSiteId || actor.profile.activeSiteId;
  if (!actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 300
    ? request.data.limit
    : 120;

  const incidentsQuery = siteId
    ? admin.firestore().collection('incidents').where('siteId', '==', siteId).limit(limitValue)
    : admin.firestore().collection('incidents').limit(limitValue);
  const incidentReportsQuery = siteId
    ? admin.firestore().collection('incidentReports').where('siteId', '==', siteId).limit(limitValue)
    : admin.firestore().collection('incidentReports').limit(limitValue);

  const [incidentsSnap, incidentReportsSnap] = await Promise.all([
    incidentsQuery.get(),
    incidentReportsQuery.get(),
  ]);

  const incidents = [
    ...incidentsSnap.docs.map((snapDoc) => {
      const data = snapDoc.data() as Record<string, unknown>;
      return {
        id: `incidents:${snapDoc.id}`,
        sourceCollection: 'incidents',
        sourceId: snapDoc.id,
        title: typeof data.title === 'string' ? data.title : `Incident ${snapDoc.id}`,
        summary: typeof data.summary === 'string' ? data.summary : 'Safety incident record.',
        status: typeof data.status === 'string' ? data.status : 'open',
        severity: typeof data.severity === 'string' ? data.severity : 'medium',
        siteId: typeof data.siteId === 'string' ? data.siteId : siteId || null,
        updatedAt: data.updatedAt || data.createdAt || null,
      };
    }),
    ...incidentReportsSnap.docs.map((snapDoc) => {
      const data = snapDoc.data() as Record<string, unknown>;
      return {
        id: `incidentReports:${snapDoc.id}`,
        sourceCollection: 'incidentReports',
        sourceId: snapDoc.id,
        title: typeof data.title === 'string' ? data.title : `Incident Report ${snapDoc.id}`,
        summary: typeof data.summary === 'string' ? data.summary : 'Safeguarding incident report.',
        status: typeof data.status === 'string' ? data.status : 'open',
        severity: typeof data.severity === 'string' ? data.severity : 'medium',
        siteId: typeof data.siteId === 'string' ? data.siteId : siteId || null,
        updatedAt: data.updatedAt || data.createdAt || null,
      };
    }),
  ];

  return { incidents };
});

export const resolveSafetyIncident = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const mode = typeof request.data?.mode === 'string' ? request.data.mode : 'update';
  if (mode === 'create') {
    const siteId = typeof request.data?.siteId === 'string' ? request.data.siteId : actor.profile.activeSiteId;
    if (!siteId || !actorCanAccessSite(actor, siteId)) {
      throw new HttpsError('permission-denied', 'Invalid site context for incident creation.');
    }
    const title = typeof request.data?.title === 'string' ? request.data.title : 'Incident';
    const summary = typeof request.data?.summary === 'string' ? request.data.summary : '';
    const createdRef = await admin.firestore().collection('incidents').add({
      siteId,
      title,
      summary,
      status: 'open',
      severity: 'medium',
      createdBy: actor.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true, id: `incidents:${createdRef.id}` };
  }

  const id = typeof request.data?.id === 'string' ? request.data.id : '';
  const status = typeof request.data?.status === 'string' ? request.data.status : 'resolved';
  if (!id) {
    throw new HttpsError('invalid-argument', 'id is required for update mode.');
  }
  const [collectionName, sourceId] = id.includes(':') ? id.split(':') : ['incidents', id];
  if (!['incidents', 'incidentReports'].includes(collectionName) || !sourceId) {
    throw new HttpsError('invalid-argument', 'Unsupported incident source.');
  }

  const ref = admin.firestore().collection(collectionName).doc(sourceId);
  const existing = await ref.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Incident not found.');
  }
  const currentData = existing.data() as Record<string, unknown>;
  const siteId = typeof currentData.siteId === 'string' ? currentData.siteId : undefined;
  if (!actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to this incident site.');
  }

  await ref.set({
    status,
    resolvedBy: actor.uid,
    resolvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true };
});

export const getIntegrationsHealth = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId : undefined;
  const siteId = requestedSiteId || actor.profile.activeSiteId;
  if (!actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const syncJobsQuery = siteId
    ? admin.firestore().collection('syncJobs').where('siteId', '==', siteId).limit(120)
    : admin.firestore().collection('syncJobs').limit(120);
  const connectionsQuery = siteId
    ? admin.firestore().collection('integrationConnections').where('siteId', '==', siteId).limit(120)
    : admin.firestore().collection('integrationConnections').limit(120);

  const [syncJobsSnap, connectionsSnap] = await Promise.all([
    syncJobsQuery.get(),
    connectionsQuery.get(),
  ]);

  const siteIdCandidates: string[] = [];
  for (const snapDoc of syncJobsSnap.docs) {
    const row = snapDoc.data() as Record<string, unknown>;
    const rowSiteId = asTrimmedString(row.siteId);
    if (rowSiteId.length > 0) siteIdCandidates.push(rowSiteId);
  }
  for (const snapDoc of connectionsSnap.docs) {
    const row = snapDoc.data() as Record<string, unknown>;
    const rowSiteId = asTrimmedString(row.siteId);
    if (rowSiteId.length > 0) siteIdCandidates.push(rowSiteId);
  }
  const siteNames = await buildSiteNameMap(siteIdCandidates);

  const syncJobs = syncJobsSnap.docs.map((snapDoc) => ({
    ...(snapDoc.data() as Record<string, unknown>),
    id: snapDoc.id,
    siteName: siteNames[asTrimmedString((snapDoc.data() as Record<string, unknown>).siteId)] || null,
  }));
  const connections = connectionsSnap.docs.map((snapDoc) => {
    const data = snapDoc.data() as Record<string, unknown>;
    const rowSiteId = asTrimmedString(data.siteId);
    return {
      ...stripSecretFields(data),
      id: snapDoc.id,
      siteName: siteNames[rowSiteId] || null,
    };
  });

  return { syncJobs, connections };
});

export const triggerIntegrationSyncJob = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId : actor.profile.activeSiteId;
  if (!requestedSiteId || !actorCanAccessSite(actor, requestedSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const provider = typeof request.data?.provider === 'string' ? request.data.provider : 'google-classroom';
  const docRef = await admin.firestore().collection('syncJobs').add({
    siteId: requestedSiteId,
    provider,
    status: 'queued',
    requestedBy: actor.uid,
    requestedByRole: actor.role,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true, id: docRef.id };
});

export const updateIntegrationConnectionStatus = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const id = typeof request.data?.id === 'string' ? request.data.id : '';
  const status = typeof request.data?.status === 'string' ? request.data.status : '';
  if (!id || !status) {
    throw new HttpsError('invalid-argument', 'id and status are required.');
  }

  const ref = admin.firestore().collection('integrationConnections').doc(id);
  const existing = await ref.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Integration connection not found.');
  }
  const data = existing.data() as Record<string, unknown>;
  const siteId = typeof data.siteId === 'string' ? data.siteId : undefined;
  if (!actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  await ref.set({
    status,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true };
});

export const listExternalIdentityLinks = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId : actor.profile.activeSiteId;
  if (!actorCanAccessSite(actor, requestedSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const linksQuery = requestedSiteId
    ? admin.firestore().collection('externalIdentityLinks').where('siteId', '==', requestedSiteId).limit(120)
    : admin.firestore().collection('externalIdentityLinks').limit(120);

  const linksSnap = await linksQuery.get();
  const links = linksSnap.docs.map((snapDoc) => {
    const data = snapDoc.data() as Record<string, unknown>;
    return {
      id: snapDoc.id,
      ...stripSecretFields(data),
    };
  });

  return { links };
});

export const resolveExternalIdentityLink = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const id = typeof request.data?.id === 'string' ? request.data.id : '';
  const status = typeof request.data?.status === 'string' ? request.data.status : 'resolved';
  if (!id) {
    throw new HttpsError('invalid-argument', 'id is required.');
  }

  const ref = admin.firestore().collection('externalIdentityLinks').doc(id);
  const existing = await ref.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Identity link not found.');
  }
  const data = existing.data() as Record<string, unknown>;
  const siteId = typeof data.siteId === 'string' ? data.siteId : undefined;
  if (!actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  await ref.set({
    status,
    resolvedBy: actor.uid,
    resolvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true };
});

export const listFeatureFlags = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const snap = await admin.firestore().collection('featureFlags').limit(300).get();
  const flags = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { flags };
});

export const upsertFeatureFlag = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const requestedId = typeof request.data?.id === 'string' && request.data.id.trim().length > 0
    ? request.data.id.trim()
    : '';
  const ref = requestedId
    ? admin.firestore().collection('featureFlags').doc(requestedId)
    : admin.firestore().collection('featureFlags').doc();
  const id = ref.id;
  const name = typeof request.data?.name === 'string' ? request.data.name : id;
  const description = typeof request.data?.description === 'string' ? request.data.description : '';
  const enabled = typeof request.data?.enabled === 'boolean' ? request.data.enabled : false;

  await ref.set({
    name,
    description,
    enabled,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    status: enabled ? 'enabled' : 'disabled',
  }, { merge: true });

  return { success: true, id };
});

export const listWorkflowContacts = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 80;
  const targetSiteId = requestedSiteId || asTrimmedString(actor.profile.activeSiteId) || asTrimmedString(actor.profile.siteIds?.[0]);

  const candidates = new Map<string, { id: string; data: Record<string, unknown> }>();
  const addCandidates = (rows: Array<{ id: string; data: Record<string, unknown> }>) => {
    for (const row of rows) {
      if (!row.id || row.id === actor.uid) continue;
      candidates.set(row.id, row);
    }
  };

  if (actor.role === 'hq') {
    const usersSnap = await admin.firestore().collection('users').limit(limitValue).get();
    addCandidates(usersSnap.docs.map((docSnap) => ({
      id: docSnap.id,
      data: (docSnap.data() || {}) as Record<string, unknown>,
    })));
  } else if (actor.role === 'site' || actor.role === 'educator') {
    if (!targetSiteId || !actorCanAccessSite(actor, targetSiteId)) {
      throw new HttpsError('permission-denied', 'No access to requested site.');
    }
    const usersSnap = await admin.firestore()
      .collection('users')
      .where('siteIds', 'array-contains', targetSiteId)
      .limit(limitValue)
      .get();
    addCandidates(usersSnap.docs.map((docSnap) => ({
      id: docSnap.id,
      data: (docSnap.data() || {}) as Record<string, unknown>,
    })));
  } else if (actor.role === 'parent') {
    const linkedLearnerIds = new Set<string>();
    const guardianLinksSnap = await admin.firestore()
      .collection('guardianLinks')
      .where('parentId', '==', actor.uid)
      .limit(100)
      .get()
      .catch(() => null);
    guardianLinksSnap?.docs.forEach((docSnap) => {
      const learnerId = asTrimmedString((docSnap.data() as Record<string, unknown>).learnerId);
      if (learnerId) linkedLearnerIds.add(learnerId);
    });
    toStringArray(actor.profile.learnerIds).forEach((learnerId) => linkedLearnerIds.add(learnerId));

    addCandidates(await loadUsersByIds(Array.from(linkedLearnerIds.values())));

    if (targetSiteId) {
      const siteUsersSnap = await admin.firestore()
        .collection('users')
        .where('siteIds', 'array-contains', targetSiteId)
        .limit(120)
        .get();
      addCandidates(
        siteUsersSnap.docs
          .map((docSnap) => ({
            id: docSnap.id,
            data: (docSnap.data() || {}) as Record<string, unknown>,
          }))
          .filter((row) => ['educator', 'site', 'hq', 'teacher', 'siteLead', 'site_lead'].includes(asTrimmedString(row.data.role))),
      );
    }
  } else if (actor.role === 'learner') {
    const linkedParentIds = new Set<string>(toStringArray(actor.profile.parentIds));
    addCandidates(await loadUsersByIds(Array.from(linkedParentIds.values())));

    if (targetSiteId) {
      const siteUsersSnap = await admin.firestore()
        .collection('users')
        .where('siteIds', 'array-contains', targetSiteId)
        .limit(120)
        .get();
      addCandidates(
        siteUsersSnap.docs
          .map((docSnap) => ({
            id: docSnap.id,
            data: (docSnap.data() || {}) as Record<string, unknown>,
          }))
          .filter((row) => ['educator', 'site', 'hq', 'teacher', 'siteLead', 'site_lead', 'parent', 'guardian'].includes(asTrimmedString(row.data.role))),
      );
    }
  } else if (actor.role === 'partner') {
    const usersSnap = await admin.firestore()
      .collection('users')
      .where('role', 'in', ['hq', 'admin'])
      .limit(limitValue)
      .get()
      .catch(() => admin.firestore().collection('users').limit(limitValue).get());
    addCandidates(usersSnap.docs
      .map((docSnap) => ({
        id: docSnap.id,
        data: (docSnap.data() || {}) as Record<string, unknown>,
      }))
      .filter((row) => ['hq', 'admin'].includes(asTrimmedString(row.data.role))));
  }

  const contacts = Array.from(candidates.values())
    .map((row) => ({
      id: row.id,
      displayName: asTrimmedString(row.data.displayName) || asTrimmedString(row.data.email) || row.id,
      role: normalizeRoleValue(row.data.role)?.toString() || asTrimmedString(row.data.role) || 'unknown',
      siteId: asTrimmedString(row.data.activeSiteId) || null,
      email: asTrimmedString(row.data.email) || null,
    }))
    .sort((left, right) => left.displayName.localeCompare(right.displayName))
    .slice(0, limitValue);

  return { contacts };
});

export const getParentBillingSummary = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'parent' && actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'Parent or HQ role required.');
  }

  const requestedParentId = asTrimmedString(request.data?.parentId);
  const targetParentId = requestedParentId.length > 0 ? requestedParentId : actor.uid;
  if (actor.role === 'parent' && targetParentId !== actor.uid) {
    throw new HttpsError('permission-denied', 'Parents can only access their own billing summary.');
  }

  const [accountSnap, paymentSnap] = await Promise.all([
    admin.firestore().collection('billingAccounts').doc(targetParentId).get(),
    admin.firestore()
      .collection('payments')
      .where('parentId', '==', targetParentId)
      .limit(20)
      .get()
      .catch(() => admin.firestore().collection('payments').limit(20).get()),
  ]);

  const accountData = accountSnap.data() as Record<string, unknown> | undefined;
  const recentPayments = paymentSnap.docs
    .map((docSnap) => {
      const row = docSnap.data() as Record<string, unknown>;
      const parentId = asTrimmedString(row.parentId);
      if (parentId.length > 0 && parentId !== targetParentId) return null;
      return {
        id: docSnap.id,
        amount: asNumber(row.amount) ?? 0,
        date: toIsoString(row.date || row.updatedAt || row.createdAt),
        status: asTrimmedString(row.status).length > 0 ? asTrimmedString(row.status) : 'unknown',
        description: asTrimmedString(row.description),
      };
    })
    .filter((row): row is { id: string; amount: number; date: string | null; status: string; description: string } => Boolean(row))
    .sort((a, b) => {
      const timeA = a.date ? Date.parse(a.date) : 0;
      const timeB = b.date ? Date.parse(b.date) : 0;
      return timeB - timeA;
    })
    .slice(0, 10);

  return {
    summary: {
      parentId: targetParentId,
      currentBalance: asNumber(accountData?.currentBalance) ?? 0,
      nextPaymentAmount: asNumber(accountData?.nextPaymentAmount) ?? 0,
      nextPaymentDate: toIsoString(accountData?.nextPaymentDate),
      subscriptionPlan: asTrimmedString(accountData?.subscriptionPlan) || 'Basic',
      recentPayments,
    },
  };
});

export const getSiteBillingSnapshot = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'site' && actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId || asTrimmedString(actor.profile.activeSiteId) || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No active site context found.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const [siteSnap, payoutsSnap] = await Promise.all([
    admin.firestore().collection('sites').doc(targetSiteId).get(),
    admin.firestore()
      .collection('payouts')
      .where('siteId', '==', targetSiteId)
      .limit(80)
      .get()
      .catch(() => admin.firestore().collection('payouts').limit(80).get()),
  ]);

  const siteData = siteSnap.data() as Record<string, unknown> | undefined;
  const invoices = payoutsSnap.docs
    .map((docSnap) => {
      const row = docSnap.data() as Record<string, unknown>;
      const rowSiteId = asTrimmedString(row.siteId);
      if (rowSiteId.length > 0 && rowSiteId !== targetSiteId) return null;
      const amount = asNumber(row.amount) ?? 0;
      const currency = asTrimmedString(row.currency).toUpperCase() || 'USD';
      return {
        id: docSnap.id,
        amount,
        currency,
        status: normalizeInvoiceStatus(row.status),
        date: toIsoString(row.approvedAt || row.createdAt || row.updatedAt),
      };
    })
    .filter((row): row is { id: string; amount: number; currency: string; status: 'paid' | 'pending' | 'overdue'; date: string | null } => Boolean(row))
    .sort((a, b) => {
      const timeA = a.date ? Date.parse(a.date) : 0;
      const timeB = b.date ? Date.parse(b.date) : 0;
      return timeB - timeA;
    })
    .slice(0, 50);

  return {
    siteId: targetSiteId,
    planName: asTrimmedString(siteData?.billingPlan) || 'Standard',
    planStatus: asTrimmedString(siteData?.billingStatus) || 'Active',
    monthlyAmount: asNumber(siteData?.monthlyFee) ?? 0,
    currency: asTrimmedString(siteData?.currency).toUpperCase() || 'USD',
    nextBillingDate: toIsoString(siteData?.nextBillingDate),
    activeLearnersUsed: asNumber(siteData?.learnerCount) ?? (Array.isArray(siteData?.learnerIds) ? siteData?.learnerIds.length : 0),
    activeLearnersTotal: asNumber(siteData?.learnerCap) ?? asNumber(siteData?.billingLearnerLimit) ?? 100,
    educatorsUsed: asNumber(siteData?.educatorCount) ?? (Array.isArray(siteData?.educatorIds) ? siteData?.educatorIds.length : 0),
    educatorsTotal: asNumber(siteData?.educatorCap) ?? asNumber(siteData?.billingEducatorLimit) ?? 15,
    storageUsedGb: asNumber(siteData?.storageUsedGb) ?? asNumber(siteData?.storageUsed) ?? 0,
    storageTotalGb: asNumber(siteData?.storageCapGb) ?? asNumber(siteData?.storageLimitGb) ?? 10,
    invoices,
  };
});

export const requestSiteBillingPlanChange = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'site' && actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId || asTrimmedString(actor.profile.activeSiteId) || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const reason = asTrimmedString(request.data?.reason);
  const docRef = await admin.firestore().collection('billingPlanChangeRequests').add({
    siteId: targetSiteId,
    status: 'pending',
    reason,
    requestedBy: actor.uid,
    requestedByRole: actor.role,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await admin.firestore().collection('auditLogs').add({
    actorId: actor.uid,
    actorRole: actor.role,
    action: 'billing.plan_change_requested',
    entityType: 'billingPlanChangeRequest',
    entityId: docRef.id,
    siteId: targetSiteId,
    details: { reason },
    createdAt: FieldValue.serverTimestamp(),
  });

  return { success: true, id: docRef.id };
});

export const listHqBillingRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const selectedSiteId = asTrimmedString(request.data?.siteId);
  const now = new Date();
  const start = periodStart(request.data?.period, now);
  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 1000
    ? request.data.limit
    : 500;

  let siteDocs: FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>[] = [];
  if (selectedSiteId.length > 0) {
    const selectedDoc = await admin.firestore().collection('sites').doc(selectedSiteId).get();
    siteDocs = selectedDoc.exists ? [selectedDoc] : [];
  } else {
    const sitesSnap = await admin.firestore().collection('sites').limit(500).get();
    siteDocs = sitesSnap.docs;
  }

  let payoutsQuery: FirebaseFirestore.Query = admin.firestore().collection('payouts').limit(limitValue);
  if (selectedSiteId.length > 0) {
    payoutsQuery = payoutsQuery.where('siteId', '==', selectedSiteId);
  }
  const payoutsSnap = await payoutsQuery.get();

  const siteNames: Record<string, string> = {};
  const siteRows = siteDocs.map((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const siteName = asTrimmedString(data.name) || docSnap.id;
    siteNames[docSnap.id] = siteName;
    return {
      id: docSnap.id,
      label: siteName,
      data,
    };
  });

  const invoices: Array<{
    id: string;
    parent: string;
    learner: string;
    site: string;
    amount: number;
    status: 'paid' | 'pending' | 'overdue';
    date: string;
  }> = [];
  const payments: Array<{
    id: string;
    from: string;
    method: string;
    amount: number;
    date: string;
    invoice: string;
  }> = [];

  for (const docSnap of payoutsSnap.docs) {
    const data = docSnap.data() as Record<string, unknown>;
    const rowSiteId = asTrimmedString(data.siteId);
    if (selectedSiteId.length > 0 && rowSiteId !== selectedSiteId) continue;

    const createdAt = toDateValue(data.createdAt) || toDateValue(data.updatedAt) || now;
    if (createdAt < start || createdAt > now) continue;

    const amount = asNumber(data.amount) ?? 0;
    const status = normalizeInvoiceStatus(data.status);
    const siteLabel = siteNames[rowSiteId] || (rowSiteId.length > 0 ? rowSiteId : 'Unknown');
    const parentName = asTrimmedString(data.parentName) || asTrimmedString(data.requestedBy) || asTrimmedString(data.createdBy) || 'Unknown';
    const learnerName = asTrimmedString(data.learnerName) || asTrimmedString(data.learnerId) || '-';
    const invoiceId = asTrimmedString(data.invoiceId) || docSnap.id;
    const dateIso = createdAt.toISOString();

    invoices.push({
      id: invoiceId,
      parent: parentName,
      learner: learnerName,
      site: siteLabel,
      amount,
      status,
      date: dateIso,
    });

    if (status === 'paid') {
      payments.push({
        id: docSnap.id,
        from: parentName,
        method: asTrimmedString(data.paymentMethod) || asTrimmedString(data.method) || 'Transfer',
        amount,
        date: dateIso,
        invoice: invoiceId,
      });
    }
  }

  const subscriptions = siteRows
    .filter((row) => selectedSiteId.length === 0 || row.id === selectedSiteId)
    .map((row) => ({
      parent: row.label,
      learners: asNumber(row.data.learnerCount) ?? (Array.isArray(row.data.learnerIds) ? row.data.learnerIds.length : 0),
      plan: asTrimmedString(row.data.billingPlan) || 'Standard',
      amount: asNumber(row.data.monthlyFee) ?? 0,
      status: normalizeSubscriptionStatus(row.data.billingStatus),
      nextBilling: toIsoString(row.data.nextBillingDate),
    }));

  return {
    siteOptions: [
      { id: 'all', label: 'All Sites' },
      ...siteRows.map((row) => ({ id: row.id, label: row.label })),
    ],
    invoices,
    payments,
    subscriptions,
  };
});

export const createHqInvoice = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const parentId = asTrimmedString(request.data?.parentId);
  const learnerId = asTrimmedString(request.data?.learnerId);
  const amount = asNumber(request.data?.amount);
  if (!parentId || !learnerId || amount === null || amount <= 0) {
    throw new HttpsError('invalid-argument', 'parentId, learnerId, and positive amount are required.');
  }

  const siteId = asTrimmedString(request.data?.siteId);
  const parentName = asTrimmedString(request.data?.parentName) || parentId;
  const learnerName = asTrimmedString(request.data?.learnerName) || learnerId;
  const description = asTrimmedString(request.data?.description);
  const currency = asTrimmedString(request.data?.currency).toUpperCase() || 'USD';
  const payoutRef = admin.firestore().collection('payouts').doc();
  const invoiceId = payoutRef.id;

  await payoutRef.set({
    type: 'invoice',
    invoiceId,
    status: 'pending',
    amount,
    currency,
    parentId,
    parentName,
    learnerId,
    learnerName,
    description,
    siteId: siteId || null,
    createdBy: actor.uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await admin.firestore().collection('auditLogs').add({
    actorId: actor.uid,
    actorRole: actor.role,
    action: 'billing.invoice_created',
    entityType: 'payouts',
    entityId: payoutRef.id,
    siteId: siteId || null,
    details: { invoiceId, amount, currency, parentId, learnerId },
    createdAt: FieldValue.serverTimestamp(),
  });

  return { success: true, id: payoutRef.id, invoiceId };
});
