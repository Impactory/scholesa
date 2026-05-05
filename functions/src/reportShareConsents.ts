import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type {
  ReportShareRequestAudience,
  ReportShareRequestRole,
  ReportShareRequestVisibility,
} from './reportShareRequests';

export type ReportShareConsentStatus = 'pending' | 'granted' | 'revoked' | 'expired';
export type ReportShareConsentScope =
  | 'family'
  | 'staff'
  | 'site'
  | 'partner'
  | 'external'
  | 'public';

export interface ReportShareConsentWriteParams {
  requesterId: string;
  requesterRole: ReportShareRequestRole;
  learnerId: string;
  siteId: string;
  scope: ReportShareConsentScope;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
  purpose: string;
  evidenceSummary: string;
  expiresAt: Date;
  linkedReportShareRequestIds?: string[];
  collectionName?: string;
}

const CONSENT_REQUESTER_ROLES = new Set<ReportShareRequestRole>([
  'educator',
  'site',
  'siteLead',
  'hq',
  'admin',
]);

const CONSENT_SCOPES_REQUIRING_EXPLICIT_GRANT = new Set<ReportShareConsentScope>([
  'staff',
  'site',
  'partner',
  'external',
  'public',
]);

export function isReportShareConsentScope(value: unknown): value is ReportShareConsentScope {
  return (
    value === 'family' ||
    value === 'staff' ||
    value === 'site' ||
    value === 'partner' ||
    value === 'external' ||
    value === 'public'
  );
}

export function canRequestReportShareConsentForPolicy(params: {
  actorRole: ReportShareRequestRole;
  scope: ReportShareConsentScope;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
}): boolean {
  if (!CONSENT_REQUESTER_ROLES.has(params.actorRole)) return false;
  if (!CONSENT_SCOPES_REQUIRING_EXPLICIT_GRANT.has(params.scope)) return false;
  if (params.scope === 'partner') return params.audience === 'partner';
  if (params.scope === 'external') return params.audience === 'external';
  if (params.scope === 'public') return params.visibility === 'public';
  if (params.scope === 'site') return params.visibility === 'site' || params.audience === 'site';
  return (
    params.visibility === 'staff' || params.audience === 'educator' || params.audience === 'hq'
  );
}

export function canDecideReportShareConsent(params: {
  actorId: string;
  actorRole: ReportShareRequestRole;
  learnerId: string;
  linkedLearnerIds?: string[];
}): boolean {
  if (params.actorRole === 'learner') return params.actorId === params.learnerId;
  if (params.actorRole === 'parent')
    return params.linkedLearnerIds?.includes(params.learnerId) === true;
  return false;
}

export function canRevokeReportShareConsent(params: {
  actorId: string;
  actorRole: ReportShareRequestRole;
  learnerId: string;
  requesterId?: string;
  approverId?: string;
  linkedLearnerIds?: string[];
}): boolean {
  if (canDecideReportShareConsent(params)) return true;
  if (params.actorId === params.requesterId) return true;
  if (params.actorId === params.approverId) return true;
  return ['site', 'siteLead', 'hq', 'admin'].includes(params.actorRole);
}

function readExpiryMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (
    value &&
    typeof value === 'object' &&
    'toMillis' in value &&
    typeof value.toMillis === 'function'
  ) {
    const millis = value.toMillis();
    return typeof millis === 'number' && Number.isFinite(millis) ? millis : null;
  }
  return null;
}

export function isPendingUnexpiredReportShareConsentRecord(
  data: Record<string, unknown>,
  now = new Date()
): boolean {
  if (data.status !== 'pending') return false;
  const expiresAtMillis = readExpiryMillis(data.expiresAt);
  if (expiresAtMillis === null) return false;
  return expiresAtMillis > now.getTime();
}

export function isGrantedUnexpiredReportShareConsentRecord(
  data: Record<string, unknown>,
  now = new Date()
): boolean {
  if (data.status !== 'granted') return false;
  const expiresAtMillis = readExpiryMillis(data.expiresAt);
  if (expiresAtMillis === null) return false;
  return expiresAtMillis > now.getTime();
}

export function doesGrantedReportShareConsentMatchPolicy(params: {
  data: Record<string, unknown>;
  learnerId: string;
  siteId: string;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
  now?: Date;
}): boolean {
  if (!isGrantedUnexpiredReportShareConsentRecord(params.data, params.now)) return false;
  return (
    params.data.learnerId === params.learnerId &&
    params.data.siteId === params.siteId &&
    params.data.audience === params.audience &&
    params.data.visibility === params.visibility
  );
}

export function buildReportShareConsentRecord(id: string, params: ReportShareConsentWriteParams) {
  return {
    id,
    siteId: params.siteId,
    learnerId: params.learnerId,
    requesterId: params.requesterId,
    requesterRole: params.requesterRole,
    status: 'pending' as ReportShareConsentStatus,
    scope: params.scope,
    audience: params.audience,
    visibility: params.visibility,
    purpose: params.purpose,
    evidenceSummary: params.evidenceSummary,
    linkedReportShareRequestIds: params.linkedReportShareRequestIds ?? [],
    requestedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(params.expiresAt),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export async function persistReportShareConsentRecord(params: ReportShareConsentWriteParams) {
  const collectionName = params.collectionName ?? 'reportShareConsents';
  const consentRef = admin.firestore().collection(collectionName).doc();
  await consentRef.set(buildReportShareConsentRecord(consentRef.id, params));
  return consentRef.id;
}

export async function grantReportShareConsentRecord(params: {
  consentId: string;
  approverId: string;
  approverRole: ReportShareRequestRole;
  collectionName?: string;
}) {
  const collectionName = params.collectionName ?? 'reportShareConsents';
  await admin.firestore().collection(collectionName).doc(params.consentId).update({
    status: 'granted',
    approverId: params.approverId,
    approverRole: params.approverRole,
    decidedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export async function revokeReportShareConsentRecord(params: {
  consentId: string;
  actorId: string;
  collectionName?: string;
}) {
  const collectionName = params.collectionName ?? 'reportShareConsents';
  await admin.firestore().collection(collectionName).doc(params.consentId).update({
    status: 'revoked',
    revokedAt: FieldValue.serverTimestamp(),
    revokedBy: params.actorId,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export async function linkReportShareConsentToRequestRecord(params: {
  consentId: string;
  shareRequestId: string;
  collectionName?: string;
}) {
  const collectionName = params.collectionName ?? 'reportShareConsents';
  await admin.firestore().collection(collectionName).doc(params.consentId).update({
    linkedReportShareRequestIds: FieldValue.arrayUnion(params.shareRequestId),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
