import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import './gen2Runtime';
import {
  buildLtiGradePassbackAuditLog,
  buildLtiGradePassbackJob,
  normalizeIntegrationProvider,
} from './ltiIntegration';
import {
  buildDistrictConnectionDocId,
  type DistrictProvider,
  districtProviderAuditAction,
  districtProviderDefaultAuthBaseUrl,
  districtProviderDisplayName,
  districtProviderRosterSyncJobType,
  districtProviderSchoolField,
  districtProviderSectionsField,
} from './districtProviderIntegration';
import {
  buildFederatedLearningAggregationRunDocId,
  buildFederatedLearningCandidateModelPackageDocId,
  buildFederatedLearningCandidatePromotionRecordDocId,
  buildFederatedLearningCandidatePromotionRevocationRecordDocId,
  buildFederatedLearningExperimentReviewRecordDocId,
  buildFederatedLearningPilotEvidenceRecordDocId,
  buildFederatedLearningPilotApprovalRecordDocId,
  buildFederatedLearningPilotExecutionRecordDocId,
  buildFederatedLearningRuntimeDeliveryRecordDocId,
  buildFederatedLearningRuntimeDeliveryManifestDigest,
  buildFederatedLearningRuntimeActivationRecordDocId,
  buildFederatedLearningRuntimeRolloutAlertRecordDocId,
  buildFederatedLearningRuntimeRolloutEscalationRecordDocId,
  buildFederatedLearningRuntimeRolloutControlRecordDocId,
  buildFederatedLearningContributionDetails,
  buildFederatedLearningMergeWeightSummary,
  buildFederatedLearningMergedRuntimeVector,
  buildFederatedLearningCandidateModelPackageSummary,
  buildFederatedLearningMergeArtifactDocId,
  buildFederatedLearningMergeArtifactSummary,
  buildFederatedLearningExperimentDocId,
  buildFederatedLearningFeatureFlagId,
  buildFederatedLearningFeatureFlagPayload,
  FEDERATED_LEARNING_MERGE_STRATEGY,
  federatedLearningAuditAction,
  normalizeFederatedLearningCandidatePromotionStatus,
  normalizeFederatedLearningCandidatePromotionTarget,
  normalizeFederatedLearningExperimentReviewStatus,
  normalizeFederatedLearningMergeStrategy,
  normalizeFederatedLearningPilotEvidenceStatus,
  normalizeFederatedLearningPilotApprovalStatus,
  normalizeFederatedLearningPilotExecutionStatus,
  normalizeFederatedLearningRuntimeDeliveryStatus,
  normalizeFederatedLearningRuntimeActivationStatus,
  normalizeFederatedLearningRuntimeRolloutAlertStatus,
  normalizeFederatedLearningRuntimeRolloutEscalationStatus,
  normalizeFederatedLearningRuntimeRolloutControlMode,
  normalizeFederatedLearningRuntimeTarget,
  normalizeFederatedLearningBatteryState,
  normalizeFederatedLearningNetworkType,
  selectFederatedLearningAggregationBatch,
  sanitizeFederatedLearningExperimentConfig,
  sanitizeFederatedLearningUpdateSummary,
  type FederatedLearningBatteryState,
  type FederatedLearningNetworkType,
} from './federatedLearningPrototype';

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

function buildGovernanceApprovalError(feature: string): HttpsError {
  return new HttpsError(
    'failed-precondition',
    `${feature} is scaffolded but not approved for production rollout. Complete the governance artifact before enabling this path.`,
  );
}

function buildDistrictProviderGovernanceError(provider: DistrictProvider, feature: string): HttpsError {
  return buildGovernanceApprovalError(`${districtProviderDisplayName(provider)} ${feature}`);
}

function buildCleverConnectionDocId(siteId: string): string {
  return buildDistrictConnectionDocId('clever', siteId);
}

async function getCleverConnection(siteId: string) {
  const docId = buildDistrictConnectionDocId('clever', siteId);
  const docSnap = await admin.firestore().collection('integrationConnections').doc(docId).get();
  return docSnap.exists ? { id: docSnap.id, data: docSnap.data() as Record<string, unknown> } : null;
}

function buildClassLinkConnectionDocId(siteId: string): string {
  return buildDistrictConnectionDocId('classlink', siteId);
}

async function getDistrictProviderConnection(provider: DistrictProvider, siteId: string) {
  const docId = buildDistrictConnectionDocId(provider, siteId);
  const docSnap = await admin.firestore().collection('integrationConnections').doc(docId).get();
  return docSnap.exists ? { id: docSnap.id, data: docSnap.data() as Record<string, unknown> } : null;
}

async function getClassLinkConnection(siteId: string) {
  return getDistrictProviderConnection('classlink', siteId);
}

function normalizeReturnUrl(value: unknown): string {
  const raw = asTrimmedString(value);
  if (!raw) return '';
  try {
    const parsed = new URL(raw);
    return parsed.toString();
  } catch {
    return '';
  }
}

function districtProviderClientId(provider: DistrictProvider): string {
  const envKey = provider === 'clever' ? 'CLEVER_CLIENT_ID' : 'CLASSLINK_CLIENT_ID';
  return asTrimmedString(process.env[envKey]);
}

function districtProviderRedirectUri(provider: DistrictProvider): string {
  const envKey = provider === 'clever' ? 'CLEVER_REDIRECT_URI' : 'CLASSLINK_REDIRECT_URI';
  return asTrimmedString(process.env[envKey]);
}

function districtProviderAuthBaseUrl(provider: DistrictProvider): string {
  const envKey = provider === 'clever' ? 'CLEVER_AUTH_BASE_URL' : 'CLASSLINK_AUTH_BASE_URL';
  return asTrimmedString(process.env[envKey]) || districtProviderDefaultAuthBaseUrl(provider);
}

function districtProviderSchools(provider: DistrictProvider, data: Record<string, unknown>): Array<Record<string, unknown>> {
  const field = districtProviderSchoolField(provider);
  const schools = data[field];
  return Array.isArray(schools)
    ? schools.map((entry) => ({ ...(entry as Record<string, unknown>) }))
    : [];
}

function districtProviderSections(
  provider: DistrictProvider,
  data: Record<string, unknown>,
  schoolId: string,
): Array<Record<string, unknown>> {
  const field = districtProviderSectionsField(provider);
  const sectionMap = data[field];
  return sectionMap && typeof sectionMap === 'object' && !Array.isArray(sectionMap)
    ? ((sectionMap as Record<string, unknown>)[schoolId] as Array<Record<string, unknown>> | undefined) || []
    : [];
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function buildLtiRegistrationDocId(siteId: string, issuer: string, clientId: string, deploymentId: string): string {
  const raw = `${siteId.trim()}|${issuer.trim()}|${clientId.trim()}|${deploymentId.trim()}`;
  return `lti_${Buffer.from(raw).toString('base64url').slice(0, 120)}`;
}

function buildLtiResourceLinkDocId(registrationId: string, resourceLinkId: string): string {
  const raw = `${registrationId.trim()}|${resourceLinkId.trim()}`;
  return `lti_link_${Buffer.from(raw).toString('base64url').slice(0, 120)}`;
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

function asTimestampMillis(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

function buildRuntimeRolloutEscalationDueAt(
  status: 'open' | 'investigating' | 'resolved',
  fallbackCount: number,
  pendingCount: number,
  openedAt: number,
): number | null {
  if (status === 'resolved') {
    return null;
  }
  const hasFallback = fallbackCount > 0;
  const hasPendingOnly = !hasFallback && pendingCount > 0;
  if (!hasFallback && !hasPendingOnly) {
    return null;
  }
  const baseHours = hasFallback
    ? (status === 'investigating' ? 8 : 4)
    : (status === 'investigating' ? 48 : 24);
  return openedAt + (baseHours * 60 * 60 * 1000);
}

function getRuntimeDeliveryTerminalLifecycleStatus(
  deliveryData: Record<string, unknown>,
  now = Date.now(),
): 'expired' | 'revoked' | 'superseded' | null {
  const deliveryStatus = normalizeFederatedLearningRuntimeDeliveryStatus(deliveryData.status);
  if (deliveryStatus === 'revoked') {
    return 'revoked';
  }
  if (deliveryStatus === 'superseded') {
    return 'superseded';
  }
  const expiresAt = asTimestampMillis(deliveryData.expiresAt);
  if (expiresAt != null && expiresAt <= now) {
    return 'expired';
  }
  return null;
}

type RuntimeDeliveryLineageSnapshot = {
  runtimeTarget: string;
  targetSiteIds: string[];
  packageDigest: string;
  boundedDigest: string;
  triggerSummaryId: string;
  summaryIds: string[];
  schemaVersions: string[];
  optimizerStrategies: string[];
  compatibilityKey: string;
  warmStartPackageId: string;
  warmStartModelVersion: string;
  manifestDigest: string;
};

function buildRuntimeDeliveryLineageSnapshot(
  deliveryData: Record<string, unknown>,
): RuntimeDeliveryLineageSnapshot {
  return {
    runtimeTarget: normalizeFederatedLearningRuntimeTarget(deliveryData.runtimeTarget) || 'flutter_mobile',
    targetSiteIds: toStringArray(deliveryData.targetSiteIds),
    packageDigest: asTrimmedString(deliveryData.packageDigest),
    boundedDigest: asTrimmedString(deliveryData.boundedDigest),
    triggerSummaryId: asTrimmedString(deliveryData.triggerSummaryId),
    summaryIds: toStringArray(deliveryData.summaryIds),
    schemaVersions: toStringArray(deliveryData.schemaVersions),
    optimizerStrategies: toStringArray(deliveryData.optimizerStrategies),
    compatibilityKey: asTrimmedString(deliveryData.compatibilityKey),
    warmStartPackageId: asTrimmedString(deliveryData.warmStartPackageId),
    warmStartModelVersion: asTrimmedString(deliveryData.warmStartModelVersion),
    manifestDigest: asTrimmedString(deliveryData.manifestDigest),
  };
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
    const happenedAt = toDateValue(request.data?.happenedAt);
    const location = asTrimmedString(request.data?.location) || null;
    const involvedNames = asTrimmedString(request.data?.involvedNames) || null;
    const immediateAction = asTrimmedString(request.data?.immediateAction) || null;
    const correctiveAction = asTrimmedString(request.data?.correctiveAction) || null;
    const incidentType = asTrimmedString(request.data?.incidentType) || 'general';
    const severity = asTrimmedString(request.data?.severity) || 'medium';
    const investigationStatus = asTrimmedString(request.data?.investigationStatus) || 'open';
    const createdRef = await admin.firestore().collection('incidents').add({
      siteId,
      title,
      summary,
      status: 'open',
      severity,
      incidentType,
      happenedAt: happenedAt || null,
      location,
      involvedNames,
      immediateAction,
      correctiveAction,
      investigationStatus,
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

  const provider = normalizeIntegrationProvider(
    typeof request.data?.provider === 'string' ? request.data.provider : 'google-classroom',
  );
  const requestedType = typeof request.data?.type === 'string' ? request.data.type.trim().toLowerCase() : '';
  const jobType = requestedType || provider;
  const docRef = await admin.firestore().collection('syncJobs').add({
    siteId: requestedSiteId,
    provider,
    type: jobType,
    jobType,
    status: 'queued',
    requestedBy: actor.uid,
    requestedByRole: actor.role,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true, id: docRef.id };
});

export const upsertLtiPlatformRegistration = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : actor.profile.activeSiteId;
  if (!requestedSiteId || !actorCanAccessSite(actor, requestedSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const issuer = asTrimmedString(request.data?.issuer);
  const clientId = asTrimmedString(request.data?.clientId);
  const deploymentId = asTrimmedString(request.data?.deploymentId);
  const authLoginUrl = asTrimmedString(request.data?.authLoginUrl);
  const accessTokenUrl = asTrimmedString(request.data?.accessTokenUrl);
  const jwksUrl = asTrimmedString(request.data?.jwksUrl);
  if (!issuer || !clientId || !deploymentId || !authLoginUrl || !accessTokenUrl || !jwksUrl) {
    throw new HttpsError('invalid-argument', 'issuer, clientId, deploymentId, authLoginUrl, accessTokenUrl, and jwksUrl are required.');
  }

  const docId = typeof request.data?.id === 'string' && request.data.id.trim().length > 0
    ? request.data.id.trim()
    : buildLtiRegistrationDocId(requestedSiteId, issuer, clientId, deploymentId);
  const platformName = asTrimmedString(request.data?.platformName) || 'LTI 1.3';
  const lineItemsScope = request.data?.lineItemsScope !== false;
  const registrationPayload = {
    siteId: requestedSiteId,
    issuer,
    clientId,
    deploymentId,
    authLoginUrl,
    accessTokenUrl,
    jwksUrl,
    ownerUserId: actor.uid,
    platformName,
    lineItemsScope,
    provider: 'lti_1p3',
    status: 'active',
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection('ltiPlatformRegistrations').doc(docId).set(registrationPayload, { merge: true });
  await admin.firestore().collection('integrationConnections').doc(docId).set({
    siteId: requestedSiteId,
    ownerUserId: actor.uid,
    provider: 'lti_1p3',
    name: platformName,
    status: 'active',
    issuer,
    clientId,
    deploymentId,
    lineItemsScope,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true, id: docId };
});

export const upsertLtiResourceLink = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const registrationId = asTrimmedString(request.data?.registrationId);
  const resourceLinkId = asTrimmedString(request.data?.resourceLinkId);
  if (!registrationId || !resourceLinkId) {
    throw new HttpsError('invalid-argument', 'registrationId and resourceLinkId are required.');
  }

  const registrationSnap = await admin.firestore().collection('ltiPlatformRegistrations').doc(registrationId).get();
  if (!registrationSnap.exists) {
    throw new HttpsError('not-found', 'LTI platform registration not found.');
  }
  const registration = registrationSnap.data() as Record<string, unknown>;
  const siteId = asTrimmedString(registration.siteId);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const docId = typeof request.data?.id === 'string' && request.data.id.trim().length > 0
    ? request.data.id.trim()
    : buildLtiResourceLinkDocId(registrationId, resourceLinkId);
  const locale = asTrimmedString(request.data?.locale) || null;
  const targetPath = asTrimmedString(request.data?.targetPath) || null;
  const missionId = asTrimmedString(request.data?.missionId) || null;
  const sessionId = asTrimmedString(request.data?.sessionId) || null;
  const lineItemId = asTrimmedString(request.data?.lineItemId) || null;
  const lineItemUrl = asTrimmedString(request.data?.lineItemUrl) || null;
  const title = asTrimmedString(request.data?.title) || null;

  await admin.firestore().collection('ltiResourceLinks').doc(docId).set({
    registrationId,
    siteId,
    resourceLinkId,
    locale,
    targetPath,
    missionId,
    sessionId,
    lineItemId,
    lineItemUrl,
    title,
    provider: 'lti_1p3',
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true, id: docId };
});

export const queueLtiGradePassback = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId;
  if (!requestedSiteId || !actorCanAccessSite(actor, requestedSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const missionAttemptId = asTrimmedString(request.data?.missionAttemptId);
  if (!missionAttemptId) {
    throw new HttpsError('invalid-argument', 'missionAttemptId is required.');
  }

  const attemptSnap = await admin.firestore().collection('missionAttempts').doc(missionAttemptId).get();
  if (!attemptSnap.exists) {
    throw new HttpsError('not-found', 'Mission attempt not found.');
  }
  const attempt = attemptSnap.data() as Record<string, unknown>;
  const attemptSiteId = asTrimmedString(attempt.siteId);
  if (attemptSiteId !== requestedSiteId) {
    throw new HttpsError('permission-denied', 'Mission attempt is outside the requested site.');
  }

  const learnerId = asTrimmedString(request.data?.learnerId) || asTrimmedString(attempt.learnerId);
  const scoreGiven = asNumber(request.data?.scoreGiven);
  const scoreMaximum = asNumber(request.data?.scoreMaximum);
  if (scoreGiven === null || scoreMaximum === null) {
    throw new HttpsError('invalid-argument', 'scoreGiven and scoreMaximum are required.');
  }

  let lineItemId = asTrimmedString(request.data?.lineItemId) || undefined;
  let lineItemUrl = asTrimmedString(request.data?.lineItemUrl) || undefined;
  if (!lineItemId && !lineItemUrl) {
    const resourceLinkId = asTrimmedString(request.data?.resourceLinkId);
    if (resourceLinkId) {
      const linkSnap = await admin.firestore().collection('ltiResourceLinks')
        .where('resourceLinkId', '==', resourceLinkId)
        .where('siteId', '==', requestedSiteId)
        .limit(1)
        .get();
      const link = linkSnap.docs[0]?.data() as Record<string, unknown> | undefined;
      lineItemId = asTrimmedString(link?.lineItemId) || undefined;
      lineItemUrl = asTrimmedString(link?.lineItemUrl) || undefined;
    }
  }

  const job = buildLtiGradePassbackJob({
    siteId: requestedSiteId,
    learnerId,
    missionAttemptId,
    requestedBy: actor.uid,
    lineItemId,
    lineItemUrl,
    scoreGiven,
    scoreMaximum,
    activityProgress: asTrimmedString(request.data?.activityProgress) || undefined,
    gradingProgress: asTrimmedString(request.data?.gradingProgress) || undefined,
  });

  const duplicateSnap = await admin.firestore().collection('syncJobs')
    .where('provider', '==', 'lti_1p3')
    .where('idempotencyKey', '==', job.idempotencyKey)
    .limit(1)
    .get();
  if (!duplicateSnap.empty) {
    return {
      success: true,
      deduped: true,
      id: duplicateSnap.docs[0].id,
      idempotencyKey: job.idempotencyKey,
    };
  }

  const docRef = await admin.firestore().collection('syncJobs').add({
    ...job,
    requestedByRole: actor.role,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await admin.firestore().collection('auditLogs').add(buildLtiGradePassbackAuditLog(job, actor.uid));

  return {
    success: true,
    deduped: false,
    id: docRef.id,
    idempotencyKey: job.idempotencyKey,
  };
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

export const createCleverAuthUrl = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const returnUrl = normalizeReturnUrl(request.data?.returnUrl);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }
  if (!returnUrl) {
    throw new HttpsError('invalid-argument', 'A valid returnUrl is required.');
  }

  const clientId = asTrimmedString(process.env.CLEVER_CLIENT_ID);
  const redirectUri = asTrimmedString(process.env.CLEVER_REDIRECT_URI);
  if (!clientId || !redirectUri) {
    throw buildGovernanceApprovalError('Clever connect');
  }

  const cleverBaseUrl = asTrimmedString(process.env.CLEVER_AUTH_BASE_URL) || 'https://clever.com/oauth/authorize';
  const statePayload = Buffer.from(JSON.stringify({
    siteId,
    returnUrl,
    actorUid: actor.uid,
    provider: 'clever',
  })).toString('base64url');

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: 'clever.connect.started',
    collection: 'integrationConnections',
    documentId: buildCleverConnectionDocId(siteId),
    timestamp: Date.now(),
    details: { siteId, returnUrl },
  });

  const url = new URL(cleverBaseUrl);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('state', statePayload);

  return {
    provider: 'clever',
    siteId,
    returnUrl,
    url: url.toString(),
    stub: true,
  };
});

export const listCleverSchools = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const connection = await getCleverConnection(siteId);
  if (!connection) {
    throw buildGovernanceApprovalError('Clever school discovery');
  }

  const schools = Array.isArray(connection.data.cleverSchools)
    ? connection.data.cleverSchools.map((entry) => ({ ...(entry as Record<string, unknown>) }))
    : [];
  return {
    connectionId: connection.id,
    schools,
    stub: true,
  };
});

export const listCleverSections = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const schoolId = asTrimmedString(request.data?.schoolId);
  if (!siteId || !schoolId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site or school.');
  }

  const connection = await getCleverConnection(siteId);
  if (!connection) {
    throw buildGovernanceApprovalError('Clever section discovery');
  }

  const sectionMap = connection.data.cleverSectionsBySchool;
  const sections = sectionMap && typeof sectionMap === 'object' && !Array.isArray(sectionMap)
    ? ((sectionMap as Record<string, unknown>)[schoolId] as Array<Record<string, unknown>> | undefined) || []
    : [];
  return {
    connectionId: connection.id,
    schoolId,
    sections,
    stub: true,
  };
});

export const queueCleverRosterSync = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const schoolId = asTrimmedString(request.data?.schoolId);
  const mode = asTrimmedString(request.data?.mode).toLowerCase() || 'preview';
  if (!siteId || !schoolId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site or school.');
  }
  if (!['preview', 'apply'].includes(mode)) {
    throw new HttpsError('invalid-argument', 'mode must be preview or apply.');
  }

  const connection = await getCleverConnection(siteId);
  if (!connection || asTrimmedString(connection.data.status) !== 'active') {
    throw buildGovernanceApprovalError('Clever roster sync');
  }

  const docRef = await admin.firestore().collection('syncJobs').add({
    siteId,
    provider: 'clever',
    type: 'roster_import',
    jobType: `clever_roster_${mode}`,
    status: 'queued',
    schoolId,
    requestedBy: actor.uid,
    requestedByRole: actor.role,
    stub: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: 'clever.roster.sync',
    collection: 'syncJobs',
    documentId: docRef.id,
    timestamp: Date.now(),
    details: { siteId, schoolId, mode, stub: true },
  });

  return {
    success: true,
    id: docRef.id,
    mode,
    provider: 'clever',
    stub: true,
  };
});

export const resolveCleverIdentityLink = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const id = asTrimmedString(request.data?.id);
  const decision = asTrimmedString(request.data?.decision).toLowerCase() || 'link';
  const scholesaUserId = asTrimmedString(request.data?.scholesaUserId) || null;
  if (!id) {
    throw new HttpsError('invalid-argument', 'id is required.');
  }
  if (!['link', 'ignore', 'hold'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'decision must be link, ignore, or hold.');
  }
  if (decision === 'link' && !scholesaUserId) {
    throw new HttpsError('invalid-argument', 'scholesaUserId is required when decision is link.');
  }

  const ref = admin.firestore().collection('externalIdentityLinks').doc(id);
  const existing = await ref.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Identity link not found.');
  }
  const data = existing.data() as Record<string, unknown>;
  const siteId = asTrimmedString(data.siteId);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }
  if (asTrimmedString(data.provider).toLowerCase() !== 'clever') {
    throw new HttpsError('failed-precondition', 'Identity link is not a Clever link.');
  }

  const nextStatus = decision === 'link' ? 'linked' : decision === 'ignore' ? 'ignored' : 'held';
  await ref.set({
    status: nextStatus,
    scholesaUserId,
    approvedBy: actor.uid,
    approvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: 'clever.identity.resolve',
    collection: 'externalIdentityLinks',
    documentId: id,
    timestamp: Date.now(),
    details: { siteId, decision, scholesaUserId },
  });

  return { success: true, id, status: nextStatus, stub: true };
});

export const disconnectCleverConnection = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const connection = await getCleverConnection(siteId);
  if (!connection) {
    throw new HttpsError('not-found', 'Clever connection not found.');
  }

  await admin.firestore().collection('integrationConnections').doc(connection.id).set({
    status: 'revoked',
    lastError: null,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: 'clever.disconnect',
    collection: 'integrationConnections',
    documentId: connection.id,
    timestamp: Date.now(),
    details: { siteId },
  });

  return { success: true, id: connection.id, status: 'revoked', stub: true };
});

export const createClassLinkAuthUrl = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const returnUrl = normalizeReturnUrl(request.data?.returnUrl);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }
  if (!returnUrl) {
    throw new HttpsError('invalid-argument', 'A valid returnUrl is required.');
  }

  const clientId = districtProviderClientId('classlink');
  const redirectUri = districtProviderRedirectUri('classlink');
  if (!clientId || !redirectUri) {
    throw buildDistrictProviderGovernanceError('classlink', 'connect');
  }

  const statePayload = Buffer.from(JSON.stringify({
    siteId,
    returnUrl,
    actorUid: actor.uid,
    provider: 'classlink',
  })).toString('base64url');

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: districtProviderAuditAction('classlink', 'connect.started'),
    collection: 'integrationConnections',
    documentId: buildClassLinkConnectionDocId(siteId),
    timestamp: Date.now(),
    details: { siteId, returnUrl },
  });

  const url = new URL(districtProviderAuthBaseUrl('classlink'));
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('state', statePayload);

  return {
    provider: 'classlink',
    siteId,
    returnUrl,
    url: url.toString(),
    stub: true,
  };
});

export const listClassLinkSchools = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const connection = await getClassLinkConnection(siteId);
  if (!connection) {
    throw buildDistrictProviderGovernanceError('classlink', 'school discovery');
  }

  return {
    connectionId: connection.id,
    schools: districtProviderSchools('classlink', connection.data),
    stub: true,
  };
});

export const listClassLinkSections = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const schoolId = asTrimmedString(request.data?.schoolId);
  if (!siteId || !schoolId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site or school.');
  }

  const connection = await getClassLinkConnection(siteId);
  if (!connection) {
    throw buildDistrictProviderGovernanceError('classlink', 'section discovery');
  }

  return {
    connectionId: connection.id,
    schoolId,
    sections: districtProviderSections('classlink', connection.data, schoolId),
    stub: true,
  };
});

export const queueClassLinkRosterSync = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  const schoolId = asTrimmedString(request.data?.schoolId);
  const mode = asTrimmedString(request.data?.mode).toLowerCase() || 'preview';
  if (!siteId || !schoolId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site or school.');
  }
  if (!['preview', 'apply'].includes(mode)) {
    throw new HttpsError('invalid-argument', 'mode must be preview or apply.');
  }

  const connection = await getClassLinkConnection(siteId);
  if (!connection || asTrimmedString(connection.data.status) !== 'active') {
    throw buildDistrictProviderGovernanceError('classlink', 'roster sync');
  }

  const docRef = await admin.firestore().collection('syncJobs').add({
    siteId,
    provider: 'classlink',
    type: 'roster_import',
    jobType: districtProviderRosterSyncJobType('classlink', mode as 'preview' | 'apply'),
    status: 'queued',
    schoolId,
    requestedBy: actor.uid,
    requestedByRole: actor.role,
    stub: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: districtProviderAuditAction('classlink', 'roster.sync'),
    collection: 'syncJobs',
    documentId: docRef.id,
    timestamp: Date.now(),
    details: { siteId, schoolId, mode, stub: true },
  });

  return {
    success: true,
    id: docRef.id,
    mode,
    provider: 'classlink',
    stub: true,
  };
});

export const resolveClassLinkIdentityLink = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const id = asTrimmedString(request.data?.id);
  const decision = asTrimmedString(request.data?.decision).toLowerCase() || 'link';
  const scholesaUserId = asTrimmedString(request.data?.scholesaUserId) || null;
  if (!id) {
    throw new HttpsError('invalid-argument', 'id is required.');
  }
  if (!['link', 'ignore', 'hold'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'decision must be link, ignore, or hold.');
  }
  if (decision === 'link' && !scholesaUserId) {
    throw new HttpsError('invalid-argument', 'scholesaUserId is required when decision is link.');
  }

  const ref = admin.firestore().collection('externalIdentityLinks').doc(id);
  const existing = await ref.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Identity link not found.');
  }
  const data = existing.data() as Record<string, unknown>;
  const siteId = asTrimmedString(data.siteId);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }
  if (asTrimmedString(data.provider).toLowerCase() !== 'classlink') {
    throw new HttpsError('failed-precondition', 'Identity link is not a ClassLink link.');
  }

  const nextStatus = decision === 'link' ? 'linked' : decision === 'ignore' ? 'ignored' : 'held';
  await ref.set({
    status: nextStatus,
    scholesaUserId,
    approvedBy: actor.uid,
    approvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: districtProviderAuditAction('classlink', 'identity.resolve'),
    collection: 'externalIdentityLinks',
    documentId: id,
    timestamp: Date.now(),
    details: { siteId, decision, scholesaUserId },
  });

  return { success: true, id, status: nextStatus, stub: true };
});

export const disconnectClassLinkConnection = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = asTrimmedString(request.data?.siteId) || actor.profile.activeSiteId || '';
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const connection = await getClassLinkConnection(siteId);
  if (!connection) {
    throw new HttpsError('not-found', 'ClassLink connection not found.');
  }

  await admin.firestore().collection('integrationConnections').doc(connection.id).set({
    status: 'revoked',
    lastError: null,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: districtProviderAuditAction('classlink', 'disconnect'),
    collection: 'integrationConnections',
    documentId: connection.id,
    timestamp: Date.now(),
    details: { siteId },
  });

  return { success: true, id: connection.id, status: 'revoked', stub: true };
});

export const listEnterpriseSsoProviders = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = typeof request.data?.siteId === 'string' ? request.data.siteId.trim() : actor.profile.activeSiteId;
  if (requestedSiteId && !actorCanAccessSite(actor, requestedSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const query = requestedSiteId
    ? admin.firestore().collection('enterpriseSsoProviders').where('siteIds', 'array-contains', requestedSiteId).limit(50)
    : admin.firestore().collection('enterpriseSsoProviders').limit(50);

  const snap = await query.get();
  const providers = snap.docs.map((docSnap) => ({
    id: docSnap.id,
    ...stripSecretFields(docSnap.data() as Record<string, unknown>),
  }));

  return { providers };
});

export const upsertEnterpriseSsoProvider = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const providerId = asTrimmedString(request.data?.providerId).toLowerCase();
  const providerType = asTrimmedString(request.data?.providerType).toLowerCase();
  const displayName = asTrimmedString(request.data?.displayName);
  if (!providerId || !displayName || !['oidc', 'saml'].includes(providerType)) {
    throw new HttpsError('invalid-argument', 'providerId, providerType, and displayName are required.');
  }
  if ((providerType === 'oidc' && !providerId.startsWith('oidc.')) || (providerType === 'saml' && !providerId.startsWith('saml.'))) {
    throw new HttpsError('invalid-argument', 'providerId prefix must match providerType.');
  }

  const siteIds = toStringArray(request.data?.siteIds);
  if (siteIds.length === 0) {
    const fallbackSiteId = asTrimmedString(request.data?.defaultSiteId) || actor.profile.activeSiteId || '';
    if (!fallbackSiteId) {
      throw new HttpsError('invalid-argument', 'At least one siteId is required.');
    }
    siteIds.push(fallbackSiteId);
  }
  if (!siteIds.every((siteId) => actorCanAccessSite(actor, siteId))) {
    throw new HttpsError('permission-denied', 'No access to one or more requested sites.');
  }

  const docId = asTrimmedString(request.data?.id) || providerId.replace(/[^a-z0-9_.-]/g, '_');
  const payload = {
    providerId,
    providerType,
    displayName,
    siteIds,
    defaultSiteId: asTrimmedString(request.data?.defaultSiteId) || siteIds[0],
    defaultRole: asTrimmedString(request.data?.defaultRole) || 'educator',
    allowedDomains: toStringArray(request.data?.allowedDomains),
    organizationId: asTrimmedString(request.data?.organizationId) || null,
    buttonText: asTrimmedString(request.data?.buttonText) || null,
    jitProvisioning: request.data?.jitProvisioning !== false,
    enabled: request.data?.enabled !== false,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection('enterpriseSsoProviders').doc(docId).set(payload, { merge: true });
  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: 'auth.sso.provider.updated',
    collection: 'enterpriseSsoProviders',
    documentId: docId,
    timestamp: Date.now(),
    details: {
      providerId,
      providerType,
      siteIds,
      defaultRole: payload.defaultRole,
      enabled: payload.enabled,
    },
  });

  return { success: true, id: docId };
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
  const scope = ['global', 'site', 'user'].includes(asTrimmedString(request.data?.scope))
    ? asTrimmedString(request.data?.scope)
    : 'global';
  const enabledSites = toStringArray(request.data?.enabledSites);

  await ref.set({
    name,
    description,
    enabled,
    scope,
    enabledSites,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    status: enabled ? 'enabled' : 'disabled',
  }, { merge: true });

  return { success: true, id };
});

interface FederatedPendingSummaryRow {
  id: string;
  siteId: string;
  createdAtMs?: number;
  batteryState?: FederatedLearningBatteryState | null;
  networkType?: FederatedLearningNetworkType | null;
  sampleCount: number;
  vectorLength: number;
  vectorSketch: number[];
  payloadBytes: number;
  updateNorm: number;
  schemaVersion: string;
  runtimeTarget?: string | null;
  optimizerStrategy?: string | null;
  warmStartPackageId?: string | null;
  warmStartModelVersion?: string | null;
  traceId: string;
  payloadDigest: string;
  aggregationStatus: string;
  aggregationRunId?: string;
  ref: FirebaseFirestore.DocumentReference;
}

function asPositiveInteger(value: unknown, fallback: number): number {
  const parsed = typeof value === 'number' && Number.isFinite(value)
    ? value
    : Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function mapPendingFederatedSummary(
  snapDoc: FirebaseFirestore.DocumentSnapshot,
): FederatedPendingSummaryRow {
  const data = (snapDoc.data() || {}) as Record<string, unknown>;
  return {
    id: snapDoc.id,
    siteId: asTrimmedString(data.siteId),
    createdAtMs: toDateValue(data.createdAt || data.updatedAt)?.getTime(),
    batteryState: data.batteryState == null
      ? null
      : normalizeFederatedLearningBatteryState(data.batteryState),
    networkType: data.networkType == null
      ? null
      : normalizeFederatedLearningNetworkType(data.networkType),
    sampleCount: asPositiveInteger(data.sampleCount, 0),
    vectorLength: asPositiveInteger(data.vectorLength, 0),
    vectorSketch: Array.isArray(data.vectorSketch)
      ? data.vectorSketch
        .map((entry) => asNumber(entry) ?? 0)
        .map((entry) => Number(entry.toFixed(6)))
      : [],
    payloadBytes: asPositiveInteger(data.payloadBytes, 0),
    updateNorm: asNumber(data.updateNorm) ?? 0,
    schemaVersion: asTrimmedString(data.schemaVersion) || 'v1',
    runtimeTarget: asTrimmedString(data.runtimeTarget) || null,
    optimizerStrategy: asTrimmedString(data.optimizerStrategy) || null,
    warmStartPackageId: asTrimmedString(data.warmStartPackageId) || null,
    warmStartModelVersion: asTrimmedString(data.warmStartModelVersion) || null,
    traceId: asTrimmedString(data.traceId),
    payloadDigest: asTrimmedString(data.payloadDigest),
    aggregationStatus: asTrimmedString(data.aggregationStatus) || 'pending',
    aggregationRunId: asTrimmedString(data.aggregationRunId) || undefined,
    ref: snapDoc.ref,
  };
}

async function maybeMaterializeFederatedLearningAggregationRun({
  experimentId,
  experimentRef,
  experiment,
  actorId,
  triggerSummaryId,
}: {
  experimentId: string;
  experimentRef: FirebaseFirestore.DocumentReference;
  experiment: Record<string, unknown>;
  actorId: string;
  triggerSummaryId: string;
}): Promise<{ runId: string; artifactId: string; packageId: string; created: boolean } | null> {
  const aggregateThreshold = asPositiveInteger(experiment.aggregateThreshold, 25);
  const minDistinctSiteCount = asPositiveInteger(experiment.minDistinctSiteCount, 2);
  const mergeStrategy = normalizeFederatedLearningMergeStrategy(experiment.mergeStrategy) ??
    FEDERATED_LEARNING_MERGE_STRATEGY;
  const pendingSnap = await admin.firestore()
    .collection('federatedLearningUpdateSummaries')
    .where('experimentId', '==', experimentId)
    .where('status', '==', 'accepted')
    .orderBy('createdAt', 'asc')
    .limit(200)
    .get();

  const pendingRows = pendingSnap.docs
    .map(mapPendingFederatedSummary)
    .filter((row) => row.aggregationStatus !== 'materialized' && !row.aggregationRunId);
  const selection = selectFederatedLearningAggregationBatch(
    pendingRows,
    aggregateThreshold,
    minDistinctSiteCount,
  );
  if (!selection) {
    return null;
  }

  const runId = buildFederatedLearningAggregationRunDocId(experimentId, selection.summaryIds);
  const artifactId = buildFederatedLearningMergeArtifactDocId(runId);
  const packageId = buildFederatedLearningCandidateModelPackageDocId(runId);
  const runRef = admin.firestore().collection('federatedLearningAggregationRuns').doc(runId);
  const artifactRef = admin.firestore().collection('federatedLearningMergeArtifacts').doc(artifactId);
  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(packageId);
  let created = false;

  await admin.firestore().runTransaction(async (transaction) => {
    const existingRun = await transaction.get(runRef);
    const existingArtifact = await transaction.get(artifactRef);
    const existingPackage = await transaction.get(packageRef);
    if (existingRun.exists || existingArtifact.exists || existingPackage.exists) {
      return;
    }

    const selectedRows = selection.summaryIds
      .map((summaryId) => pendingRows.find((row) => row.id === summaryId))
      .filter((row): row is FederatedPendingSummaryRow => row != null);
    if (selectedRows.length !== selection.summaryIds.length) {
      return;
    }

    const selectedSnapshots = await Promise.all(
      selectedRows.map((row) => transaction.get(row.ref)),
    );
    if (selectedSnapshots.some((snapDoc) => !snapDoc.exists)) {
      return;
    }

    const refreshedRows = selectedSnapshots.map((snapDoc) => mapPendingFederatedSummary(snapDoc));
    if (refreshedRows.some((row) => row.aggregationStatus === 'materialized' || row.aggregationRunId)) {
      return;
    }

    const refreshedSelection = selectFederatedLearningAggregationBatch(
      refreshedRows,
      aggregateThreshold,
      minDistinctSiteCount,
    );
    if (!refreshedSelection || refreshedSelection.summaryIds.join('|') !== selection.summaryIds.join('|')) {
      return;
    }
    const mergedRuntimeVector = buildFederatedLearningMergedRuntimeVector(
      refreshedRows,
      refreshedSelection.maxVectorLength,
      mergeStrategy,
    );
    const mergeWeights = buildFederatedLearningMergeWeightSummary(
      refreshedRows,
      mergeStrategy,
    );
    const contributionDetails = buildFederatedLearningContributionDetails(
      refreshedRows,
      mergeWeights.normCap,
      mergeStrategy,
    );
    const artifactSummary = buildFederatedLearningMergeArtifactSummary(
      triggerSummaryId,
      refreshedSelection,
      mergedRuntimeVector,
      mergeWeights,
      contributionDetails,
      mergeStrategy,
    );
    const packageSummary = buildFederatedLearningCandidateModelPackageSummary(
      runId,
      artifactId,
      artifactSummary,
    );

    transaction.set(runRef, {
      experimentId,
      status: 'materialized',
      threshold: aggregateThreshold,
      thresholdMet: true,
      minDistinctSiteCount,
      distinctSiteThresholdMet: refreshedSelection.distinctSiteCount >= minDistinctSiteCount,
      mergeArtifactId: artifactId,
      mergeArtifactStatus: 'generated',
      candidateModelPackageId: packageId,
      candidateModelPackageStatus: 'staged',
      candidateModelPackageFormat: packageSummary.packageFormat,
      payloadFormat: artifactSummary.payloadFormat,
      modelVersion: artifactSummary.modelVersion,
      runtimeVectorLength: artifactSummary.runtimeVectorLength,
      runtimeVectorDigest: artifactSummary.runtimeVectorDigest,
      mergeStrategy,
      normCap: mergeWeights.normCap,
      effectiveTotalWeight: mergeWeights.effectiveTotalWeight,
      rawTotalWeight: mergeWeights.rawTotalWeight,
      dampedSummaryCount: mergeWeights.dampedSummaryCount,
      minUpdateNorm: mergeWeights.minUpdateNorm,
      maxUpdateNorm: mergeWeights.maxUpdateNorm,
      oldestSummaryCreatedAtMs: refreshedSelection.oldestSummaryCreatedAtMs ?? null,
      newestSummaryCreatedAtMs: refreshedSelection.newestSummaryCreatedAtMs ?? null,
      summaryFreshnessSpanSeconds: refreshedSelection.summaryFreshnessSpanSeconds ?? null,
      batteryStateBreakdown: refreshedSelection.batteryStateBreakdown,
      networkTypeBreakdown: refreshedSelection.networkTypeBreakdown,
      triggerSummaryId,
      summaryIds: refreshedSelection.summaryIds,
      summaryCount: refreshedSelection.summaryCount,
      distinctSiteCount: refreshedSelection.distinctSiteCount,
      contributingSiteIds: refreshedSelection.contributingSiteIds,
      totalSampleCount: refreshedSelection.totalSampleCount,
      maxVectorLength: refreshedSelection.maxVectorLength,
      totalPayloadBytes: refreshedSelection.totalPayloadBytes,
      averageUpdateNorm: refreshedSelection.averageUpdateNorm,
      schemaVersions: refreshedSelection.schemaVersions,
      runtimeTargets: refreshedSelection.runtimeTargets,
      optimizerStrategies: refreshedSelection.optimizerStrategies,
      compatibilityKey: refreshedSelection.compatibilityKey,
      warmStartPackageId: refreshedSelection.warmStartPackageId ?? null,
      warmStartModelVersion: refreshedSelection.warmStartModelVersion ?? null,
      boundedDigest: artifactSummary.boundedDigest,
      contributionDetails: artifactSummary.contributionDetails,
      siteContributionSummaries: artifactSummary.siteContributionSummaries,
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(artifactRef, {
      experimentId,
      aggregationRunId: runId,
      status: 'generated',
      mergeStrategy,
      normCap: artifactSummary.normCap,
      effectiveTotalWeight: artifactSummary.effectiveTotalWeight,
      rawTotalWeight: artifactSummary.rawTotalWeight,
      dampedSummaryCount: artifactSummary.dampedSummaryCount,
      minUpdateNorm: artifactSummary.minUpdateNorm,
      maxUpdateNorm: artifactSummary.maxUpdateNorm,
      oldestSummaryCreatedAtMs: artifactSummary.oldestSummaryCreatedAtMs ?? null,
      newestSummaryCreatedAtMs: artifactSummary.newestSummaryCreatedAtMs ?? null,
      summaryFreshnessSpanSeconds: artifactSummary.summaryFreshnessSpanSeconds ?? null,
      batteryStateBreakdown: artifactSummary.batteryStateBreakdown,
      networkTypeBreakdown: artifactSummary.networkTypeBreakdown,
      triggerSummaryId: artifactSummary.triggerSummaryId,
      summaryIds: artifactSummary.summaryIds,
      boundedDigest: artifactSummary.boundedDigest,
      payloadFormat: artifactSummary.payloadFormat,
      modelVersion: artifactSummary.modelVersion,
      runtimeVectorLength: artifactSummary.runtimeVectorLength,
      runtimeVector: artifactSummary.runtimeVector,
      runtimeVectorDigest: artifactSummary.runtimeVectorDigest,
      sampleCount: artifactSummary.sampleCount,
      summaryCount: artifactSummary.summaryCount,
      distinctSiteCount: artifactSummary.distinctSiteCount,
      contributingSiteIds: artifactSummary.contributingSiteIds,
      schemaVersions: artifactSummary.schemaVersions,
      runtimeTargets: artifactSummary.runtimeTargets,
      optimizerStrategies: artifactSummary.optimizerStrategies,
      compatibilityKey: artifactSummary.compatibilityKey,
      warmStartPackageId: artifactSummary.warmStartPackageId ?? null,
      warmStartModelVersion: artifactSummary.warmStartModelVersion ?? null,
      maxVectorLength: artifactSummary.maxVectorLength,
      totalPayloadBytes: artifactSummary.totalPayloadBytes,
      averageUpdateNorm: artifactSummary.averageUpdateNorm,
      contributionDetails: artifactSummary.contributionDetails,
      siteContributionSummaries: artifactSummary.siteContributionSummaries,
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      experimentId,
      aggregationRunId: runId,
      mergeArtifactId: artifactId,
      status: 'staged',
      mergeStrategy: packageSummary.mergeStrategy,
      packageFormat: packageSummary.packageFormat,
      rolloutStatus: packageSummary.rolloutStatus,
      normCap: packageSummary.normCap,
      effectiveTotalWeight: packageSummary.effectiveTotalWeight,
      rawTotalWeight: packageSummary.rawTotalWeight,
      dampedSummaryCount: packageSummary.dampedSummaryCount,
      minUpdateNorm: packageSummary.minUpdateNorm,
      maxUpdateNorm: packageSummary.maxUpdateNorm,
      oldestSummaryCreatedAtMs: packageSummary.oldestSummaryCreatedAtMs ?? null,
      newestSummaryCreatedAtMs: packageSummary.newestSummaryCreatedAtMs ?? null,
      summaryFreshnessSpanSeconds: packageSummary.summaryFreshnessSpanSeconds ?? null,
      batteryStateBreakdown: packageSummary.batteryStateBreakdown,
      networkTypeBreakdown: packageSummary.networkTypeBreakdown,
      triggerSummaryId: packageSummary.triggerSummaryId,
      summaryIds: packageSummary.summaryIds,
      modelVersion: packageSummary.modelVersion,
      packageDigest: packageSummary.packageDigest,
      boundedDigest: packageSummary.boundedDigest,
      runtimeVectorLength: packageSummary.runtimeVectorLength,
      runtimeVector: packageSummary.runtimeVector,
      runtimeVectorDigest: packageSummary.runtimeVectorDigest,
      sampleCount: packageSummary.sampleCount,
      summaryCount: packageSummary.summaryCount,
      distinctSiteCount: packageSummary.distinctSiteCount,
      contributingSiteIds: packageSummary.contributingSiteIds,
      schemaVersions: packageSummary.schemaVersions,
      runtimeTargets: packageSummary.runtimeTargets,
      optimizerStrategies: packageSummary.optimizerStrategies,
      compatibilityKey: packageSummary.compatibilityKey,
      warmStartPackageId: packageSummary.warmStartPackageId ?? null,
      warmStartModelVersion: packageSummary.warmStartModelVersion ?? null,
      maxVectorLength: packageSummary.maxVectorLength,
      totalPayloadBytes: packageSummary.totalPayloadBytes,
      averageUpdateNorm: packageSummary.averageUpdateNorm,
      contributionDetails: packageSummary.contributionDetails,
      siteContributionSummaries: packageSummary.siteContributionSummaries,
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    for (const row of refreshedRows) {
      transaction.set(row.ref, {
        aggregationStatus: 'materialized',
        aggregationRunId: runId,
        aggregatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    transaction.set(experimentRef, {
      latestAggregationRunId: runId,
      latestMergeArtifactId: artifactId,
      latestCandidateModelPackageId: packageId,
      lastAggregatedAt: FieldValue.serverTimestamp(),
      lastAggregationSampleCount: refreshedSelection.totalSampleCount,
      lastAggregationSummaryCount: refreshedSelection.summaryCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    created = true;
  });

  return { runId, artifactId, packageId, created };
}

export const listFederatedLearningExperiments = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const snap = await admin.firestore().collection('federatedLearningExperiments').limit(200).get();
  const experiments = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { experiments };
});

export const listFederatedLearningExperimentReviewRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 120;
  const experimentId = asTrimmedString(request.data?.experimentId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningExperimentReviewRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listSiteFederatedLearningExperiments = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 40;

  const experimentSnap = await admin.firestore()
    .collection('federatedLearningExperiments')
    .where('allowedSiteIds', 'array-contains', targetSiteId)
    .limit(limitValue)
    .get()
    .catch(() => admin.firestore().collection('federatedLearningExperiments').limit(200).get());

  const scopedExperiments: Array<Record<string, unknown> & { id: string }> = experimentSnap.docs
    .map((snapDoc) => {
      const data = snapDoc.data() as Record<string, unknown>;
      return {
        id: snapDoc.id,
        ...data,
      } as Record<string, unknown> & { id: string };
    })
    .filter((row) => {
      const allowedSiteIds = toStringArray(row.allowedSiteIds);
      const status = asTrimmedString(row.status);
      return allowedSiteIds.includes(targetSiteId) && ['pilot_ready', 'active'].includes(status);
    });

  const flagIds = Array.from(new Set(
    scopedExperiments
      .map((row) => asTrimmedString(row.featureFlagId))
      .filter((value) => value.length > 0),
  ));
  const flagDocs = flagIds.length > 0
    ? await admin.firestore().getAll(
      ...flagIds.map((flagId) => admin.firestore().collection('featureFlags').doc(flagId)),
    )
    : [];
  const flagMap = new Map<string, Record<string, unknown>>();
  flagDocs.forEach((docSnap) => {
    if (docSnap.exists) {
      flagMap.set(docSnap.id, (docSnap.data() || {}) as Record<string, unknown>);
    }
  });

  const experiments: Record<string, unknown>[] = [];
  scopedExperiments.forEach((row) => {
      const featureFlagId = asTrimmedString(row.featureFlagId);
      const flag = featureFlagId ? flagMap.get(featureFlagId) : null;
      if (!flag || flag.enabled !== true) return;

      const scope = asTrimmedString(flag.scope) || 'site';
      const enabledSites = toStringArray(flag.enabledSites);
      if (scope === 'site' && enabledSites.length > 0 && !enabledSites.includes(targetSiteId)) {
        return;
      }

      experiments.push({
        ...row,
        featureFlag: {
          id: featureFlagId,
          enabled: true,
          scope,
          enabledSites,
          status: asTrimmedString(flag.status) || 'enabled',
        },
      });
    });

  return { siteId: targetSiteId, experiments };
});

export const listFederatedLearningAggregationRuns = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningAggregationRuns')
    .orderBy('createdAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }

  const snap = await query.get();
  const runs = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { runs };
});

export const listFederatedLearningMergeArtifacts = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningMergeArtifacts')
    .orderBy('createdAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }

  const snap = await query.get();
  const artifacts = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { artifacts };
});

export const listFederatedLearningCandidateModelPackages = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningCandidateModelPackages')
    .orderBy('createdAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }

  const snap = await query.get();
  const packages = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { packages };
});

export const listFederatedLearningCandidatePromotionRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningCandidatePromotionRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningCandidatePromotionRevocationRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningCandidatePromotionRevocationRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningPilotEvidenceRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningPilotEvidenceRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningPilotApprovalRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningPilotApprovalRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningPilotExecutionRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningPilotExecutionRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeDeliveryRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeDeliveryRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listSiteFederatedLearningRuntimeDeliveryRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 40;

  const snap = await admin.firestore()
    .collection('federatedLearningRuntimeDeliveryRecords')
    .where('targetSiteIds', 'array-contains', targetSiteId)
    .limit(limitValue)
    .get()
    .catch(() => admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').limit(200).get());

  const records = snap.docs
    .map((snapDoc) => ({
      id: snapDoc.id,
      ...(snapDoc.data() as Record<string, unknown>),
    }))
    .filter((row) => {
      const rowData = row as Record<string, unknown>;
      const targetSiteIds = toStringArray(rowData.targetSiteIds);
      const status = asTrimmedString(rowData.status);
      const terminalLifecycleStatus = getRuntimeDeliveryTerminalLifecycleStatus(rowData);
      return targetSiteIds.includes(targetSiteId)
        && ['assigned', 'active'].includes(status)
        && terminalLifecycleStatus == null;
    })
    .sort((a, b) => {
      const aUpdatedAt = typeof (a as Record<string, unknown>).updatedAt === 'number'
        ? ((a as Record<string, unknown>).updatedAt as number)
        : 0;
      const bUpdatedAt = typeof (b as Record<string, unknown>).updatedAt === 'number'
        ? ((b as Record<string, unknown>).updatedAt as number)
        : 0;
      return bUpdatedAt - aUpdatedAt;
    })
    .slice(0, limitValue);
  return { records };
});

export const listSiteFederatedLearningRuntimeDeliveryHistoryRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 20;

  const snap = await admin.firestore()
    .collection('federatedLearningRuntimeDeliveryRecords')
    .where('targetSiteIds', 'array-contains', targetSiteId)
    .limit(Math.max(limitValue * 3, 40))
    .get()
    .catch(() => admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').limit(200).get());

  const controlIds = snap.docs.map((snapDoc) => buildFederatedLearningRuntimeRolloutControlRecordDocId(snapDoc.id));
  const controlRefs = controlIds.map((controlId) => admin.firestore()
    .collection('federatedLearningRuntimeRolloutControlRecords')
    .doc(controlId));
  const controlSnaps = controlRefs.length > 0
    ? await admin.firestore().getAll(...controlRefs)
    : [];
  const controlsByDeliveryId = new Map<string, Record<string, unknown>>();
  controlSnaps.forEach((controlSnap) => {
    if (!controlSnap.exists) {
      return;
    }
    const controlData = (controlSnap.data() || {}) as Record<string, unknown>;
    const deliveryRecordId = asTrimmedString(controlData.deliveryRecordId);
    if (!deliveryRecordId) {
      return;
    }
    controlsByDeliveryId.set(deliveryRecordId, controlData);
  });

  type SiteRuntimeDeliveryHistoryRow = Record<string, unknown> & {
    terminalLifecycleStatus: 'expired' | 'revoked' | 'superseded' | null;
    rolloutControlMode: string | null;
    rolloutControlReason: string | null;
    rolloutControlReviewByAt: number | null;
  };

  const records: SiteRuntimeDeliveryHistoryRow[] = snap.docs
    .map((snapDoc) => {
      const row = {
        id: snapDoc.id,
        ...(snapDoc.data() as Record<string, unknown>),
      } as Record<string, unknown>;
      const targetSiteIds = toStringArray(row.targetSiteIds);
      if (!targetSiteIds.includes(targetSiteId)) {
        return null;
      }
      const terminalLifecycleStatus = getRuntimeDeliveryTerminalLifecycleStatus(row);
      const controlData = controlsByDeliveryId.get(snapDoc.id) || {};
      return {
        ...row,
        terminalLifecycleStatus: terminalLifecycleStatus || null,
        rolloutControlMode: normalizeFederatedLearningRuntimeRolloutControlMode(controlData.mode) || null,
        rolloutControlReason: asTrimmedString(controlData.reason) || null,
        rolloutControlReviewByAt: asTimestampMillis(controlData.reviewByAt) ?? null,
      } as SiteRuntimeDeliveryHistoryRow;
    })
    .filter((row): row is SiteRuntimeDeliveryHistoryRow => row != null)
    .sort((a, b) => {
      const aUpdatedAt = typeof a.updatedAt === 'number' ? a.updatedAt : 0;
      const bUpdatedAt = typeof b.updatedAt === 'number' ? b.updatedAt : 0;
      return bUpdatedAt - aUpdatedAt;
    })
    .slice(0, limitValue);
  return { records };
});

export const resolveSiteFederatedLearningRuntimePackage = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const experimentId = asTrimmedString(request.data?.experimentId);
  const runtimeTarget = normalizeFederatedLearningRuntimeTarget(request.data?.runtimeTarget);

  let deliveryData: Record<string, unknown> | null = null;
  let resolvedDeliveryId = deliveryRecordId;

  if (deliveryRecordId) {
    const deliverySnap = await admin.firestore()
      .collection('federatedLearningRuntimeDeliveryRecords')
      .doc(deliveryRecordId)
      .get();
    if (!deliverySnap.exists) {
      throw new HttpsError('not-found', 'Runtime delivery record not found.');
    }
    deliveryData = (deliverySnap.data() || {}) as Record<string, unknown>;
  } else {
    const deliverySnap = await admin.firestore()
      .collection('federatedLearningRuntimeDeliveryRecords')
      .where('targetSiteIds', 'array-contains', targetSiteId)
      .limit(50)
      .get()
      .catch(() => admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').limit(200).get());

    const candidateDeliveries = deliverySnap.docs
      .map((snapDoc) => ({
        id: snapDoc.id,
        ...(snapDoc.data() as Record<string, unknown>),
      }))
      .filter((row) => {
        const rowData = row as Record<string, unknown>;
        const allowedSites = toStringArray(rowData.targetSiteIds);
        const status = asTrimmedString(rowData.status);
        const rowExperimentId = asTrimmedString(rowData.experimentId);
        const rowRuntimeTarget = normalizeFederatedLearningRuntimeTarget(rowData.runtimeTarget);
        return allowedSites.includes(targetSiteId)
          && ['assigned', 'active', 'revoked', 'superseded'].includes(status)
          && (!experimentId || rowExperimentId === experimentId)
          && (!runtimeTarget || rowRuntimeTarget === runtimeTarget);
      })
      .sort((a, b) => {
        const statusRank = (value: string) => (
          value === 'active' ? 4 : value === 'assigned' ? 3 : value === 'revoked' ? 2 : value === 'superseded' ? 1 : 0
        );
        const aData = a as Record<string, unknown>;
        const bData = b as Record<string, unknown>;
        const statusDelta = statusRank(asTrimmedString(bData.status)) - statusRank(asTrimmedString(aData.status));
        if (statusDelta !== 0) return statusDelta;
        const aUpdatedAt = typeof aData.updatedAt === 'number' ? aData.updatedAt : 0;
        const bUpdatedAt = typeof bData.updatedAt === 'number' ? bData.updatedAt : 0;
        return bUpdatedAt - aUpdatedAt;
      });
    if (candidateDeliveries.length === 0) {
      return { package: null };
    }
    resolvedDeliveryId = asTrimmedString(candidateDeliveries[0].id);
    deliveryData = candidateDeliveries[0] as Record<string, unknown>;
  }

  const deliveryStatus = asTrimmedString(deliveryData.status);
  const allowedSites = toStringArray(deliveryData.targetSiteIds);
  if (!allowedSites.includes(targetSiteId)) {
    throw new HttpsError('permission-denied', 'No active or assigned runtime delivery available for the requested site.');
  }

  const expiresAt = typeof deliveryData.expiresAt === 'number' ? Math.trunc(deliveryData.expiresAt) : 0;
  const supersededAt = typeof deliveryData.supersededAt === 'number' ? Math.trunc(deliveryData.supersededAt) : 0;
  const supersededBy = asTrimmedString(deliveryData.supersededBy);
  const supersededByDeliveryRecordId = asTrimmedString(deliveryData.supersededByDeliveryRecordId);
  const supersededByCandidateModelPackageId = asTrimmedString(deliveryData.supersededByCandidateModelPackageId);
  const supersessionReason = asTrimmedString(deliveryData.supersessionReason);
  const revokedAt = typeof deliveryData.revokedAt === 'number' ? Math.trunc(deliveryData.revokedAt) : 0;
  const revokedBy = asTrimmedString(deliveryData.revokedBy);
  const revocationReason = asTrimmedString(deliveryData.revocationReason);
  const now = Date.now();
  const controlId = buildFederatedLearningRuntimeRolloutControlRecordDocId(resolvedDeliveryId);
  const [controlSnap, packageSnap] = await Promise.all([
    admin.firestore().collection('federatedLearningRuntimeRolloutControlRecords').doc(controlId).get(),
    admin.firestore()
      .collection('federatedLearningCandidateModelPackages')
      .doc(asTrimmedString(deliveryData.candidateModelPackageId))
      .get(),
  ]);
  const controlData = (controlSnap.data() || {}) as Record<string, unknown>;
  const controlMode = normalizeFederatedLearningRuntimeRolloutControlMode(controlData.mode);
  const controlReason = asTrimmedString(controlData.reason);
  const controlReviewByAt = asTimestampMillis(controlData.reviewByAt);

  let resolutionStatus = deliveryStatus === 'revoked' || revokedAt > 0
    ? 'revoked'
    : deliveryStatus === 'superseded' || supersededAt > 0
      ? 'superseded'
    : (expiresAt > 0 && expiresAt <= now)
      ? 'expired'
      : ['assigned', 'active'].includes(deliveryStatus)
        ? 'resolved'
        : null;
  if (!resolutionStatus) {
    return { package: null };
  }

  const candidateModelPackageId = asTrimmedString(deliveryData.candidateModelPackageId);
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  if (resolutionStatus === 'resolved' && controlMode === 'paused') {
    resolutionStatus = 'paused';
  }
  if (resolutionStatus === 'resolved' && controlMode === 'restricted') {
    const activationSnap = await admin.firestore()
      .collection('federatedLearningRuntimeActivationRecords')
      .doc(buildFederatedLearningRuntimeActivationRecordDocId(resolvedDeliveryId, targetSiteId))
      .get();
    const activationData = (activationSnap.data() || {}) as Record<string, unknown>;
    const activationStatus = normalizeFederatedLearningRuntimeActivationStatus(activationData.status);
    if (activationStatus !== 'resolved') {
      resolutionStatus = 'restricted';
    }
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const packageRuntimeTarget = normalizeFederatedLearningRuntimeTarget(deliveryData.runtimeTarget)
    || normalizeFederatedLearningRuntimeTarget(toStringArray(packageData.runtimeTargets)[0])
    || 'flutter_mobile';

  return {
    package: {
      packageId: candidateModelPackageId,
      deliveryRecordId: resolvedDeliveryId,
      experimentId: asTrimmedString(deliveryData.experimentId),
      candidateModelPackageId,
      siteId: targetSiteId,
      runtimeTarget: packageRuntimeTarget,
      packageDigest: asTrimmedString(packageData.packageDigest),
      manifestDigest: asTrimmedString(deliveryData.manifestDigest),
      resolutionStatus,
      modelVersion: asTrimmedString(packageData.modelVersion) || 'fl_runtime_model_v1',
      runtimeVectorLength: resolutionStatus === 'resolved'
        ? asPositiveInteger(packageData.runtimeVectorLength, 0)
        : 0,
      runtimeVector: resolutionStatus === 'resolved' && Array.isArray(packageData.runtimeVector)
        ? packageData.runtimeVector
          .map((entry) => asNumber(entry) ?? 0)
          .map((entry) => Number(entry.toFixed(6)))
        : [],
      runtimeVectorDigest: asTrimmedString(packageData.runtimeVectorDigest),
      rolloutStatus: asTrimmedString(packageData.rolloutStatus) || 'not_distributed',
      expiresAt: expiresAt > 0 ? expiresAt : null,
      supersededAt: supersededAt > 0 ? supersededAt : null,
      supersededBy: supersededBy || null,
      supersededByDeliveryRecordId: supersededByDeliveryRecordId || null,
      supersededByCandidateModelPackageId: supersededByCandidateModelPackageId || null,
      supersessionReason: supersessionReason || null,
      revokedAt: revokedAt > 0 ? revokedAt : null,
      revokedBy: revokedBy || null,
      revocationReason: revocationReason || null,
      rolloutControlMode: controlMode || null,
      rolloutControlReason: controlReason || null,
      rolloutControlReviewByAt: controlReviewByAt ?? null,
      resolvedAt: Date.now(),
    },
  };
});

export const listFederatedLearningRuntimeActivationRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const siteId = asTrimmedString(request.data?.siteId);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeActivationRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }
  if (siteId) {
    query = query.where('siteId', '==', siteId);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeRolloutAlertRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const status = normalizeFederatedLearningRuntimeRolloutAlertStatus(request.data?.status);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeRolloutAlertRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }
  if (deliveryRecordId) {
    query = query.where('deliveryRecordId', '==', deliveryRecordId);
  }
  if (status) {
    query = query.where('status', '==', status);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeRolloutEscalationRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const status = normalizeFederatedLearningRuntimeRolloutEscalationStatus(request.data?.status);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeRolloutEscalationRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }
  if (deliveryRecordId) {
    query = query.where('deliveryRecordId', '==', deliveryRecordId);
  }
  if (status) {
    query = query.where('status', '==', status);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeRolloutEscalationHistoryRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 80;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const status = normalizeFederatedLearningRuntimeRolloutEscalationStatus(request.data?.status);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeRolloutEscalationHistoryRecords')
    .orderBy('recordedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }
  if (deliveryRecordId) {
    query = query.where('deliveryRecordId', '==', deliveryRecordId);
  }
  if (status) {
    query = query.where('status', '==', status);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeRolloutControlRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 120
    ? request.data.limit
    : 60;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const mode = normalizeFederatedLearningRuntimeRolloutControlMode(request.data?.mode);

  let query: FirebaseFirestore.Query = admin.firestore()
    .collection('federatedLearningRuntimeRolloutControlRecords')
    .orderBy('updatedAt', 'desc')
    .limit(limitValue);
  if (experimentId) {
    query = query.where('experimentId', '==', experimentId);
  }
  if (candidateModelPackageId) {
    query = query.where('candidateModelPackageId', '==', candidateModelPackageId);
  }
  if (deliveryRecordId) {
    query = query.where('deliveryRecordId', '==', deliveryRecordId);
  }
  if (mode) {
    query = query.where('mode', '==', mode);
  }

  const snap = await query.get();
  const records = snap.docs.map((snapDoc) => ({
    id: snapDoc.id,
    ...(snapDoc.data() as Record<string, unknown>),
  }));
  return { records };
});

export const listFederatedLearningRuntimeRolloutAuditEvents = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 80;
  const experimentId = asTrimmedString(request.data?.experimentId);
  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  const siteId = asTrimmedString(request.data?.siteId);
  const actionFilter = new Set<string>([
    federatedLearningAuditAction('runtime_delivery_record.upsert'),
    federatedLearningAuditAction('runtime_activation_record.upsert'),
    federatedLearningAuditAction('runtime_rollout_alert_record.upsert'),
    federatedLearningAuditAction('runtime_rollout_escalation_record.upsert'),
    federatedLearningAuditAction('runtime_rollout_control_record.upsert'),
  ]);

  const snap = await admin.firestore()
    .collection('auditLogs')
    .where('action', 'in', Array.from(actionFilter))
    .orderBy('timestamp', 'desc')
    .limit(Math.min(limitValue * 3, 200))
    .get()
    .catch(() => admin.firestore().collection('auditLogs').limit(400).get());

  const records = snap.docs
    .map((snapDoc) => ({
      id: snapDoc.id,
      ...(snapDoc.data() as Record<string, unknown>),
    }))
    .filter((row) => {
      const rowData = row as Record<string, unknown>;
      const details = (rowData.details || {}) as Record<string, unknown>;
      const rowAction = asTrimmedString(rowData.action);
      if (!actionFilter.has(rowAction)) {
        return false;
      }
      if (experimentId && asTrimmedString(details.experimentId) !== experimentId) {
        return false;
      }
      if (candidateModelPackageId && asTrimmedString(details.candidateModelPackageId) !== candidateModelPackageId) {
        return false;
      }
      if (deliveryRecordId && asTrimmedString(details.deliveryRecordId) !== deliveryRecordId) {
        return false;
      }
      if (siteId && asTrimmedString(details.siteId) !== siteId) {
        return false;
      }
      return true;
    })
    .sort((a, b) => {
      const aTimestamp = typeof (a as Record<string, unknown>).timestamp === 'number'
        ? ((a as Record<string, unknown>).timestamp as number)
        : 0;
      const bTimestamp = typeof (b as Record<string, unknown>).timestamp === 'number'
        ? ((b as Record<string, unknown>).timestamp as number)
        : 0;
      return bTimestamp - aTimestamp;
    })
    .slice(0, limitValue);

  return { records };
});

export const listSiteFederatedLearningRuntimeActivationRecords = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 100
    ? request.data.limit
    : 40;
  const snap = await admin.firestore()
    .collection('federatedLearningRuntimeActivationRecords')
    .where('siteId', '==', targetSiteId)
    .orderBy('updatedAt', 'desc')
    .limit(limitValue)
    .get()
    .catch(() => admin.firestore().collection('federatedLearningRuntimeActivationRecords').limit(200).get());

  const records = snap.docs
    .map((snapDoc) => ({
      id: snapDoc.id,
      ...(snapDoc.data() as Record<string, unknown>),
    }))
    .filter((row) => asTrimmedString((row as Record<string, unknown>).siteId) === targetSiteId)
    .slice(0, limitValue);
  return { records };
});

export const upsertFederatedLearningExperimentReviewRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const experimentId = asTrimmedString(request.data?.experimentId);
  if (!experimentId) {
    throw new HttpsError('invalid-argument', 'experimentId is required.');
  }

  const experimentRef = admin.firestore().collection('federatedLearningExperiments').doc(experimentId);
  const experimentSnap = await experimentRef.get();
  if (!experimentSnap.exists) {
    throw new HttpsError('not-found', 'Federated learning experiment not found.');
  }

  const status = normalizeFederatedLearningExperimentReviewStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be pending, approved, or blocked.');
  }

  const privacyReviewComplete = request.data?.privacyReviewComplete === true;
  const signoffChecklistComplete = request.data?.signoffChecklistComplete === true;
  const rolloutRiskAcknowledged = request.data?.rolloutRiskAcknowledged === true;
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);

  if (status === 'approved' && (!privacyReviewComplete || !signoffChecklistComplete || !rolloutRiskAcknowledged)) {
    throw new HttpsError(
      'failed-precondition',
      'Approved review records require privacy review, sign-off checklist, and rollout-risk acknowledgement.',
    );
  }

  const reviewId = buildFederatedLearningExperimentReviewRecordDocId(experimentId);
  const reviewRef = admin.firestore().collection('federatedLearningExperimentReviewRecords').doc(reviewId);

  await reviewRef.set({
    experimentId,
    status,
    privacyReviewComplete,
    signoffChecklistComplete,
    rolloutRiskAcknowledged,
    notes,
    reviewedBy: actor.uid,
    reviewedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('experiment_review_record.upsert'),
    collection: 'federatedLearningExperimentReviewRecords',
    documentId: reviewId,
    timestamp: Date.now(),
    details: {
      experimentId,
      status,
      privacyReviewComplete,
      signoffChecklistComplete,
      rolloutRiskAcknowledged,
    },
  });

  return {
    success: true,
    id: reviewId,
    experimentId,
    status,
  };
});

export const upsertFederatedLearningPilotEvidenceRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const status = normalizeFederatedLearningPilotEvidenceStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be pending, ready_for_pilot, or blocked.');
  }

  const sandboxEvalComplete = request.data?.sandboxEvalComplete === true;
  const metricsSnapshotComplete = request.data?.metricsSnapshotComplete === true;
  const rollbackPlanVerified = request.data?.rollbackPlanVerified === true;
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);

  if (status === 'ready_for_pilot' && (!sandboxEvalComplete || !metricsSnapshotComplete || !rollbackPlanVerified)) {
    throw new HttpsError(
      'failed-precondition',
      'Ready-for-pilot evidence requires sandbox eval, metrics snapshot, and rollback-plan verification.',
    );
  }

  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId);
  const packageDigest = asTrimmedString(packageData.packageDigest);
  const boundedDigest = asTrimmedString(packageData.boundedDigest);
  const evidenceId = buildFederatedLearningPilotEvidenceRecordDocId(candidateModelPackageId);
  const evidenceRef = admin.firestore().collection('federatedLearningPilotEvidenceRecords').doc(evidenceId);

  await admin.firestore().runTransaction(async (transaction) => {
    transaction.set(evidenceRef, {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      status,
      sandboxEvalComplete,
      metricsSnapshotComplete,
      rollbackPlanVerified,
      notes,
      reviewedBy: actor.uid,
      reviewedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestPilotEvidenceRecordId: evidenceId,
      latestPilotEvidenceStatus: status,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('pilot_evidence_record.upsert'),
    collection: 'federatedLearningPilotEvidenceRecords',
    documentId: evidenceId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      status,
      sandboxEvalComplete,
      metricsSnapshotComplete,
      rollbackPlanVerified,
    },
  });

  return {
    success: true,
    id: evidenceId,
    candidateModelPackageId,
    status,
  };
});

export const upsertFederatedLearningPilotApprovalRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const status = normalizeFederatedLearningPilotApprovalStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be pending, approved, or blocked.');
  }

  const notes = asTrimmedString(request.data?.notes).slice(0, 500);
  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId);
  const reviewId = buildFederatedLearningExperimentReviewRecordDocId(experimentId);
  const evidenceId = buildFederatedLearningPilotEvidenceRecordDocId(candidateModelPackageId);
  const promotionId = buildFederatedLearningCandidatePromotionRecordDocId(candidateModelPackageId);
  const revocationId = buildFederatedLearningCandidatePromotionRevocationRecordDocId(candidateModelPackageId);
  const approvalId = buildFederatedLearningPilotApprovalRecordDocId(candidateModelPackageId);

  const [reviewSnap, evidenceSnap, promotionSnap, revocationSnap] = await Promise.all([
    admin.firestore().collection('federatedLearningExperimentReviewRecords').doc(reviewId).get(),
    admin.firestore().collection('federatedLearningPilotEvidenceRecords').doc(evidenceId).get(),
    admin.firestore().collection('federatedLearningCandidatePromotionRecords').doc(promotionId).get(),
    admin.firestore().collection('federatedLearningCandidatePromotionRevocationRecords').doc(revocationId).get(),
  ]);

  if (status === 'approved') {
    const reviewData = (reviewSnap.data() || {}) as Record<string, unknown>;
    const evidenceData = (evidenceSnap.data() || {}) as Record<string, unknown>;
    const promotionData = (promotionSnap.data() || {}) as Record<string, unknown>;
    if (!reviewSnap.exists || asTrimmedString(reviewData.status) !== 'approved') {
      throw new HttpsError('failed-precondition', 'Approved pilot approval requires an approved experiment review record.');
    }
    if (!evidenceSnap.exists || asTrimmedString(evidenceData.status) !== 'ready_for_pilot') {
      throw new HttpsError('failed-precondition', 'Approved pilot approval requires ready-for-pilot evidence.');
    }
    if (!promotionSnap.exists || asTrimmedString(promotionData.status) !== 'approved_for_eval') {
      throw new HttpsError('failed-precondition', 'Approved pilot approval requires an approved-for-eval promotion record.');
    }
    if (revocationSnap.exists) {
      throw new HttpsError('failed-precondition', 'Approved pilot approval cannot use a revoked promotion record.');
    }
  }

  const promotionTarget = promotionSnap.exists
    ? asTrimmedString((promotionSnap.data() || {}).target) || 'sandbox_eval'
    : 'sandbox_eval';
  const approvalRef = admin.firestore().collection('federatedLearningPilotApprovalRecords').doc(approvalId);

  await admin.firestore().runTransaction(async (transaction) => {
    transaction.set(approvalRef, {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      experimentReviewRecordId: reviewId,
      pilotEvidenceRecordId: evidenceId,
      candidatePromotionRecordId: promotionId,
      promotionTarget,
      status,
      notes,
      approvedBy: actor.uid,
      approvedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestPilotApprovalRecordId: approvalId,
      latestPilotApprovalStatus: status,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('pilot_approval_record.upsert'),
    collection: 'federatedLearningPilotApprovalRecords',
    documentId: approvalId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      experimentReviewRecordId: reviewId,
      pilotEvidenceRecordId: evidenceId,
      candidatePromotionRecordId: promotionId,
      promotionTarget,
      status,
    },
  });

  return {
    success: true,
    id: approvalId,
    candidateModelPackageId,
    status,
  };
});

export const upsertFederatedLearningPilotExecutionRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const status = normalizeFederatedLearningPilotExecutionStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be planned, launched, observed, or completed.');
  }

  const launchedSiteIds = toStringArray(request.data?.launchedSiteIds);
  const sessionCount = typeof request.data?.sessionCount === 'number' && Number.isFinite(request.data.sessionCount)
    ? Math.max(0, Math.trunc(request.data.sessionCount))
    : 0;
  const learnerCount = typeof request.data?.learnerCount === 'number' && Number.isFinite(request.data.learnerCount)
    ? Math.max(0, Math.trunc(request.data.learnerCount))
    : 0;
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);

  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId);
  const approvalId = buildFederatedLearningPilotApprovalRecordDocId(candidateModelPackageId);
  const executionId = buildFederatedLearningPilotExecutionRecordDocId(candidateModelPackageId);
  const approvalSnap = await admin.firestore().collection('federatedLearningPilotApprovalRecords').doc(approvalId).get();
  const approvalData = (approvalSnap.data() || {}) as Record<string, unknown>;

  if (['launched', 'observed', 'completed'].includes(status)) {
    if (!approvalSnap.exists || asTrimmedString(approvalData.status) !== 'approved') {
      throw new HttpsError('failed-precondition', 'Pilot execution beyond planning requires an approved pilot approval record.');
    }
  }
  if (['observed', 'completed'].includes(status) && (launchedSiteIds.length === 0 || sessionCount <= 0 || learnerCount <= 0)) {
    throw new HttpsError(
      'failed-precondition',
      'Observed or completed pilot execution requires launched sites plus positive session and learner counts.',
    );
  }

  const experimentSnap = await admin.firestore().collection('federatedLearningExperiments').doc(experimentId).get();
  const experimentData = (experimentSnap.data() || {}) as Record<string, unknown>;
  const allowedSiteIds = toStringArray(experimentData.allowedSiteIds);
  if (launchedSiteIds.some((siteId) => !allowedSiteIds.includes(siteId))) {
    throw new HttpsError('failed-precondition', 'Pilot execution sites must be within the experiment allowed-site cohort.');
  }

  const executionRef = admin.firestore().collection('federatedLearningPilotExecutionRecords').doc(executionId);
  await admin.firestore().runTransaction(async (transaction) => {
    transaction.set(executionRef, {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      pilotApprovalRecordId: approvalId,
      status,
      launchedSiteIds,
      sessionCount,
      learnerCount,
      notes,
      recordedBy: actor.uid,
      recordedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestPilotExecutionRecordId: executionId,
      latestPilotExecutionStatus: status,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('pilot_execution_record.upsert'),
    collection: 'federatedLearningPilotExecutionRecords',
    documentId: executionId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      pilotApprovalRecordId: approvalId,
      status,
      launchedSiteIds,
      sessionCount,
      learnerCount,
    },
  });

  return {
    success: true,
    id: executionId,
    candidateModelPackageId,
    status,
  };
});

export const upsertFederatedLearningRuntimeDeliveryRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const status = normalizeFederatedLearningRuntimeDeliveryStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be prepared, assigned, active, or revoked.');
  }

  const targetSiteIds = toStringArray(request.data?.targetSiteIds);
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);
  const requestedExpiresAtValue = asNumber(request.data?.expiresAt);
  const requestedExpiresAt = requestedExpiresAtValue == null
    ? null
    : Math.max(0, Math.trunc(requestedExpiresAtValue));
  const revocationReason = asTrimmedString(request.data?.revocationReason).slice(0, 500);
  const now = Date.now();

  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId);
  const schemaVersions = toStringArray(packageData.schemaVersions);
  const packageDigest = asTrimmedString(packageData.packageDigest);
  const boundedDigest = asTrimmedString(packageData.boundedDigest);
  const triggerSummaryId = asTrimmedString(packageData.triggerSummaryId);
  const summaryIds = toStringArray(packageData.summaryIds);
  const optimizerStrategies = toStringArray(packageData.optimizerStrategies);
  const compatibilityKey = asTrimmedString(packageData.compatibilityKey);
  const warmStartPackageId = asTrimmedString(packageData.warmStartPackageId);
  const warmStartModelVersion = asTrimmedString(packageData.warmStartModelVersion);
  const executionId = buildFederatedLearningPilotExecutionRecordDocId(candidateModelPackageId);
  const deliveryId = buildFederatedLearningRuntimeDeliveryRecordDocId(candidateModelPackageId);
  const deliveryRef = admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').doc(deliveryId);

  const [experimentSnap, executionSnap, existingDeliverySnap] = await Promise.all([
    admin.firestore().collection('federatedLearningExperiments').doc(experimentId).get(),
    admin.firestore().collection('federatedLearningPilotExecutionRecords').doc(executionId).get(),
    deliveryRef.get(),
  ]);
  if (!experimentSnap.exists) {
    throw new HttpsError('not-found', 'Federated learning experiment not found.');
  }

  const experimentData = (experimentSnap.data() || {}) as Record<string, unknown>;
  const executionData = (executionSnap.data() || {}) as Record<string, unknown>;
  const existingDeliveryData = (existingDeliverySnap.data() || {}) as Record<string, unknown>;
  const allowedSiteIds = toStringArray(experimentData.allowedSiteIds);
  const executionStatus = asTrimmedString(executionData.status);
  const existingTargetSiteIds = toStringArray(existingDeliveryData.targetSiteIds);
  const existingExpiresAt = typeof existingDeliveryData.expiresAt === 'number'
    ? Math.trunc(existingDeliveryData.expiresAt)
    : 0;
  const effectiveTargetSiteIds = targetSiteIds.length > 0
    ? targetSiteIds
    : (status === 'revoked' ? existingTargetSiteIds : []);

  if (['assigned', 'active'].includes(status) && requestedExpiresAt != null && requestedExpiresAt <= now) {
    throw new HttpsError(
      'failed-precondition',
      'Assigned or active runtime delivery requires expiresAt to be in the future.',
    );
  }
  if (status === 'revoked' && !revocationReason) {
    throw new HttpsError('failed-precondition', 'Revoked runtime delivery requires a revocationReason.');
  }

  const effectiveExpiresAt = ['assigned', 'active'].includes(status)
    ? (requestedExpiresAt ?? (existingExpiresAt > now ? existingExpiresAt : now + (7 * 24 * 60 * 60 * 1000)))
    : (status === 'revoked' && existingExpiresAt > 0 ? existingExpiresAt : null);

  if (['assigned', 'active'].includes(status)) {
    if (!executionSnap.exists || !['observed', 'completed'].includes(executionStatus)) {
      throw new HttpsError(
        'failed-precondition',
        'Assigned or active runtime delivery requires observed or completed pilot execution.',
      );
    }
    if (targetSiteIds.length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'Assigned or active runtime delivery requires at least one target site.',
      );
    }
  }
  if (effectiveTargetSiteIds.some((siteId) => !allowedSiteIds.includes(siteId))) {
    throw new HttpsError('failed-precondition', 'Runtime delivery sites must be within the experiment allowed-site cohort.');
  }

  const packageRuntimeTargets = toStringArray(packageData.runtimeTargets);
  const runtimeTarget = normalizeFederatedLearningRuntimeTarget(packageRuntimeTargets[0])
    || normalizeFederatedLearningRuntimeTarget(experimentData.runtimeTarget)
    || 'flutter_mobile';
  const manifestDigest = buildFederatedLearningRuntimeDeliveryManifestDigest(
    packageDigest,
    effectiveTargetSiteIds,
    status,
    runtimeTarget,
    effectiveExpiresAt ?? undefined,
  );
  const overlappingDeliveriesQuery = admin.firestore()
    .collection('federatedLearningRuntimeDeliveryRecords')
    .where('experimentId', '==', experimentId)
    .where('runtimeTarget', '==', runtimeTarget)
    .limit(50);
  const supersededDeliveries: Array<{
    id: string;
    candidateModelPackageId: string;
    targetSiteIds: string[];
  }> = [];

  await admin.firestore().runTransaction(async (transaction) => {
    const overlappingDeliveriesSnap = ['assigned', 'active'].includes(status)
      ? await transaction.get(overlappingDeliveriesQuery)
      : null;
    if (overlappingDeliveriesSnap) {
      overlappingDeliveriesSnap.docs.forEach((snapDoc) => {
        if (snapDoc.id === deliveryId) {
          return;
        }
        const rowData = snapDoc.data() as Record<string, unknown>;
        const rowStatus = asTrimmedString(rowData.status);
        const rowPackageId = asTrimmedString(rowData.candidateModelPackageId);
        const rowTargetSiteIds = toStringArray(rowData.targetSiteIds);
        const overlaps = rowTargetSiteIds.some((siteId) => effectiveTargetSiteIds.includes(siteId));
        if (!['assigned', 'active'].includes(rowStatus) || !rowPackageId || !overlaps) {
          return;
        }
        supersededDeliveries.push({
          id: snapDoc.id,
          candidateModelPackageId: rowPackageId,
          targetSiteIds: rowTargetSiteIds,
        });
        transaction.set(snapDoc.ref, {
          status: 'superseded',
          supersededAt: FieldValue.serverTimestamp(),
          supersededBy: actor.uid,
          supersededByDeliveryRecordId: deliveryId,
          supersededByCandidateModelPackageId: candidateModelPackageId,
          supersessionReason: `Superseded by ${deliveryId} for overlapping site cohort.`,
          revokedAt: FieldValue.delete(),
          revokedBy: FieldValue.delete(),
          revocationReason: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(
          admin.firestore().collection('federatedLearningCandidateModelPackages').doc(rowPackageId),
          {
            latestRuntimeDeliveryStatus: 'superseded',
            rolloutStatus: 'retired',
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });
    }

    transaction.set(deliveryRef, {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      pilotExecutionRecordId: executionId,
      runtimeTarget,
      targetSiteIds: effectiveTargetSiteIds,
      status,
      packageDigest,
      boundedDigest,
      triggerSummaryId,
      summaryIds,
      schemaVersions,
      optimizerStrategies,
      compatibilityKey,
      warmStartPackageId,
      warmStartModelVersion,
      manifestDigest,
      expiresAt: effectiveExpiresAt ?? FieldValue.delete(),
      supersededAt: FieldValue.delete(),
      supersededBy: FieldValue.delete(),
      supersededByDeliveryRecordId: FieldValue.delete(),
      supersededByCandidateModelPackageId: FieldValue.delete(),
      supersessionReason: FieldValue.delete(),
      revokedAt: status === 'revoked' ? FieldValue.serverTimestamp() : FieldValue.delete(),
      revokedBy: status === 'revoked' ? actor.uid : FieldValue.delete(),
      revocationReason: status === 'revoked' ? revocationReason : FieldValue.delete(),
      notes,
      assignedBy: actor.uid,
      assignedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestRuntimeDeliveryRecordId: deliveryId,
      latestRuntimeDeliveryStatus: status,
      rolloutStatus: ['assigned', 'active'].includes(status)
        ? 'distributed'
        : ['superseded', 'revoked'].includes(status)
          ? 'retired'
          : 'not_distributed',
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await Promise.all(supersededDeliveries.map((delivery) =>
    admin.firestore().collection('auditLogs').add({
      userId: actor.uid,
      action: federatedLearningAuditAction('runtime_delivery_record.upsert'),
      collection: 'federatedLearningRuntimeDeliveryRecords',
      documentId: delivery.id,
      timestamp: Date.now(),
      details: {
        experimentId,
        candidateModelPackageId: delivery.candidateModelPackageId,
        runtimeTarget,
        targetSiteIds: delivery.targetSiteIds,
        status: 'superseded',
        supersededByDeliveryRecordId: deliveryId,
        supersededByCandidateModelPackageId: candidateModelPackageId,
      },
    }),
  ));

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('runtime_delivery_record.upsert'),
    collection: 'federatedLearningRuntimeDeliveryRecords',
    documentId: deliveryId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      pilotExecutionRecordId: executionId,
      runtimeTarget,
      targetSiteIds,
      status,
      manifestDigest,
      schemaVersions,
      optimizerStrategies,
      compatibilityKey,
      warmStartPackageId,
      warmStartModelVersion,
    },
  });

  return {
    success: true,
    id: deliveryId,
    candidateModelPackageId,
    status,
  };
});

export const upsertFederatedLearningRuntimeActivationRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  if (!deliveryRecordId) {
    throw new HttpsError('invalid-argument', 'deliveryRecordId is required.');
  }

  const status = normalizeFederatedLearningRuntimeActivationStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be resolved, staged, or fallback.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const targetSiteId = requestedSiteId
    || asTrimmedString(actor.profile.activeSiteId)
    || asTrimmedString(actor.profile.siteIds?.[0]);
  if (!targetSiteId) {
    throw new HttpsError('failed-precondition', 'No site context provided.');
  }
  if (!actorCanAccessSite(actor, targetSiteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const traceId = asTrimmedString(request.data?.traceId).slice(0, 200);
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);
  const deliveryRef = admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').doc(deliveryRecordId);
  const deliverySnap = await deliveryRef.get();
  if (!deliverySnap.exists) {
    throw new HttpsError('not-found', 'Runtime delivery record not found.');
  }

  const deliveryData = (deliverySnap.data() || {}) as Record<string, unknown>;
  const deliveryStatus = asTrimmedString(deliveryData.status);
  const targetSiteIds = toStringArray(deliveryData.targetSiteIds);
  if (!targetSiteIds.includes(targetSiteId)) {
    throw new HttpsError('permission-denied', 'Runtime delivery record is not assigned to the requested site.');
  }
  const deliveryExpiresAt = typeof deliveryData.expiresAt === 'number' ? Math.trunc(deliveryData.expiresAt) : 0;
  const deliveryRevokedAt = typeof deliveryData.revokedAt === 'number' ? Math.trunc(deliveryData.revokedAt) : 0;
  const now = Date.now();
  const deliveryUsable = ['assigned', 'active'].includes(deliveryStatus)
    && deliveryRevokedAt === 0
    && (deliveryExpiresAt === 0 || deliveryExpiresAt > now);
  if (status === 'fallback') {
    if (!['assigned', 'active', 'revoked'].includes(deliveryStatus)) {
      throw new HttpsError('failed-precondition', 'Runtime fallback evidence requires a delivery record assigned to the requested site.');
    }
  } else if (!deliveryUsable) {
    throw new HttpsError('failed-precondition', 'Runtime activation evidence requires an assigned or active, non-expired runtime delivery record.');
  }

  const activationId = buildFederatedLearningRuntimeActivationRecordDocId(deliveryRecordId, targetSiteId);
  const activationRef = admin.firestore().collection('federatedLearningRuntimeActivationRecords').doc(activationId);
  const experimentId = asTrimmedString(deliveryData.experimentId);
  const candidateModelPackageId = asTrimmedString(deliveryData.candidateModelPackageId);
  const runtimeTarget = normalizeFederatedLearningRuntimeTarget(deliveryData.runtimeTarget) || 'flutter_mobile';
  const packageDigest = asTrimmedString(deliveryData.packageDigest);
  const boundedDigest = asTrimmedString(deliveryData.boundedDigest);
  const triggerSummaryId = asTrimmedString(deliveryData.triggerSummaryId);
  const summaryIds = toStringArray(deliveryData.summaryIds);
  const schemaVersions = toStringArray(deliveryData.schemaVersions);
  const optimizerStrategies = toStringArray(deliveryData.optimizerStrategies);
  const compatibilityKey = asTrimmedString(deliveryData.compatibilityKey);
  const warmStartPackageId = asTrimmedString(deliveryData.warmStartPackageId);
  const warmStartModelVersion = asTrimmedString(deliveryData.warmStartModelVersion);
  const manifestDigest = asTrimmedString(deliveryData.manifestDigest);

  await activationRef.set({
    deliveryRecordId,
    experimentId,
    candidateModelPackageId,
    siteId: targetSiteId,
    runtimeTarget,
    packageDigest,
    boundedDigest,
    triggerSummaryId,
    summaryIds,
    schemaVersions,
    optimizerStrategies,
    compatibilityKey,
    warmStartPackageId,
    warmStartModelVersion,
    manifestDigest,
    status,
    traceId,
    notes,
    reportedBy: actor.uid,
    reportedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('runtime_activation_record.upsert'),
    collection: 'federatedLearningRuntimeActivationRecords',
    documentId: activationId,
    timestamp: Date.now(),
    details: {
      deliveryRecordId,
      experimentId,
      candidateModelPackageId,
      siteId: targetSiteId,
      runtimeTarget,
      packageDigest,
      boundedDigest,
      triggerSummaryId,
      summaryIds,
      schemaVersions,
      optimizerStrategies,
      compatibilityKey,
      warmStartPackageId,
      warmStartModelVersion,
      status,
      manifestDigest,
    },
  });

  return {
    success: true,
    id: activationId,
    deliveryRecordId,
    status,
  };
});

export const upsertFederatedLearningRuntimeRolloutAlertRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  if (!deliveryRecordId) {
    throw new HttpsError('invalid-argument', 'deliveryRecordId is required.');
  }

  const requestedStatus = normalizeFederatedLearningRuntimeRolloutAlertStatus(request.data?.status);
  if (!requestedStatus) {
    throw new HttpsError('invalid-argument', 'status must be active or acknowledged.');
  }

  const notes = asTrimmedString(request.data?.notes).slice(0, 500);
  const deliveryRef = admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').doc(deliveryRecordId);
  const deliverySnap = await deliveryRef.get();
  if (!deliverySnap.exists) {
    throw new HttpsError('not-found', 'Runtime delivery record not found.');
  }

  const deliveryData = (deliverySnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(deliveryData.experimentId);
  const candidateModelPackageId = asTrimmedString(deliveryData.candidateModelPackageId);
  const lineage = buildRuntimeDeliveryLineageSnapshot(deliveryData);
  const targetSiteIds = lineage.targetSiteIds;
  const alertId = buildFederatedLearningRuntimeRolloutAlertRecordDocId(deliveryRecordId);
  const alertRef = admin.firestore().collection('federatedLearningRuntimeRolloutAlertRecords').doc(alertId);

  const activationSnap = await admin.firestore()
    .collection('federatedLearningRuntimeActivationRecords')
    .where('deliveryRecordId', '==', deliveryRecordId)
    .limit(Math.max(50, targetSiteIds.length || 0) + 50)
    .get();

  const activationStatusBySite = new Map<string, string>();
  activationSnap.docs.forEach((snapDoc) => {
    const row = (snapDoc.data() || {}) as Record<string, unknown>;
    const siteId = asTrimmedString(row.siteId);
    const activationStatus = normalizeFederatedLearningRuntimeActivationStatus(row.status);
    if (siteId && activationStatus) {
      activationStatusBySite.set(siteId, activationStatus);
    }
  });

  let fallbackCount = 0;
  let pendingCount = 0;
  targetSiteIds.forEach((siteId) => {
    const activationStatus = activationStatusBySite.get(siteId);
    if (activationStatus === 'fallback') {
      fallbackCount += 1;
      return;
    }
    if (!activationStatus) {
      pendingCount += 1;
    }
  });

  const terminalLifecycleStatus = getRuntimeDeliveryTerminalLifecycleStatus(deliveryData);
  const status = terminalLifecycleStatus || (fallbackCount === 0 && pendingCount === 0)
    ? 'acknowledged'
    : requestedStatus;

  await alertRef.set({
    experimentId,
    candidateModelPackageId,
    deliveryRecordId,
    ...lineage,
    status,
    fallbackCount,
    pendingCount,
    notes,
    acknowledgedBy: status === 'acknowledged' ? actor.uid : FieldValue.delete(),
    acknowledgedAt: status === 'acknowledged' ? FieldValue.serverTimestamp() : FieldValue.delete(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('runtime_rollout_alert_record.upsert'),
    collection: 'federatedLearningRuntimeRolloutAlertRecords',
    documentId: alertId,
    timestamp: Date.now(),
    details: {
      deliveryRecordId,
      experimentId,
      candidateModelPackageId,
      ...lineage,
      status,
      requestedStatus,
      fallbackCount,
      pendingCount,
      targetSiteIds,
      notes,
      terminalLifecycleStatus: terminalLifecycleStatus || '',
      acknowledgedBy: status === 'acknowledged' ? actor.uid : '',
    },
  });

  return {
    success: true,
    id: alertId,
    deliveryRecordId,
    status,
    requestedStatus,
    fallbackCount,
    pendingCount,
  };
});

export const upsertFederatedLearningRuntimeRolloutEscalationRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  if (!deliveryRecordId) {
    throw new HttpsError('invalid-argument', 'deliveryRecordId is required.');
  }

  const requestedStatus = normalizeFederatedLearningRuntimeRolloutEscalationStatus(request.data?.status);
  if (!requestedStatus) {
    throw new HttpsError('invalid-argument', 'status must be open, investigating, or resolved.');
  }

  const ownerUserId = asTrimmedString(request.data?.ownerUserId).slice(0, 200);
  const notes = asTrimmedString(request.data?.notes).slice(0, 500);
  const deliveryRef = admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').doc(deliveryRecordId);
  const deliverySnap = await deliveryRef.get();
  if (!deliverySnap.exists) {
    throw new HttpsError('not-found', 'Runtime delivery record not found.');
  }

  const deliveryData = (deliverySnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(deliveryData.experimentId);
  const candidateModelPackageId = asTrimmedString(deliveryData.candidateModelPackageId);
  const lineage = buildRuntimeDeliveryLineageSnapshot(deliveryData);
  const targetSiteIds = lineage.targetSiteIds;
  const escalationId = buildFederatedLearningRuntimeRolloutEscalationRecordDocId(deliveryRecordId);
  const escalationRef = admin.firestore().collection('federatedLearningRuntimeRolloutEscalationRecords').doc(escalationId);
  const escalationSnap = await escalationRef.get();
  const escalationData = (escalationSnap.data() || {}) as Record<string, unknown>;

  const activationSnap = await admin.firestore()
    .collection('federatedLearningRuntimeActivationRecords')
    .where('deliveryRecordId', '==', deliveryRecordId)
    .limit(Math.max(50, targetSiteIds.length || 0) + 50)
    .get();

  const activationStatusBySite = new Map<string, string>();
  activationSnap.docs.forEach((snapDoc) => {
    const row = (snapDoc.data() || {}) as Record<string, unknown>;
    const siteId = asTrimmedString(row.siteId);
    const activationStatus = normalizeFederatedLearningRuntimeActivationStatus(row.status);
    if (siteId && activationStatus) {
      activationStatusBySite.set(siteId, activationStatus);
    }
  });

  let fallbackCount = 0;
  let pendingCount = 0;
  targetSiteIds.forEach((siteId) => {
    const activationStatus = activationStatusBySite.get(siteId);
    if (activationStatus === 'fallback') {
      fallbackCount += 1;
      return;
    }
    if (!activationStatus) {
      pendingCount += 1;
    }
  });

  const currentIssueActive = fallbackCount > 0 || pendingCount > 0;
  const terminalLifecycleStatus = getRuntimeDeliveryTerminalLifecycleStatus(deliveryData);
  const existingStatus = normalizeFederatedLearningRuntimeRolloutEscalationStatus(escalationData.status);
  const reopenedStatus = existingStatus && existingStatus !== 'resolved'
    ? existingStatus
    : 'open';
  const status = terminalLifecycleStatus || !currentIssueActive
    ? 'resolved'
    : requestedStatus === 'resolved'
      ? reopenedStatus
      : requestedStatus;
  const existingOwnerUserId = asTrimmedString(escalationData.ownerUserId);
  const effectiveOwnerUserId = status === 'resolved'
    ? ''
    : (ownerUserId || existingOwnerUserId);
  if (status !== 'resolved' && !effectiveOwnerUserId) {
    throw new HttpsError(
      'failed-precondition',
      'Open or investigating rollout escalation requires ownerUserId.',
    );
  }
  const existingOpenedAt = asTimestampMillis(escalationData.openedAt);
  const openedAt = status === 'resolved' || !currentIssueActive
    ? null
    : (existingOpenedAt ?? Date.now());
  const dueAt = openedAt == null
    ? null
    : buildRuntimeRolloutEscalationDueAt(status, fallbackCount, pendingCount, openedAt);
  const createdAt = escalationSnap.exists
    ? (escalationData.createdAt ?? FieldValue.serverTimestamp())
    : FieldValue.serverTimestamp();

  await escalationRef.set({
    experimentId,
    candidateModelPackageId,
    deliveryRecordId,
    ...lineage,
    status,
    fallbackCount,
    pendingCount,
    openedAt: openedAt ?? FieldValue.delete(),
    dueAt: dueAt ?? FieldValue.delete(),
    ownerUserId: effectiveOwnerUserId || FieldValue.delete(),
    notes,
    resolvedBy: status === 'resolved' ? actor.uid : FieldValue.delete(),
    resolvedAt: status === 'resolved' ? FieldValue.serverTimestamp() : FieldValue.delete(),
    createdAt,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('federatedLearningRuntimeRolloutEscalationHistoryRecords').add({
    escalationRecordId: escalationId,
    experimentId,
    candidateModelPackageId,
    deliveryRecordId,
    ...lineage,
    status,
    fallbackCount,
    pendingCount,
    openedAt: openedAt ?? FieldValue.delete(),
    dueAt: dueAt ?? FieldValue.delete(),
    ownerUserId: effectiveOwnerUserId || FieldValue.delete(),
    notes,
    resolvedBy: status === 'resolved' ? actor.uid : FieldValue.delete(),
    resolvedAt: status === 'resolved' ? FieldValue.serverTimestamp() : FieldValue.delete(),
    recordedBy: actor.uid,
    recordedAt: Date.now(),
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('runtime_rollout_escalation_record.upsert'),
    collection: 'federatedLearningRuntimeRolloutEscalationRecords',
    documentId: escalationId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      deliveryRecordId,
      ...lineage,
      status,
      requestedStatus,
      ownerUserId: effectiveOwnerUserId,
      fallbackCount,
      pendingCount,
      openedAt,
      dueAt,
      targetSiteIds,
      notes,
      terminalLifecycleStatus: terminalLifecycleStatus || '',
      resolvedBy: status === 'resolved' ? actor.uid : '',
    },
  });

  return {
    success: true,
    id: escalationId,
    deliveryRecordId,
    status,
    requestedStatus,
    fallbackCount,
    pendingCount,
  };
});

export const upsertFederatedLearningRuntimeRolloutControlRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const deliveryRecordId = asTrimmedString(request.data?.deliveryRecordId);
  if (!deliveryRecordId) {
    throw new HttpsError('invalid-argument', 'deliveryRecordId is required.');
  }

  const requestedMode = normalizeFederatedLearningRuntimeRolloutControlMode(request.data?.mode);
  if (!requestedMode) {
    throw new HttpsError('invalid-argument', 'mode must be monitor, restricted, or paused.');
  }

  const ownerUserId = asTrimmedString(request.data?.ownerUserId).slice(0, 200);
  const reason = asTrimmedString(request.data?.reason).slice(0, 500);
  const reviewByAtValue = asNumber(request.data?.reviewByAt);
  const reviewByAt = reviewByAtValue == null ? null : Math.max(0, Math.trunc(reviewByAtValue));
  if (requestedMode !== 'monitor' && !reason) {
    throw new HttpsError('failed-precondition', 'Restricted or paused rollout control requires a reason.');
  }

  const deliveryRef = admin.firestore().collection('federatedLearningRuntimeDeliveryRecords').doc(deliveryRecordId);
  const deliverySnap = await deliveryRef.get();
  if (!deliverySnap.exists) {
    throw new HttpsError('not-found', 'Runtime delivery record not found.');
  }

  const deliveryData = (deliverySnap.data() || {}) as Record<string, unknown>;
  const experimentId = asTrimmedString(deliveryData.experimentId);
  const candidateModelPackageId = asTrimmedString(deliveryData.candidateModelPackageId);
  const lineage = buildRuntimeDeliveryLineageSnapshot(deliveryData);
  const controlId = buildFederatedLearningRuntimeRolloutControlRecordDocId(deliveryRecordId);
  const controlRef = admin.firestore().collection('federatedLearningRuntimeRolloutControlRecords').doc(controlId);
  const controlSnap = await controlRef.get();
  const controlData = (controlSnap.data() || {}) as Record<string, unknown>;
  const terminalLifecycleStatus = getRuntimeDeliveryTerminalLifecycleStatus(deliveryData);
  const mode = terminalLifecycleStatus ? 'monitor' : requestedMode;
  const existingOwnerUserId = asTrimmedString(controlData.ownerUserId);
  const effectiveOwnerUserId = mode === 'monitor'
    ? ''
    : (ownerUserId || existingOwnerUserId);
  if (mode !== 'monitor' && !effectiveOwnerUserId) {
    throw new HttpsError(
      'failed-precondition',
      'Restricted or paused rollout control requires ownerUserId.',
    );
  }
  const createdAt = controlSnap.exists
    ? (controlData.createdAt ?? FieldValue.serverTimestamp())
    : FieldValue.serverTimestamp();

  await controlRef.set({
    experimentId,
    candidateModelPackageId,
    deliveryRecordId,
    ...lineage,
    mode,
    ownerUserId: terminalLifecycleStatus
      ? FieldValue.delete()
      : (effectiveOwnerUserId || FieldValue.delete()),
    reason: mode === 'monitor' ? FieldValue.delete() : (reason || FieldValue.delete()),
    reviewByAt: mode === 'monitor' ? FieldValue.delete() : (reviewByAt ?? FieldValue.delete()),
    releasedBy: mode === 'monitor' ? actor.uid : FieldValue.delete(),
    releasedAt: mode === 'monitor' ? FieldValue.serverTimestamp() : FieldValue.delete(),
    createdAt,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('runtime_rollout_control_record.upsert'),
    collection: 'federatedLearningRuntimeRolloutControlRecords',
    documentId: controlId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      deliveryRecordId,
      ...lineage,
      mode,
      requestedMode,
      ownerUserId: effectiveOwnerUserId,
      reason,
      reviewByAt,
      terminalLifecycleStatus: terminalLifecycleStatus || '',
    },
  });

  return {
    success: true,
    id: controlId,
    deliveryRecordId,
    mode,
    requestedMode,
  };
});

export const upsertFederatedLearningCandidatePromotionRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const status = normalizeFederatedLearningCandidatePromotionStatus(request.data?.status);
  if (!status) {
    throw new HttpsError('invalid-argument', 'status must be approved_for_eval or hold.');
  }

  const target = normalizeFederatedLearningCandidatePromotionTarget(request.data?.target) ?? 'sandbox_eval';
  const rationale = asTrimmedString(request.data?.rationale).slice(0, 500);
  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  if (asTrimmedString(packageData.status) !== 'staged') {
    throw new HttpsError('failed-precondition', 'Only staged candidate model packages can receive promotion records.');
  }

  const promotionId = buildFederatedLearningCandidatePromotionRecordDocId(candidateModelPackageId);
  const promotionRef = admin.firestore().collection('federatedLearningCandidatePromotionRecords').doc(promotionId);
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId);
  const packageDigest = asTrimmedString(packageData.packageDigest);
  const boundedDigest = asTrimmedString(packageData.boundedDigest);

  await admin.firestore().runTransaction(async (transaction) => {
    transaction.set(promotionRef, {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      packageDigest,
      boundedDigest,
      status,
      target,
      rationale,
      decidedBy: actor.uid,
      decidedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestPromotionRecordId: promotionId,
      latestPromotionStatus: status,
      latestPromotionRevocationRecordId: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('candidate_promotion_record.upsert'),
    collection: 'federatedLearningCandidatePromotionRecords',
    documentId: promotionId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      aggregationRunId,
      mergeArtifactId,
      packageDigest,
      boundedDigest,
      status,
      target,
    },
  });

  return {
    success: true,
    id: promotionId,
    candidateModelPackageId,
    status,
    target,
  };
});

export const revokeFederatedLearningCandidatePromotionRecord = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const candidateModelPackageId = asTrimmedString(request.data?.candidateModelPackageId);
  if (!candidateModelPackageId) {
    throw new HttpsError('invalid-argument', 'candidateModelPackageId is required.');
  }

  const rationale = asTrimmedString(request.data?.rationale).slice(0, 500);
  const packageRef = admin.firestore().collection('federatedLearningCandidateModelPackages').doc(candidateModelPackageId);
  const packageSnap = await packageRef.get();
  if (!packageSnap.exists) {
    throw new HttpsError('not-found', 'Candidate model package not found.');
  }

  const promotionId = buildFederatedLearningCandidatePromotionRecordDocId(candidateModelPackageId);
  const promotionRef = admin.firestore().collection('federatedLearningCandidatePromotionRecords').doc(promotionId);
  const promotionSnap = await promotionRef.get();
  if (!promotionSnap.exists) {
    throw new HttpsError('failed-precondition', 'Promotion record not found for candidate model package.');
  }

  const packageData = (packageSnap.data() || {}) as Record<string, unknown>;
  const promotionData = (promotionSnap.data() || {}) as Record<string, unknown>;
  const revocationId = buildFederatedLearningCandidatePromotionRevocationRecordDocId(candidateModelPackageId);
  const revocationRef = admin.firestore().collection('federatedLearningCandidatePromotionRevocationRecords').doc(revocationId);
  const experimentId = asTrimmedString(packageData.experimentId);
  const aggregationRunId = asTrimmedString(packageData.aggregationRunId || promotionData.aggregationRunId);
  const mergeArtifactId = asTrimmedString(packageData.mergeArtifactId || promotionData.mergeArtifactId);
  const packageDigest = asTrimmedString(packageData.packageDigest || promotionData.packageDigest);
  const boundedDigest = asTrimmedString(packageData.boundedDigest || promotionData.boundedDigest);
  const revokedStatus = asTrimmedString(promotionData.status);
  const target = asTrimmedString(promotionData.target) || 'sandbox_eval';

  await admin.firestore().runTransaction(async (transaction) => {
    transaction.set(revocationRef, {
      experimentId,
      candidateModelPackageId,
      candidatePromotionRecordId: promotionId,
      aggregationRunId,
      mergeArtifactId,
      packageDigest,
      boundedDigest,
      revokedStatus,
      target,
      rationale,
      revokedBy: actor.uid,
      revokedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(packageRef, {
      latestPromotionStatus: 'revoked',
      latestPromotionRevocationRecordId: revocationId,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('candidate_promotion_record.revoke'),
    collection: 'federatedLearningCandidatePromotionRevocationRecords',
    documentId: revocationId,
    timestamp: Date.now(),
    details: {
      experimentId,
      candidateModelPackageId,
      candidatePromotionRecordId: promotionId,
      aggregationRunId,
      mergeArtifactId,
      packageDigest,
      boundedDigest,
      revokedStatus,
      target,
    },
  });

  return {
    success: true,
    id: revocationId,
    candidateModelPackageId,
  };
});

export const upsertFederatedLearningExperiment = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  let config;
  try {
    config = sanitizeFederatedLearningExperimentConfig((request.data || {}) as Record<string, unknown>);
  } catch (error) {
    throw new HttpsError('invalid-argument', error instanceof Error ? error.message : 'Invalid experiment config.');
  }

  const requestedId = asTrimmedString(request.data?.id);
  const id = requestedId || buildFederatedLearningExperimentDocId(config.name);
  const featureFlagId = buildFederatedLearningFeatureFlagId(id);
  const ref = admin.firestore().collection('federatedLearningExperiments').doc(id);

  await ref.set({
    ...config,
    featureFlagId,
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('featureFlags').doc(featureFlagId).set({
    ...buildFederatedLearningFeatureFlagPayload(id, config),
    updatedBy: actor.uid,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('experiment.upsert'),
    collection: 'federatedLearningExperiments',
    documentId: id,
    timestamp: Date.now(),
    details: {
      runtimeTarget: config.runtimeTarget,
      status: config.status,
      mergeStrategy: config.mergeStrategy,
      requireWarmStartForTraining: config.requireWarmStartForTraining,
      maxLocalEpochs: config.maxLocalEpochs,
      maxLocalSteps: config.maxLocalSteps,
      maxTrainingWindowSeconds: config.maxTrainingWindowSeconds,
      allowedSiteIds: config.allowedSiteIds,
      aggregateThreshold: config.aggregateThreshold,
      minDistinctSiteCount: config.minDistinctSiteCount,
      rawUpdateMaxBytes: config.rawUpdateMaxBytes,
      featureFlagId,
    },
  });

  return { success: true, id, featureFlagId };
});

export const recordFederatedLearningPrototypeUpdate = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const experimentId = asTrimmedString(request.data?.experimentId);
  if (!experimentId) {
    throw new HttpsError('invalid-argument', 'experimentId is required.');
  }

  const experimentRef = admin.firestore().collection('federatedLearningExperiments').doc(experimentId);
  const experimentSnap = await experimentRef.get();
  if (!experimentSnap.exists) {
    throw new HttpsError('not-found', 'Federated learning experiment not found.');
  }

  const experiment = (experimentSnap.data() || {}) as Record<string, unknown>;
  const siteId = asTrimmedString(request.data?.siteId);
  if (!siteId || !actorCanAccessSite(actor, siteId)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }

  const allowedSiteIds = toStringArray(experiment.allowedSiteIds);
  if (allowedSiteIds.length === 0 || !allowedSiteIds.includes(siteId)) {
    throw new HttpsError('failed-precondition', 'Site is not enrolled in the requested experiment.');
  }

  const status = asTrimmedString(experiment.status);
  if (!['pilot_ready', 'active'].includes(status)) {
    throw new HttpsError('failed-precondition', 'Experiment is not accepting prototype updates.');
  }
  if (experiment.enablePrototypeUploads !== true) {
    throw new HttpsError('failed-precondition', 'Prototype uploads are disabled for this experiment.');
  }

  const featureFlagId = asTrimmedString(experiment.featureFlagId);
  if (featureFlagId) {
    const flagSnap = await admin.firestore().collection('featureFlags').doc(featureFlagId).get();
    const flagData = (flagSnap.data() || {}) as Record<string, unknown>;
    if (flagData.enabled !== true) {
      throw new HttpsError('failed-precondition', 'Experiment feature flag is disabled.');
    }
    const scope = asTrimmedString(flagData.scope) || 'site';
    const enabledSites = toStringArray(flagData.enabledSites);
    if (scope === 'site' && enabledSites.length > 0 && !enabledSites.includes(siteId)) {
      throw new HttpsError('failed-precondition', 'Site is outside the enabled feature-flag cohort.');
    }
  }

  const rawUpdateMaxBytes = typeof experiment.rawUpdateMaxBytes === 'number'
    ? experiment.rawUpdateMaxBytes
    : Number(experiment.rawUpdateMaxBytes || 16384);
  let summary;
  try {
    summary = sanitizeFederatedLearningUpdateSummary((request.data || {}) as Record<string, unknown>, rawUpdateMaxBytes);
  } catch (error) {
    throw new HttpsError('invalid-argument', error instanceof Error ? error.message : 'Invalid update summary.');
  }

  const docRef = await admin.firestore().collection('federatedLearningUpdateSummaries').add({
    experimentId,
    runtimeTarget: experiment.runtimeTarget || null,
    requestedBy: actor.uid,
    status: 'accepted',
    aggregationStatus: 'pending',
    ...summary,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const aggregationRun = await maybeMaterializeFederatedLearningAggregationRun({
    experimentId,
    experimentRef,
    experiment,
    actorId: actor.uid,
    triggerSummaryId: docRef.id,
  });

  await admin.firestore().collection('auditLogs').add({
    userId: actor.uid,
    action: federatedLearningAuditAction('prototype_update.recorded'),
    collection: 'federatedLearningUpdateSummaries',
    documentId: docRef.id,
    timestamp: Date.now(),
    details: {
      experimentId,
      siteId: summary.siteId,
      sampleCount: summary.sampleCount,
      vectorLength: summary.vectorLength,
      payloadBytes: summary.payloadBytes,
      traceId: summary.traceId,
    },
  });

  if (aggregationRun?.created) {
    await admin.firestore().collection('auditLogs').add({
      userId: actor.uid,
      action: federatedLearningAuditAction('aggregation_run.materialized'),
      collection: 'federatedLearningAggregationRuns',
      documentId: aggregationRun.runId,
      timestamp: Date.now(),
      details: {
        experimentId,
        triggerSummaryId: docRef.id,
      },
    });

    await admin.firestore().collection('auditLogs').add({
      userId: actor.uid,
      action: federatedLearningAuditAction('merge_artifact.generated'),
      collection: 'federatedLearningMergeArtifacts',
      documentId: aggregationRun.artifactId,
      timestamp: Date.now(),
      details: {
        experimentId,
        aggregationRunId: aggregationRun.runId,
      },
    });

    await admin.firestore().collection('auditLogs').add({
      userId: actor.uid,
      action: federatedLearningAuditAction('candidate_model_package.staged'),
      collection: 'federatedLearningCandidateModelPackages',
      documentId: aggregationRun.packageId,
      timestamp: Date.now(),
      details: {
        experimentId,
        aggregationRunId: aggregationRun.runId,
        mergeArtifactId: aggregationRun.artifactId,
      },
    });
  }

  return {
    success: true,
    id: docRef.id,
    experimentId,
    siteId: summary.siteId,
    aggregationRunId: aggregationRun?.runId || null,
    mergeArtifactId: aggregationRun?.artifactId || null,
    candidateModelPackageId: aggregationRun?.packageId || null,
    aggregationMaterialized: aggregationRun?.created === true,
  };
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
        amount: asNumber(row.amount),
        date: toIsoString(row.date || row.updatedAt || row.createdAt),
        status: asTrimmedString(row.status),
        description: asTrimmedString(row.description),
      };
    })
    .filter((row): row is { id: string; amount: number | null; date: string | null; status: string; description: string } => Boolean(row))
    .sort((a, b) => {
      const timeA = a.date ? Date.parse(a.date) : 0;
      const timeB = b.date ? Date.parse(b.date) : 0;
      return timeB - timeA;
    })
    .slice(0, 10);

  if (!accountSnap.exists && recentPayments.length === 0) {
    return {
      summary: null,
    };
  }

  return {
    summary: {
      parentId: targetParentId,
      currentBalance: asNumber(accountData?.currentBalance),
      nextPaymentAmount: asNumber(accountData?.nextPaymentAmount),
      nextPaymentDate: toIsoString(accountData?.nextPaymentDate),
      subscriptionPlan: asTrimmedString(accountData?.subscriptionPlan),
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
      const currency = asTrimmedString(row.currency).toUpperCase();
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

  const planName = asTrimmedString(siteData?.billingPlan);
  const planStatus = asTrimmedString(siteData?.billingStatus);
  const monthlyAmount = asNumber(siteData?.monthlyFee);
  const currency = asTrimmedString(siteData?.currency).toUpperCase();
  const nextBillingDate = toIsoString(siteData?.nextBillingDate);
  const activeLearnersUsed = asNumber(siteData?.learnerCount) ??
    (Array.isArray(siteData?.learnerIds) ? siteData?.learnerIds.length : null);
  const activeLearnersTotal = asNumber(siteData?.learnerCap) ?? asNumber(siteData?.billingLearnerLimit);
  const educatorsUsed = asNumber(siteData?.educatorCount) ??
    (Array.isArray(siteData?.educatorIds) ? siteData?.educatorIds.length : null);
  const educatorsTotal = asNumber(siteData?.educatorCap) ?? asNumber(siteData?.billingEducatorLimit);
  const storageUsedGb = asNumber(siteData?.storageUsedGb) ?? asNumber(siteData?.storageUsed);
  const storageTotalGb = asNumber(siteData?.storageCapGb) ?? asNumber(siteData?.storageLimitGb);
  const hasBillingSummary = Boolean(
    planName ||
      planStatus ||
      monthlyAmount !== null ||
      currency ||
      nextBillingDate ||
      activeLearnersTotal !== null ||
      educatorsTotal !== null ||
      storageTotalGb !== null ||
      invoices.length > 0,
  );

  return {
    siteId: targetSiteId,
    summary: hasBillingSummary ? {
      siteId: targetSiteId,
      planName,
      planStatus,
      monthlyAmount,
      currency,
      nextBillingDate,
      activeLearnersUsed,
      activeLearnersTotal,
      educatorsUsed,
      educatorsTotal,
      storageUsedGb,
      storageTotalGb,
    } : null,
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

function normalizeLifecycleStatus(value: unknown, fallback: string): string {
  const normalized = asTrimmedString(value).toLowerCase();
  return normalized.length > 0 ? normalized : fallback;
}

function toPositiveInteger(value: unknown, fallback = 0): number {
  const parsed = asNumber(value);
  if (parsed === null || !Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.round(parsed));
}

async function writeWorkflowAuditLog(params: {
  actor: { uid: string; role: Role };
  action: string;
  entityType: string;
  entityId: string;
  siteId?: string | null;
  details?: Record<string, unknown>;
}): Promise<void> {
  await admin.firestore().collection('auditLogs').add({
    actorId: params.actor.uid,
    actorRole: params.actor.role,
    action: params.action,
    entityType: params.entityType,
    entityId: params.entityId,
    siteId: params.siteId ?? null,
    details: params.details || {},
    createdAt: FieldValue.serverTimestamp(),
  });
}

function resolveActorSiteId(actor: { role: Role; profile: UserRecord }, requestedSiteId: unknown): string {
  const requested = asTrimmedString(requestedSiteId);
  const candidate = requested || asTrimmedString(actor.profile.activeSiteId) || toStringArray(actor.profile.siteIds)[0] || '';
  if (!candidate || !actorCanAccessSite(actor, candidate)) {
    throw new HttpsError('permission-denied', 'No access to requested site.');
  }
  return candidate;
}

function resolveOptionalActorSiteId(
  actor: { role: Role; profile: UserRecord },
  requestedSiteId: unknown,
): string | null {
  const requested = asTrimmedString(requestedSiteId);
  if (requested.length > 0) {
    if (!actorCanAccessSite(actor, requested)) {
      throw new HttpsError('permission-denied', 'No access to requested site.');
    }
    return requested;
  }

  const fallback = asTrimmedString(actor.profile.activeSiteId) || toStringArray(actor.profile.siteIds)[0] || '';
  return fallback.length > 0 ? fallback : null;
}

export const listCohortLaunches = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = resolveActorSiteId(actor, request.data?.siteId);
  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 80;

  const snap = await admin.firestore()
    .collection('cohortLaunches')
    .where('siteId', '==', siteId)
    .orderBy('updatedAt', 'desc')
    .limit(limitValue)
    .get()
    .catch(() => admin.firestore().collection('cohortLaunches').where('siteId', '==', siteId).limit(limitValue).get());

  const launches = snap.docs.map((docSnap) => ({
    id: docSnap.id,
    ...(docSnap.data() as Record<string, unknown>),
  }));

  return { launches };
});

export const upsertCohortLaunch = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = resolveActorSiteId(actor, request.data?.siteId);
  const requestedId = asTrimmedString(request.data?.id);
  const ref = requestedId
    ? admin.firestore().collection('cohortLaunches').doc(requestedId)
    : admin.firestore().collection('cohortLaunches').doc();
  const id = ref.id;
  const payload = {
    siteId,
    cohortName: asTrimmedString(request.data?.cohortName) || `Cohort ${id.slice(-6)}`,
    ageBand: asTrimmedString(request.data?.ageBand) || 'mixed',
    scheduleLabel: asTrimmedString(request.data?.scheduleLabel) || 'TBD',
    programFormat: asTrimmedString(request.data?.programFormat) || 'gold',
    curriculumTerm: asTrimmedString(request.data?.curriculumTerm) || 'Term 1',
    instructorId: asTrimmedString(request.data?.instructorId) || null,
    rosterStatus: normalizeLifecycleStatus(request.data?.rosterStatus, 'draft'),
    parentCommunicationStatus: normalizeLifecycleStatus(request.data?.parentCommunicationStatus, 'pending'),
    welcomePackStatus: normalizeLifecycleStatus(request.data?.welcomePackStatus, 'pending'),
    baselineSurveyStatus: normalizeLifecycleStatus(request.data?.baselineSurveyStatus, 'pending'),
    kickoffStatus: normalizeLifecycleStatus(request.data?.kickoffStatus, 'pending'),
    deviceReadinessStatus: normalizeLifecycleStatus(request.data?.deviceReadinessStatus, 'pending'),
    kitReadinessStatus: normalizeLifecycleStatus(request.data?.kitReadinessStatus, 'not_required'),
    learnerCount: toPositiveInteger(request.data?.learnerCount),
    notes: asTrimmedString(request.data?.notes) || null,
    status: normalizeLifecycleStatus(request.data?.status, requestedId ? 'planning' : 'planning'),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  };
  const writePayload: Record<string, unknown> = { ...payload };
  if (!requestedId) {
    writePayload.createdBy = actor.uid;
    writePayload.createdAt = FieldValue.serverTimestamp();
  }

  await ref.set(writePayload, { merge: true });

  await writeWorkflowAuditLog({
    actor,
    action: requestedId ? 'cohort_launch.updated' : 'cohort_launch.created',
    entityType: 'cohortLaunches',
    entityId: id,
    siteId,
    details: {
      cohortName: payload.cohortName,
      status: payload.status,
      learnerCount: payload.learnerCount,
    },
  });

  return { success: true, id };
});

export const listPartnerLaunches = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['partner', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Partner or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 200
    ? request.data.limit
    : 80;
  let query: FirebaseFirestore.Query = admin.firestore().collection('partnerLaunches').limit(limitValue);

  if (actor.role === 'partner') {
    query = query.where('partnerId', '==', actor.uid);
  }
  if (requestedSiteId.length > 0) {
    query = query.where('siteId', '==', requestedSiteId);
  }

  const snap = await query.get();
  const launches = snap.docs.map((docSnap) => ({
    id: docSnap.id,
    ...(docSnap.data() as Record<string, unknown>),
  }));
  return { launches };
});

export const upsertPartnerLaunch = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['partner', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Partner or HQ role required.');
  }

  const siteId = actor.role === 'hq'
    ? asTrimmedString(request.data?.siteId) || null
    : resolveOptionalActorSiteId(actor, request.data?.siteId);

  const requestedId = asTrimmedString(request.data?.id);
  const ref = requestedId
    ? admin.firestore().collection('partnerLaunches').doc(requestedId)
    : admin.firestore().collection('partnerLaunches').doc();
  const id = ref.id;
  const partnerId = actor.role === 'partner' ? actor.uid : asTrimmedString(request.data?.partnerId);
  if (!partnerId) {
    throw new HttpsError('invalid-argument', 'partnerId is required.');
  }

  const writePayload: Record<string, unknown> = {
    partnerId,
    siteId,
    partnerName: asTrimmedString(request.data?.partnerName) || partnerId,
    region: asTrimmedString(request.data?.region) || 'global',
    locale: asTrimmedString(request.data?.locale) || 'en',
    dueDiligenceStatus: normalizeLifecycleStatus(request.data?.dueDiligenceStatus, 'pending'),
    contractStatus: normalizeLifecycleStatus(request.data?.contractStatus, 'draft'),
    planningWorkshopStatus: normalizeLifecycleStatus(request.data?.planningWorkshopStatus, 'pending'),
    trainerOfTrainersStatus: normalizeLifecycleStatus(request.data?.trainerOfTrainersStatus, 'pending'),
    kpiLoggingStatus: normalizeLifecycleStatus(request.data?.kpiLoggingStatus, 'pending'),
    review90DayStatus: normalizeLifecycleStatus(request.data?.review90DayStatus, 'pending'),
    pilotCohortCount: toPositiveInteger(request.data?.pilotCohortCount),
    notes: asTrimmedString(request.data?.notes) || null,
    status: normalizeLifecycleStatus(request.data?.status, 'planning'),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  };
  if (!requestedId) {
    writePayload.createdAt = FieldValue.serverTimestamp();
    writePayload.createdBy = actor.uid;
  }

  await ref.set(writePayload, { merge: true });

  await writeWorkflowAuditLog({
    actor,
    action: requestedId ? 'partner_launch.updated' : 'partner_launch.created',
    entityType: 'partnerLaunches',
    entityId: id,
    siteId,
    details: {
      partnerId,
      status: normalizeLifecycleStatus(request.data?.status, 'planning'),
    },
  });

  return { success: true, id };
});

export const listKpiPacks = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const requestedSiteId = asTrimmedString(request.data?.siteId);
  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 120
    ? request.data.limit
    : 40;
  let query: FirebaseFirestore.Query = admin.firestore().collection('kpiPacks').limit(limitValue);
  if (requestedSiteId) {
    if (!actorCanAccessSite(actor, requestedSiteId)) {
      throw new HttpsError('permission-denied', 'No access to requested site.');
    }
    query = query.where('siteId', '==', requestedSiteId);
  } else if (actor.role === 'site') {
    const siteId = resolveActorSiteId(actor, request.data?.siteId);
    query = query.where('siteId', '==', siteId);
  }
  const snap = await query.get();
  return {
    packs: snap.docs.map((docSnap) => ({
      id: docSnap.id,
      ...(docSnap.data() as Record<string, unknown>),
    })),
  };
});

export const generateKpiPack = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Site or HQ role required.');
  }

  const siteId = resolveActorSiteId(actor, request.data?.siteId);
  const period = asTrimmedString(request.data?.period) || 'month';
  const now = new Date();
  const start = periodStart(period, now);

  const [
    usersSnap,
    attendanceSnap,
    progressSnap,
    portfolioSnap,
    missionAssignmentsSnap,
    telemetrySnap,
    trainingSnap,
  ] = await Promise.all([
    admin.firestore().collection('users').where('siteIds', 'array-contains', siteId).limit(500).get(),
    admin.firestore().collection('attendanceRecords').where('siteId', '==', siteId).limit(500).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
    admin.firestore().collection('learnerProgress').where('siteId', '==', siteId).limit(500).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
    admin.firestore().collection('portfolioItems').where('siteId', '==', siteId).limit(500).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
    admin.firestore().collection('missionAssignments').where('siteId', '==', siteId).limit(500).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
    admin.firestore().collection('telemetryEvents').where('siteId', '==', siteId).limit(800).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
    admin.firestore().collection('trainingCycles').where('siteId', '==', siteId).limit(200).get().catch(() => ({ docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] })),
  ]);

  const learnerCount = usersSnap.docs.filter((docSnap) => normalizeRoleValue((docSnap.data() as UserRecord).role) === 'learner').length;

  const filteredAttendance = attendanceSnap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const timestamp = toDateValue(data.recordedAt || data.timestamp);
    return !timestamp || timestamp >= start;
  });
  const presentCount = filteredAttendance.filter((docSnap) => asTrimmedString((docSnap.data() as Record<string, unknown>).status) === 'present').length;
  const attendanceRate = filteredAttendance.length > 0 ? presentCount / filteredAttendance.length : 0;

  const filteredPortfolio = portfolioSnap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const timestamp = toDateValue(data.updatedAt || data.createdAt);
    return !timestamp || timestamp >= start;
  });
  const artifactCount = filteredPortfolio.length;

  const filteredAssignments = missionAssignmentsSnap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const timestamp = toDateValue(data.updatedAt || data.createdAt);
    return !timestamp || timestamp >= start;
  });
  const completedAssignments = filteredAssignments.filter((docSnap) => asTrimmedString((docSnap.data() as Record<string, unknown>).status) === 'completed').length;

  let avgFuture = 0;
  let avgLeadership = 0;
  let avgImpact = 0;
  if (progressSnap.docs.length > 0) {
    const futureScores = progressSnap.docs.map((docSnap) => asNumber((docSnap.data() as Record<string, unknown>).futureSkillsProgress) ?? 0);
    const leadershipScores = progressSnap.docs.map((docSnap) => asNumber((docSnap.data() as Record<string, unknown>).leadershipProgress) ?? 0);
    const impactScores = progressSnap.docs.map((docSnap) => asNumber((docSnap.data() as Record<string, unknown>).impactProgress) ?? 0);
    avgFuture = futureScores.reduce((sum, value) => sum + value, 0) / Math.max(futureScores.length, 1);
    avgLeadership = leadershipScores.reduce((sum, value) => sum + value, 0) / Math.max(leadershipScores.length, 1);
    avgImpact = impactScores.reduce((sum, value) => sum + value, 0) / Math.max(impactScores.length, 1);
  }

  const filteredTelemetry = telemetrySnap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const timestamp = toDateValue(data.timestamp || data.createdAt);
    return !timestamp || timestamp >= start;
  });
  const reflectionCount = filteredTelemetry.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const event = asTrimmedString(data.event || data.eventType);
    return event === 'reflection.submitted';
  }).length;
  const aiCollabCount = filteredTelemetry.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const event = asTrimmedString(data.event || data.eventType);
    return ['ai_help_used', 'ai_coach_response', 'voice.message', 'voice.tts'].includes(event);
  }).length;

  const trainingDocs = trainingSnap.docs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    const timestamp = toDateValue(data.updatedAt || data.createdAt || data.startsAt);
    return !timestamp || timestamp >= start;
  });
  const teacherSurveyCount = trainingDocs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    return asTrimmedString(data.audience) === 'educators';
  }).length;
  const parentSurveyCount = trainingDocs.filter((docSnap) => {
    const data = docSnap.data() as Record<string, unknown>;
    return asTrimmedString(data.audience) === 'parents';
  }).length;

  const artifactCompletionRate = learnerCount > 0 ? Math.min(1, artifactCount / learnerCount) : 0;
  const reflectionQuality = artifactCount > 0 ? Math.min(1, reflectionCount / artifactCount) : 0;
  const aiCollaborationQuality = completedAssignments > 0 ? Math.min(1, aiCollabCount / completedAssignments) : Math.min(1, aiCollabCount / Math.max(artifactCount, 1));
  const capabilityGrowth = (avgFuture + avgLeadership + avgImpact) / 3;
  const tripleHelixCoverage = [avgFuture, avgLeadership, avgImpact].filter((value) => value > 0.2).length / 3;
  const fidelityScore = (attendanceRate * 0.25) + (artifactCompletionRate * 0.2) + (reflectionQuality * 0.15) + (capabilityGrowth * 0.2) + (tripleHelixCoverage * 0.1) + (aiCollaborationQuality * 0.1);
  const portfolioQualityGrade = fidelityScore >= 0.8 ? 'A' : fidelityScore >= 0.65 ? 'B' : fidelityScore >= 0.5 ? 'C' : 'D';

  const ref = admin.firestore().collection('kpiPacks').doc();
  await ref.set({
    siteId,
    period,
    title: `KPI Pack ${siteId} ${period}`,
    periodStart: start,
    periodEnd: now,
    learnerCount,
    attendanceRate,
    artifactCount,
    artifactCompletionRate,
    missionCompletionCount: completedAssignments,
    reflectionCount,
    reflectionQuality,
    aiCollaborationQuality,
    capabilityGrowth,
    tripleHelixCoverage,
    pillarCoverage: {
      futureSkills: avgFuture,
      leadership: avgLeadership,
      impact: avgImpact,
    },
    parentSurveyCount,
    teacherSurveyCount,
    fidelityScore,
    portfolioQualityGrade,
    recommendation: fidelityScore >= 0.75 ? 'scale' : fidelityScore >= 0.55 ? 'stabilize' : 'intervene',
    generatedBy: actor.uid,
    status: 'generated',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeWorkflowAuditLog({
    actor,
    action: 'kpi_pack.generated',
    entityType: 'kpiPacks',
    entityId: ref.id,
    siteId,
    details: {
      period,
      fidelityScore,
      portfolioQualityGrade,
    },
  });

  return { success: true, id: ref.id };
});

export const listRedTeamReviews = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 120
    ? request.data.limit
    : 60;
  const snap = await admin.firestore().collection('redTeamReviews').limit(limitValue).get();
  return {
    reviews: snap.docs.map((docSnap) => ({
      id: docSnap.id,
      ...(docSnap.data() as Record<string, unknown>),
    })),
  };
});

export const upsertRedTeamReview = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (actor.role !== 'hq') {
    throw new HttpsError('permission-denied', 'HQ role required.');
  }

  const requestedId = asTrimmedString(request.data?.id);
  const ref = requestedId
    ? admin.firestore().collection('redTeamReviews').doc(requestedId)
    : admin.firestore().collection('redTeamReviews').doc();
  const id = ref.id;
  const kpiPackId = asTrimmedString(request.data?.kpiPackId);
  let siteId = asTrimmedString(request.data?.siteId);
  let fidelityScore = asNumber(request.data?.fidelityScore);
  let portfolioQualityGrade = asTrimmedString(request.data?.portfolioQualityGrade);

  if (kpiPackId) {
    const kpiDoc = await admin.firestore().collection('kpiPacks').doc(kpiPackId).get();
    if (kpiDoc.exists) {
      const data = kpiDoc.data() as Record<string, unknown>;
      if (!siteId) siteId = asTrimmedString(data.siteId);
      if (fidelityScore === null) fidelityScore = asNumber(data.fidelityScore);
      if (!portfolioQualityGrade) portfolioQualityGrade = asTrimmedString(data.portfolioQualityGrade);
    }
  }

  const writePayload: Record<string, unknown> = {
    siteId: siteId || null,
    kpiPackId: kpiPackId || null,
    period: asTrimmedString(request.data?.period) || 'term',
    title: asTrimmedString(request.data?.title) || `Red Team Review ${id.slice(-6)}`,
    ...(fidelityScore !== null ? { fidelityScore } : {}),
    portfolioQualityGrade: portfolioQualityGrade || 'C',
    decision: normalizeLifecycleStatus(request.data?.decision, 'continue'),
    partnerStatus: normalizeLifecycleStatus(request.data?.partnerStatus, 'active'),
    recommendations: asTrimmedString(request.data?.recommendations) || '',
    nextAction: asTrimmedString(request.data?.nextAction) || '',
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  };
  if (!requestedId) {
    writePayload.createdAt = FieldValue.serverTimestamp();
    writePayload.createdBy = actor.uid;
  }

  await ref.set(writePayload, { merge: true });

  await writeWorkflowAuditLog({
    actor,
    action: requestedId ? 'red_team_review.updated' : 'red_team_review.created',
    entityType: 'redTeamReviews',
    entityId: id,
    siteId: siteId || null,
    details: {
      kpiPackId,
      decision: normalizeLifecycleStatus(request.data?.decision, 'continue'),
    },
  });

  return { success: true, id };
});

export const listTrainingCycles = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const limitValue = typeof request.data?.limit === 'number' && request.data.limit > 0 && request.data.limit <= 120
    ? request.data.limit
    : 60;
  const requestedSiteId = asTrimmedString(request.data?.siteId);
  let query: FirebaseFirestore.Query = admin.firestore().collection('trainingCycles').limit(limitValue);
  if (requestedSiteId) {
    if (!actorCanAccessSite(actor, requestedSiteId)) {
      throw new HttpsError('permission-denied', 'No access to requested site.');
    }
    query = query.where('siteId', '==', requestedSiteId);
  } else if (actor.role !== 'hq') {
    query = query.where('siteId', '==', resolveActorSiteId(actor, request.data?.siteId));
  }

  const snap = await query.get();
  return {
    cycles: snap.docs.map((docSnap) => ({
      id: docSnap.id,
      ...(docSnap.data() as Record<string, unknown>),
    })),
  };
});

export const upsertTrainingCycle = onCall(async (request: CallableRequest) => {
  const actor = await getActorProfile(request.auth?.uid);
  if (!['educator', 'site', 'hq'].includes(actor.role)) {
    throw new HttpsError('permission-denied', 'Educator, Site, or HQ role required.');
  }

  const siteId = actor.role === 'hq'
    ? asTrimmedString(request.data?.siteId) || null
    : resolveActorSiteId(actor, request.data?.siteId);
  const requestedId = asTrimmedString(request.data?.id);
  const ref = requestedId
    ? admin.firestore().collection('trainingCycles').doc(requestedId)
    : admin.firestore().collection('trainingCycles').doc();
  const id = ref.id;
  const startsAt = toDateValue(request.data?.startsAt);

  const writePayload: Record<string, unknown> = {
    siteId,
    title: asTrimmedString(request.data?.title) || `Training Cycle ${id.slice(-6)}`,
    trainingType: asTrimmedString(request.data?.trainingType) || 'term_launch',
    audience: asTrimmedString(request.data?.audience) || 'educators',
    termLabel: asTrimmedString(request.data?.termLabel) || 'Current term',
    status: normalizeLifecycleStatus(request.data?.status, 'scheduled'),
    startsAt: startsAt || null,
    completionCount: toPositiveInteger(request.data?.completionCount),
    notes: asTrimmedString(request.data?.notes) || null,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  };
  if (!requestedId) {
    writePayload.createdAt = FieldValue.serverTimestamp();
    writePayload.createdBy = actor.uid;
  }

  await ref.set(writePayload, { merge: true });

  await writeWorkflowAuditLog({
    actor,
    action: requestedId ? 'training_cycle.updated' : 'training_cycle.created',
    entityType: 'trainingCycles',
    entityId: id,
    siteId,
    details: {
      trainingType: asTrimmedString(request.data?.trainingType) || 'term_launch',
      audience: asTrimmedString(request.data?.audience) || 'educators',
    },
  });

  return { success: true, id };
});
