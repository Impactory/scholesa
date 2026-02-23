import { randomUUID } from 'crypto';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

type Role = 'learner' | 'educator' | 'parent' | 'site' | 'partner' | 'hq';
type ParentRequestType = 'export' | 'delete' | 'correction';
type ParentRequestStatus = 'submitted' | 'processing' | 'completed' | 'failed' | 'cancelled';

interface UserRecord {
  role?: Role;
  siteIds?: string[];
  activeSiteId?: string;
  isActive?: boolean;
  lastActiveAt?: unknown;
  lastLoginAt?: unknown;
  updatedAt?: unknown;
  createdAt?: unknown;
}

interface SchoolConsentPayload {
  siteId: string;
  agreementSigned: boolean;
  educationalUseOnly: boolean;
  parentNoticeProvided: boolean;
  noStudentMarketing: boolean;
  signedBy?: string;
  districtAgreementRef?: string;
  notes?: string;
}

interface RetentionOverridePayload {
  siteId: string;
  inactiveMonths: number;
  aiLogMonths: number;
  notes?: string;
}

interface SubmitParentRequestPayload {
  siteId: string;
  learnerId: string;
  requestType: ParentRequestType;
  districtTicketId?: string;
  note?: string;
  traceId?: string;
}

interface ProcessParentRequestPayload {
  requestId: string;
  dryRun?: boolean;
  storagePrefixes?: string[];
}

interface RetentionRunPayload {
  dryRun?: boolean;
  siteId?: string;
}

interface RetentionPolicy {
  inactiveMonths: number;
  aiLogMonths: number;
}

interface LearnerCollectionScope {
  collection: string;
  learnerFields: string[];
  siteFields: string[];
}

interface ScopedDoc {
  collection: string;
  id: string;
  ref: FirebaseFirestore.DocumentReference;
  data: FirebaseFirestore.DocumentData;
  matchedBy: string;
}

interface ParentRequestReport {
  traceId: string;
  requestId: string;
  requestType: ParentRequestType;
  learnerId: string;
  siteId: string;
  dryRun: boolean;
  generatedAt: FirebaseFirestore.FieldValue;
  generatedBy: string;
  collectionSummaries: Array<{
    collection: string;
    count: number;
    matchedBy: string[];
    docIdsPreview: string[];
    truncated: boolean;
  }>;
  totals: {
    matchedDocuments: number;
    deletedDocuments: number;
    updatedDocuments: number;
    storagePrefixesProcessed: number;
    storagePrefixErrors: number;
  };
  userRecordAction: {
    action: 'none' | 'detached_site' | 'deleted_user_doc';
    authUserDeleted: boolean;
    notes: string[];
  };
  storage: {
    prefixes: string[];
    errors: string[];
  };
}

const USERS_COLLECTION = 'users';
const AUDIT_COLLECTION = 'auditLogs';
const AI_LOGS_COLLECTION = 'aiInteractionLogs';
const SCHOOL_CONSENT_COLLECTION = 'coppaSchoolConsents';
const PARENT_REQUEST_COLLECTION = 'coppaParentRequests';
const PARENT_REPORT_COLLECTION = 'coppaParentRequestReports';
const COPPA_TRACE_LOG_COLLECTION = 'coppaTraceLogs';
const RETENTION_OVERRIDE_COLLECTION = 'coppaRetentionOverrides';
const RETENTION_RUN_COLLECTION = 'coppaRetentionRuns';

const DEFAULT_RETENTION_POLICY: RetentionPolicy = {
  inactiveMonths: 24,
  aiLogMonths: 12,
};

const MAX_DOCS_PER_QUERY = 400;
const MAX_DOC_ID_PREVIEW = 40;
const MAX_AI_LOG_DELETES_PER_RUN = 400;
const MAX_INACTIVE_USERS_SCANNED_PER_RUN = 120;
const MAX_INACTIVE_LEARNER_DELETIONS_PER_RUN = 10;

const LEARNER_COLLECTION_SCOPES: LearnerCollectionScope[] = [
  { collection: 'missionAttempts', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'reflections', learnerFields: ['userId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'attendanceRecords', learnerFields: ['userId', 'learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'enrollments', learnerFields: ['userId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'portfolioItems', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'portfolios', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'learnerReflections', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'learnerGoals', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'learnerInterestProfiles', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'skillMastery', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'recognitionBadges', learnerFields: ['recipientId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'checkpointHistory', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'showcaseSubmissions', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'aiInteractionLogs', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'interactionEvents', learnerFields: ['actorId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'mvlEpisodes', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'learnerProgress', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'activities', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId'] },
  { collection: 'guardianLinks', learnerFields: ['learnerId'], siteFields: ['siteId', 'studioId', 'siteIds'] },
  { collection: 'parentLinks', learnerFields: ['studentUserId', 'learnerId'], siteFields: ['siteId', 'studioId'] },
];

function mustString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${field} is required`);
  }
  return value.trim();
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string' && entry.trim().length > 0);
}

function asMillis(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (value && typeof value === 'object') {
    const asObj = value as Record<string, unknown>;
    const maybeToMillis = asObj.toMillis;
    if (typeof maybeToMillis === 'function') {
      try {
        const millis = (maybeToMillis as () => number)();
        if (Number.isFinite(millis)) return millis;
      } catch {
        return null;
      }
    }
    const seconds = asObj._seconds;
    const nanoseconds = asObj._nanoseconds;
    if (typeof seconds === 'number' && typeof nanoseconds === 'number') {
      return seconds * 1000 + Math.floor(nanoseconds / 1_000_000);
    }
  }
  return null;
}

function monthsToMs(months: number): number {
  return months * 30 * 24 * 60 * 60 * 1000;
}

function pickPrimarySiteId(user: UserRecord): string | null {
  if (typeof user.activeSiteId === 'string' && user.activeSiteId.trim().length > 0) {
    return user.activeSiteId.trim();
  }
  const sites = toStringArray(user.siteIds);
  return sites.length > 0 ? sites[0] : null;
}

function getSiteCandidates(data: FirebaseFirestore.DocumentData): string[] {
  const siteCandidates: string[] = [];
  const scalarFields = ['siteId', 'studioId', 'activeSiteId'];
  for (const field of scalarFields) {
    const value = data[field];
    if (typeof value === 'string' && value.trim().length > 0) {
      siteCandidates.push(value.trim());
    }
  }

  const arrayFields = ['siteIds'];
  for (const field of arrayFields) {
    const values = toStringArray(data[field]);
    siteCandidates.push(...values);
  }

  return [...new Set(siteCandidates)];
}

function isInSiteScope(
  data: FirebaseFirestore.DocumentData,
  siteId: string,
  siteFields: string[],
): boolean {
  if (siteFields.length === 0) return true;
  for (const field of siteFields) {
    const value = data[field];
    if (typeof value === 'string' && value.trim() === siteId) {
      return true;
    }
    if (Array.isArray(value) && value.some((entry) => typeof entry === 'string' && entry.trim() === siteId)) {
      return true;
    }
  }
  return false;
}

async function getUserProfile(uid: string): Promise<UserRecord | undefined> {
  const snap = await admin.firestore().collection(USERS_COLLECTION).doc(uid).get();
  return snap.data() as UserRecord | undefined;
}

async function requireRoleAndSite(authUid: string | undefined, roles: Role[], siteId?: string) {
  if (!authUid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  const profile = await getUserProfile(authUid);
  if (!profile || !profile.role || !roles.includes(profile.role)) {
    throw new HttpsError('permission-denied', 'Insufficient role');
  }

  if (siteId && profile.role !== 'hq') {
    const siteIds = toStringArray(profile.siteIds);
    const allowed = siteIds.includes(siteId) || profile.activeSiteId === siteId;
    if (!allowed) {
      throw new HttpsError('permission-denied', 'Site access denied');
    }
  }

  return { uid: authUid, role: profile.role, profile };
}

async function appendTraceLog(params: {
  traceId: string;
  siteId: string;
  learnerId?: string;
  action: string;
  actorId: string;
  actorRole: Role | 'system';
  details?: Record<string, unknown>;
}) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  await admin.firestore().collection(COPPA_TRACE_LOG_COLLECTION).add({
    traceId: params.traceId,
    siteId: params.siteId,
    learnerId: params.learnerId || null,
    action: params.action,
    actorId: params.actorId,
    actorRole: params.actorRole,
    details: params.details ?? {},
    createdAt: now,
  });

  await admin.firestore().collection(AUDIT_COLLECTION).add({
    actorId: params.actorId,
    actorRole: params.actorRole,
    action: `coppa.${params.action}`,
    entityType: 'coppa',
    entityId: params.traceId,
    details: {
      siteId: params.siteId,
      learnerId: params.learnerId || null,
      ...(params.details ?? {}),
    },
    createdAt: now,
  });
}

async function getRetentionOverridesBySite(): Promise<Map<string, RetentionPolicy>> {
  const snap = await admin.firestore().collection(RETENTION_OVERRIDE_COLLECTION).get();
  const bySite = new Map<string, RetentionPolicy>();
  snap.forEach((doc) => {
    const data = doc.data();
    const inactiveMonths = typeof data.inactiveMonths === 'number' && data.inactiveMonths > 0
      ? Math.floor(data.inactiveMonths)
      : DEFAULT_RETENTION_POLICY.inactiveMonths;
    const aiLogMonths = typeof data.aiLogMonths === 'number' && data.aiLogMonths > 0
      ? Math.floor(data.aiLogMonths)
      : DEFAULT_RETENTION_POLICY.aiLogMonths;
    bySite.set(doc.id, { inactiveMonths, aiLogMonths });
  });
  return bySite;
}

function getRetentionPolicyForSite(siteId: string | null, overrides: Map<string, RetentionPolicy>): RetentionPolicy {
  if (!siteId) return DEFAULT_RETENTION_POLICY;
  return overrides.get(siteId) || DEFAULT_RETENTION_POLICY;
}

async function collectLearnerScopedDocs(siteId: string, learnerId: string): Promise<ScopedDoc[]> {
  const allMatches: ScopedDoc[] = [];

  for (const scope of LEARNER_COLLECTION_SCOPES) {
    const matchesById = new Map<string, ScopedDoc>();
    for (const learnerField of scope.learnerFields) {
      const snap = await admin
        .firestore()
        .collection(scope.collection)
        .where(learnerField, '==', learnerId)
        .limit(MAX_DOCS_PER_QUERY)
        .get();

      snap.forEach((doc) => {
        const data = doc.data();
        if (scope.siteFields.length > 0 && !isInSiteScope(data, siteId, scope.siteFields)) {
          return;
        }
        if (!matchesById.has(doc.id)) {
          matchesById.set(doc.id, {
            collection: scope.collection,
            id: doc.id,
            ref: doc.ref,
            data,
            matchedBy: learnerField,
          });
        }
      });
    }
    allMatches.push(...matchesById.values());
  }

  return allMatches;
}

async function deleteDocsInBatches(docRefs: FirebaseFirestore.DocumentReference[], dryRun: boolean): Promise<number> {
  if (dryRun || docRefs.length === 0) return 0;

  let deleted = 0;
  for (let index = 0; index < docRefs.length; index += 450) {
    const chunk = docRefs.slice(index, index + 450);
    const batch = admin.firestore().batch();
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

async function detachOrDeleteUserRecord(params: {
  siteId: string;
  learnerId: string;
  dryRun: boolean;
}): Promise<{
  action: 'none' | 'detached_site' | 'deleted_user_doc';
  updatedDocuments: number;
  authUserDeleted: boolean;
  notes: string[];
}> {
  const notes: string[] = [];
  const userRef = admin.firestore().collection(USERS_COLLECTION).doc(params.learnerId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    notes.push('No users/{learnerId} document found.');
    return { action: 'none', updatedDocuments: 0, authUserDeleted: false, notes };
  }

  const userData = userSnap.data() as UserRecord;
  const siteIds = toStringArray(userData.siteIds);
  const activeSiteId = typeof userData.activeSiteId === 'string' ? userData.activeSiteId : null;
  const userHasSite = siteIds.includes(params.siteId) || activeSiteId === params.siteId || siteIds.length === 0;

  if (!userHasSite) {
    notes.push('Learner user record not scoped to requested site; skipped user doc mutation.');
    return { action: 'none', updatedDocuments: 0, authUserDeleted: false, notes };
  }

  const remainingSiteIds = siteIds.filter((id) => id !== params.siteId);
  const shouldDeleteUserDoc = remainingSiteIds.length === 0;

  if (params.dryRun) {
    return {
      action: shouldDeleteUserDoc ? 'deleted_user_doc' : 'detached_site',
      updatedDocuments: 1,
      authUserDeleted: shouldDeleteUserDoc,
      notes,
    };
  }

  if (shouldDeleteUserDoc) {
    await userRef.delete();
    let authUserDeleted = false;
    try {
      await admin.auth().deleteUser(params.learnerId);
      authUserDeleted = true;
    } catch (error) {
      notes.push(`Auth user delete skipped/failed: ${(error as Error).message}`);
    }
    return {
      action: 'deleted_user_doc',
      updatedDocuments: 1,
      authUserDeleted,
      notes,
    };
  }

  const updates: Record<string, unknown> = {
    siteIds: remainingSiteIds,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (activeSiteId === params.siteId) {
    if (remainingSiteIds.length > 0) {
      updates.activeSiteId = remainingSiteIds[0];
    } else {
      updates.activeSiteId = admin.firestore.FieldValue.delete();
    }
  }
  await userRef.update(updates);
  return {
    action: 'detached_site',
    updatedDocuments: 1,
    authUserDeleted: false,
    notes,
  };
}

async function processStoragePrefixes(params: {
  siteId: string;
  learnerId: string;
  dryRun: boolean;
  extraPrefixes: string[];
}): Promise<{ prefixes: string[]; errors: string[] }> {
  const defaultPrefixes = [
    `sites/${params.siteId}/learners/${params.learnerId}/`,
    `artifacts/${params.siteId}/${params.learnerId}/`,
  ];
  const prefixes = [...new Set([...defaultPrefixes, ...params.extraPrefixes])];
  const errors: string[] = [];

  if (params.dryRun) {
    return { prefixes, errors };
  }

  const bucket = admin.storage().bucket();
  for (const prefix of prefixes) {
    try {
      await bucket.deleteFiles({ prefix, force: true });
    } catch (error) {
      errors.push(`${prefix}: ${(error as Error).message}`);
    }
  }
  return { prefixes, errors };
}

function buildCollectionSummaries(matches: ScopedDoc[]) {
  const map = new Map<
    string,
    {
      collection: string;
      count: number;
      matchedBy: Set<string>;
      docIdsPreview: string[];
      truncated: boolean;
    }
  >();

  for (const match of matches) {
    const current = map.get(match.collection) || {
      collection: match.collection,
      count: 0,
      matchedBy: new Set<string>(),
      docIdsPreview: [],
      truncated: false,
    };
    current.count += 1;
    current.matchedBy.add(match.matchedBy);
    if (current.docIdsPreview.length < MAX_DOC_ID_PREVIEW) {
      current.docIdsPreview.push(match.id);
    } else {
      current.truncated = true;
    }
    map.set(match.collection, current);
  }

  return [...map.values()].map((entry) => ({
    collection: entry.collection,
    count: entry.count,
    matchedBy: [...entry.matchedBy],
    docIdsPreview: entry.docIdsPreview,
    truncated: entry.truncated,
  }));
}

async function executeParentRequest(params: {
  requestId: string;
  siteId: string;
  learnerId: string;
  requestType: ParentRequestType;
  traceId: string;
  actorId: string;
  actorRole: Role;
  dryRun: boolean;
  storagePrefixes: string[];
}): Promise<ParentRequestReport> {
  const matches = await collectLearnerScopedDocs(params.siteId, params.learnerId);
  const docRefs = matches.map((doc) => doc.ref);
  let deletedDocuments = 0;
  let updatedDocuments = 0;
  let userRecordAction: ParentRequestReport['userRecordAction'] = {
    action: 'none',
    authUserDeleted: false,
    notes: [],
  };
  let storage: ParentRequestReport['storage'] = {
    prefixes: [],
    errors: [],
  };

  if (params.requestType === 'delete') {
    deletedDocuments = await deleteDocsInBatches(docRefs, params.dryRun);
    const userMutation = await detachOrDeleteUserRecord({
      siteId: params.siteId,
      learnerId: params.learnerId,
      dryRun: params.dryRun,
    });
    userRecordAction = {
      action: userMutation.action,
      authUserDeleted: userMutation.authUserDeleted,
      notes: userMutation.notes,
    };
    updatedDocuments += userMutation.updatedDocuments;
    storage = await processStoragePrefixes({
      siteId: params.siteId,
      learnerId: params.learnerId,
      dryRun: params.dryRun,
      extraPrefixes: params.storagePrefixes,
    });
  }

  const report: ParentRequestReport = {
    traceId: params.traceId,
    requestId: params.requestId,
    requestType: params.requestType,
    learnerId: params.learnerId,
    siteId: params.siteId,
    dryRun: params.dryRun,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    generatedBy: params.actorId,
    collectionSummaries: buildCollectionSummaries(matches),
    totals: {
      matchedDocuments: matches.length,
      deletedDocuments,
      updatedDocuments,
      storagePrefixesProcessed: storage.prefixes.length,
      storagePrefixErrors: storage.errors.length,
    },
    userRecordAction,
    storage,
  };
  return report;
}

async function executeRetentionSweep(params: {
  dryRun: boolean;
  triggeredBy: string;
  actorRole: Role | 'system';
  siteId?: string;
}) {
  const startedAt = admin.firestore.Timestamp.now();
  const overrides = await getRetentionOverridesBySite();
  const nowMs = Date.now();
  const defaultAiCutoffMs = nowMs - monthsToMs(DEFAULT_RETENTION_POLICY.aiLogMonths);
  const aiCutoffForQueryMs = params.siteId
    ? nowMs - monthsToMs(getRetentionPolicyForSite(params.siteId, overrides).aiLogMonths)
    : defaultAiCutoffMs;
  const aiCutoffTs = admin.firestore.Timestamp.fromMillis(aiCutoffForQueryMs);

  const aiCandidatesSnap = await admin
    .firestore()
    .collection(AI_LOGS_COLLECTION)
    .where('createdAt', '<', aiCutoffTs)
    .limit(MAX_AI_LOG_DELETES_PER_RUN)
    .get();

  const aiDocsToDelete: FirebaseFirestore.DocumentReference[] = [];
  aiCandidatesSnap.forEach((doc) => {
    const data = doc.data();
    const candidateSiteId = typeof data.siteId === 'string' ? data.siteId : null;
    if (params.siteId && candidateSiteId !== params.siteId) {
      return;
    }
    const policy = getRetentionPolicyForSite(candidateSiteId, overrides);
    const effectiveCutoffMs = nowMs - monthsToMs(policy.aiLogMonths);
    const createdAtMs = asMillis(data.createdAt);
    if (createdAtMs !== null && createdAtMs <= effectiveCutoffMs) {
      aiDocsToDelete.push(doc.ref);
    }
  });

  const aiLogsDeleted = await deleteDocsInBatches(aiDocsToDelete, params.dryRun);

  let usersQuery: FirebaseFirestore.Query = admin.firestore().collection(USERS_COLLECTION).limit(MAX_INACTIVE_USERS_SCANNED_PER_RUN);
  if (params.siteId) {
    usersQuery = usersQuery.where('siteIds', 'array-contains', params.siteId);
  } else {
    usersQuery = usersQuery.where('isActive', '==', false);
  }
  const inactiveUsersSnap = await usersQuery.get();

  let inactiveLearnerCandidates = 0;
  let inactiveLearnersProcessed = 0;
  let inactiveLearnersSkippedNoSite = 0;
  const retentionTraceIds: string[] = [];

  for (const userDoc of inactiveUsersSnap.docs) {
    if (inactiveLearnersProcessed >= MAX_INACTIVE_LEARNER_DELETIONS_PER_RUN) {
      break;
    }
    const user = userDoc.data() as UserRecord;
    if (user.role !== 'learner' || user.isActive !== false) {
      continue;
    }

    const primarySiteId = params.siteId || pickPrimarySiteId(user);
    if (!primarySiteId) {
      inactiveLearnersSkippedNoSite += 1;
      continue;
    }

    const policy = getRetentionPolicyForSite(primarySiteId, overrides);
    const inactiveCutoffMs = nowMs - monthsToMs(policy.inactiveMonths);
    const lastActivityMs = asMillis(user.lastActiveAt)
      ?? asMillis(user.lastLoginAt)
      ?? asMillis(user.updatedAt)
      ?? asMillis(user.createdAt);
    if (lastActivityMs === null || lastActivityMs > inactiveCutoffMs) {
      continue;
    }

    inactiveLearnerCandidates += 1;
    const traceId = `retention-${randomUUID()}`;
    retentionTraceIds.push(traceId);
    await appendTraceLog({
      traceId,
      siteId: primarySiteId,
      learnerId: userDoc.id,
      action: 'retention_candidate',
      actorId: params.triggeredBy,
      actorRole: params.actorRole,
      details: {
        reason: 'inactive_account',
        policyMonths: policy.inactiveMonths,
        lastActivityMs,
        dryRun: params.dryRun,
      },
    });

    if (params.dryRun) {
      inactiveLearnersProcessed += 1;
      continue;
    }

    const tempRequestId = `retention-${userDoc.id}-${Date.now()}`;
    const report = await executeParentRequest({
      requestId: tempRequestId,
      siteId: primarySiteId,
      learnerId: userDoc.id,
      requestType: 'delete',
      traceId,
      actorId: params.triggeredBy,
      actorRole: params.actorRole === 'system' ? 'hq' : params.actorRole,
      dryRun: false,
      storagePrefixes: [],
    });

    await admin.firestore().collection(PARENT_REPORT_COLLECTION).doc(tempRequestId).set({
      ...report,
      source: 'retentionSweep',
    });

    await appendTraceLog({
      traceId,
      siteId: primarySiteId,
      learnerId: userDoc.id,
      action: 'retention_delete_completed',
      actorId: params.triggeredBy,
      actorRole: params.actorRole,
      details: {
        requestId: tempRequestId,
        deletedDocuments: report.totals.deletedDocuments,
        updatedDocuments: report.totals.updatedDocuments,
      },
    });
    inactiveLearnersProcessed += 1;
  }

  const finishedAt = admin.firestore.Timestamp.now();
  const runRecord = {
    startedAt,
    finishedAt,
    dryRun: params.dryRun,
    triggeredBy: params.triggeredBy,
    actorRole: params.actorRole,
    siteId: params.siteId || null,
    aiLogRetention: {
      candidates: aiCandidatesSnap.size,
      matchedForDeletion: aiDocsToDelete.length,
      deleted: aiLogsDeleted,
      queryCutoffMs: aiCutoffForQueryMs,
    },
    inactiveLearners: {
      candidates: inactiveLearnerCandidates,
      processed: inactiveLearnersProcessed,
      skippedNoSite: inactiveLearnersSkippedNoSite,
      traceIds: retentionTraceIds,
    },
  };

  const runRef = await admin.firestore().collection(RETENTION_RUN_COLLECTION).add(runRecord);
  return { runId: runRef.id, ...runRecord };
}

export const upsertSchoolConsentRecord = onCall(async (request: CallableRequest<SchoolConsentPayload>) => {
  const siteId = mustString(request.data?.siteId, 'siteId');
  const actor = await requireRoleAndSite(request.auth?.uid, ['site', 'hq'], siteId);

  const data = request.data;
  const requiredBooleans: Array<keyof SchoolConsentPayload> = [
    'agreementSigned',
    'educationalUseOnly',
    'parentNoticeProvided',
    'noStudentMarketing',
  ];
  for (const key of requiredBooleans) {
    if (typeof data[key] !== 'boolean') {
      throw new HttpsError('invalid-argument', `${key} must be a boolean`);
    }
  }

  const consentRef = admin.firestore().collection(SCHOOL_CONSENT_COLLECTION).doc(siteId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  await consentRef.set({
    siteId,
    agreementSigned: data.agreementSigned,
    educationalUseOnly: data.educationalUseOnly,
    parentNoticeProvided: data.parentNoticeProvided,
    noStudentMarketing: data.noStudentMarketing,
    signedBy: typeof data.signedBy === 'string' ? data.signedBy.trim() : null,
    districtAgreementRef: typeof data.districtAgreementRef === 'string' ? data.districtAgreementRef.trim() : null,
    notes: typeof data.notes === 'string' ? data.notes.trim() : null,
    active: data.agreementSigned && data.educationalUseOnly && data.parentNoticeProvided && data.noStudentMarketing,
    updatedBy: actor.uid,
    updatedAt: now,
  }, { merge: true });

  await appendTraceLog({
    traceId: `consent-${siteId}-${Date.now()}`,
    siteId,
    action: 'school_consent_upserted',
    actorId: actor.uid,
    actorRole: actor.role,
    details: {
      active: data.agreementSigned && data.educationalUseOnly && data.parentNoticeProvided && data.noStudentMarketing,
    },
  });

  return {
    status: 'ok',
    siteId,
    active: data.agreementSigned && data.educationalUseOnly && data.parentNoticeProvided && data.noStudentMarketing,
  };
});

export const getSchoolConsentRecord = onCall(async (request: CallableRequest<{ siteId: string }>) => {
  const siteId = mustString(request.data?.siteId, 'siteId');
  await requireRoleAndSite(request.auth?.uid, ['educator', 'site', 'hq'], siteId);

  const snap = await admin.firestore().collection(SCHOOL_CONSENT_COLLECTION).doc(siteId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'School consent record not found for this site');
  }
  return { siteId, ...(snap.data() as Record<string, unknown>) };
});

export const upsertCoppaRetentionOverride = onCall(async (request: CallableRequest<RetentionOverridePayload>) => {
  const actor = await requireRoleAndSite(request.auth?.uid, ['hq']);
  const siteId = mustString(request.data?.siteId, 'siteId');
  const inactiveMonths = request.data?.inactiveMonths;
  const aiLogMonths = request.data?.aiLogMonths;
  if (typeof inactiveMonths !== 'number' || inactiveMonths <= 0 || inactiveMonths > 120) {
    throw new HttpsError('invalid-argument', 'inactiveMonths must be between 1 and 120');
  }
  if (typeof aiLogMonths !== 'number' || aiLogMonths <= 0 || aiLogMonths > 120) {
    throw new HttpsError('invalid-argument', 'aiLogMonths must be between 1 and 120');
  }

  await admin.firestore().collection(RETENTION_OVERRIDE_COLLECTION).doc(siteId).set({
    siteId,
    inactiveMonths: Math.floor(inactiveMonths),
    aiLogMonths: Math.floor(aiLogMonths),
    notes: typeof request.data?.notes === 'string' ? request.data.notes.trim() : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  }, { merge: true });

  return {
    status: 'ok',
    siteId,
    inactiveMonths: Math.floor(inactiveMonths),
    aiLogMonths: Math.floor(aiLogMonths),
  };
});

export const submitParentDataRequest = onCall(async (request: CallableRequest<SubmitParentRequestPayload>) => {
  const siteId = mustString(request.data?.siteId, 'siteId');
  const learnerId = mustString(request.data?.learnerId, 'learnerId');
  const requestTypeRaw = mustString(request.data?.requestType, 'requestType');
  if (!['export', 'delete', 'correction'].includes(requestTypeRaw)) {
    throw new HttpsError('invalid-argument', 'requestType must be export, delete, or correction');
  }
  const requestType = requestTypeRaw as ParentRequestType;

  const actor = await requireRoleAndSite(request.auth?.uid, ['educator', 'site', 'hq'], siteId);
  const traceId = typeof request.data?.traceId === 'string' && request.data.traceId.trim().length > 0
    ? request.data.traceId.trim()
    : randomUUID();

  const parentRequestRef = admin.firestore().collection(PARENT_REQUEST_COLLECTION).doc();
  await parentRequestRef.set({
    traceId,
    siteId,
    learnerId,
    requestType,
    status: 'submitted' as ParentRequestStatus,
    districtTicketId: typeof request.data?.districtTicketId === 'string' ? request.data.districtTicketId.trim() : null,
    note: typeof request.data?.note === 'string' ? request.data.note.trim() : null,
    submittedBy: actor.uid,
    submittedByRole: actor.role,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await appendTraceLog({
    traceId,
    siteId,
    learnerId,
    action: 'parent_request_submitted',
    actorId: actor.uid,
    actorRole: actor.role,
    details: {
      requestId: parentRequestRef.id,
      requestType,
    },
  });

  return {
    status: 'submitted',
    requestId: parentRequestRef.id,
    traceId,
    requestType,
  };
});

export const processParentDataRequest = onCall(async (request: CallableRequest<ProcessParentRequestPayload>) => {
  const requestId = mustString(request.data?.requestId, 'requestId');
  const dryRun = request.data?.dryRun === true;
  const storagePrefixes = toStringArray(request.data?.storagePrefixes);

  const requestRef = admin.firestore().collection(PARENT_REQUEST_COLLECTION).doc(requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) {
    throw new HttpsError('not-found', 'Parent request not found');
  }

  const requestData = requestSnap.data() as {
    traceId: string;
    siteId: string;
    learnerId: string;
    requestType: ParentRequestType;
    status: ParentRequestStatus;
  };
  const actor = await requireRoleAndSite(request.auth?.uid, ['site', 'hq'], requestData.siteId);

  if (requestData.status === 'completed' && !dryRun) {
    const existingReport = await admin.firestore().collection(PARENT_REPORT_COLLECTION).doc(requestId).get();
    return {
      status: 'already_completed',
      requestId,
      traceId: requestData.traceId,
      report: existingReport.exists ? existingReport.data() : null,
    };
  }

  await requestRef.set({
    status: 'processing' as ParentRequestStatus,
    processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    processedBy: actor.uid,
    processedByRole: actor.role,
    dryRun,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await appendTraceLog({
    traceId: requestData.traceId,
    siteId: requestData.siteId,
    learnerId: requestData.learnerId,
    action: 'parent_request_processing_started',
    actorId: actor.uid,
    actorRole: actor.role,
    details: {
      requestId,
      requestType: requestData.requestType,
      dryRun,
    },
  });

  try {
    const report = await executeParentRequest({
      requestId,
      siteId: requestData.siteId,
      learnerId: requestData.learnerId,
      requestType: requestData.requestType,
      traceId: requestData.traceId,
      actorId: actor.uid,
      actorRole: actor.role,
      dryRun,
      storagePrefixes,
    });

    await admin.firestore().collection(PARENT_REPORT_COLLECTION).doc(requestId).set(report);
    await requestRef.set({
      status: 'completed' as ParentRequestStatus,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      reportRef: `${PARENT_REPORT_COLLECTION}/${requestId}`,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await appendTraceLog({
      traceId: requestData.traceId,
      siteId: requestData.siteId,
      learnerId: requestData.learnerId,
      action: 'parent_request_completed',
      actorId: actor.uid,
      actorRole: actor.role,
      details: {
        requestId,
        requestType: requestData.requestType,
        totals: report.totals,
      },
    });

    return {
      status: 'completed',
      requestId,
      traceId: requestData.traceId,
      report,
    };
  } catch (error) {
    await requestRef.set({
      status: 'failed' as ParentRequestStatus,
      errorMessage: (error as Error).message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await appendTraceLog({
      traceId: requestData.traceId,
      siteId: requestData.siteId,
      learnerId: requestData.learnerId,
      action: 'parent_request_failed',
      actorId: actor.uid,
      actorRole: actor.role,
      details: {
        requestId,
        error: (error as Error).message,
      },
    });
    throw error;
  }
});

export const runCoppaRetentionSweep = onCall(async (request: CallableRequest<RetentionRunPayload>) => {
  const siteId = typeof request.data?.siteId === 'string' && request.data.siteId.trim().length > 0
    ? request.data.siteId.trim()
    : undefined;
  const dryRun = request.data?.dryRun === true;

  const actor = await requireRoleAndSite(request.auth?.uid, ['site', 'hq'], siteId);
  const result = await executeRetentionSweep({
    dryRun,
    triggeredBy: actor.uid,
    actorRole: actor.role,
    siteId,
  });

  return { status: 'ok', ...result };
});

export const scheduledCoppaRetentionSweep = onSchedule('30 3 * * *', async () => {
  await executeRetentionSweep({
    dryRun: false,
    triggeredBy: 'system:scheduler',
    actorRole: 'system',
  });
});

export const getCoppaComplianceSnapshot = onCall(async (request: CallableRequest<{ siteId: string }>) => {
  const siteId = mustString(request.data?.siteId, 'siteId');
  await requireRoleAndSite(request.auth?.uid, ['educator', 'site', 'hq'], siteId);

  const [consentSnap, requestsSnap, overrides] = await Promise.all([
    admin.firestore().collection(SCHOOL_CONSENT_COLLECTION).doc(siteId).get(),
    admin
      .firestore()
      .collection(PARENT_REQUEST_COLLECTION)
      .where('siteId', '==', siteId)
      .orderBy('submittedAt', 'desc')
      .limit(20)
      .get(),
    getRetentionOverridesBySite(),
  ]);

  const consentData = consentSnap.exists ? consentSnap.data() : null;
  const recentRequests = requestsSnap.docs.map((doc) => {
    const data = doc.data();
    return {
      requestId: doc.id,
      traceId: data.traceId,
      learnerId: data.learnerId,
      requestType: data.requestType,
      status: data.status,
      submittedAt: data.submittedAt || null,
      completedAt: data.completedAt || null,
    };
  });

  const retentionPolicy = getRetentionPolicyForSite(siteId, overrides);
  return {
    siteId,
    consent: consentData,
    retentionPolicy,
    recentParentRequests: recentRequests,
    noAdvertisingPolicy: {
      enabled: true,
      policyRef: 'Scholesa_COPPA_Operational_Pack/08_NO_ADVERTISING_POLICY.md',
    },
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
});
