import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

export type ReportShareRequestRole =
  | 'learner'
  | 'educator'
  | 'parent'
  | 'site'
  | 'siteLead'
  | 'partner'
  | 'hq'
  | 'admin';

export type ReportShareRequestAction = 'share' | 'export_text' | 'export_html' | 'export_pdf';
export type ReportShareRequestDelivery =
  | 'shared'
  | 'copied'
  | 'downloaded'
  | 'unavailable'
  | 'aborted'
  | 'contract-failed';
export type ReportShareRequestAudience =
  | 'learner'
  | 'guardian'
  | 'educator'
  | 'site'
  | 'hq'
  | 'partner'
  | 'external';
export type ReportShareRequestVisibility =
  | 'private'
  | 'family'
  | 'staff'
  | 'site'
  | 'external'
  | 'public';

export interface ReportShareRequestWriteParams {
  actorId: string;
  actorRole: ReportShareRequestRole;
  learnerId: string;
  siteId: string;
  reportAction: ReportShareRequestAction;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
  expiresAt: Date;
  reportDelivery?: ReportShareRequestDelivery;
  source?: string;
  surface?: string;
  cta?: string;
  fileName?: string;
  sharePolicy: {
    requiresEvidenceProvenance: boolean;
    requiresGuardianContext: boolean;
    allowsExternalSharing: boolean;
    includesLearnerIdentifiers: boolean;
  };
  provenance: {
    expectedSignals: string[];
    missingSignals: string[];
    meetsProvenanceContract: boolean;
    meetsDeliveryContract: boolean;
    sharePolicyDeclared: boolean;
  };
  collectionName?: string;
}

export function buildReportShareRequestRecord(id: string, params: ReportShareRequestWriteParams) {
  return {
    id,
    siteId: params.siteId,
    learnerId: params.learnerId,
    createdBy: params.actorId,
    createdByRole: params.actorRole,
    status: 'active',
    reportAction: params.reportAction,
    ...(params.reportDelivery ? { reportDelivery: params.reportDelivery } : {}),
    audience: params.audience,
    visibility: params.visibility,
    ...(params.source ? { source: params.source } : {}),
    ...(params.surface ? { surface: params.surface } : {}),
    ...(params.cta ? { cta: params.cta } : {}),
    ...(params.fileName ? { fileName: params.fileName } : {}),
    sharePolicy: params.sharePolicy,
    provenance: params.provenance,
    expiresAt: Timestamp.fromDate(params.expiresAt),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
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

export function isActiveUnexpiredReportShareRequestRecord(
  data: Record<string, unknown>,
  now = new Date()
): boolean {
  if (data.status !== 'active') return false;
  const expiresAtMillis = readExpiryMillis(data.expiresAt);
  if (expiresAtMillis === null) return false;
  return expiresAtMillis > now.getTime();
}

export function canCreateReportShareRequestForPolicy(params: {
  actorId: string;
  actorRole: ReportShareRequestRole;
  learnerId: string;
  audience: ReportShareRequestAudience;
  visibility: ReportShareRequestVisibility;
}): boolean {
  if (params.actorRole === 'learner') {
    return (
      params.actorId === params.learnerId &&
      params.audience === 'learner' &&
      params.visibility === 'private'
    );
  }
  if (params.actorRole === 'parent') {
    return params.audience === 'guardian' && params.visibility === 'family';
  }
  return false;
}

export function doesReportShareRequestMatchDeliveryAudit(params: {
  data: Record<string, unknown>;
  actorId: string;
  learnerId: string;
  siteId: string;
  reportAction: ReportShareRequestAction;
  reportDelivery: ReportShareRequestDelivery;
}): boolean {
  return (
    params.data.createdBy === params.actorId &&
    params.data.learnerId === params.learnerId &&
    params.data.siteId === params.siteId &&
    params.data.reportAction === params.reportAction &&
    params.data.reportDelivery === params.reportDelivery
  );
}

export async function persistReportShareRequestRecord(params: ReportShareRequestWriteParams) {
  const collectionName = params.collectionName ?? 'reportShareRequests';
  const shareRef = admin.firestore().collection(collectionName).doc();
  await shareRef.set(buildReportShareRequestRecord(shareRef.id, params));
  return shareRef.id;
}

export async function revokeReportShareRequestRecord(params: {
  shareRequestId: string;
  actorId: string;
  reason?: string;
  collectionName?: string;
}) {
  const collectionName = params.collectionName ?? 'reportShareRequests';
  await admin
    .firestore()
    .collection(collectionName)
    .doc(params.shareRequestId)
    .update({
      status: 'revoked',
      revokedAt: FieldValue.serverTimestamp(),
      revokedBy: params.actorId,
      ...(params.reason ? { revocationReason: params.reason } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
}

export async function linkReportShareRequestDeliveryAuditRecord(params: {
  shareRequestId: string;
  deliveryAuditId: string;
  reportDelivery: ReportShareRequestDelivery;
  collectionName?: string;
}) {
  const collectionName = params.collectionName ?? 'reportShareRequests';
  await admin.firestore().collection(collectionName).doc(params.shareRequestId).update({
    deliveryAuditId: params.deliveryAuditId,
    reportDelivery: params.reportDelivery,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
