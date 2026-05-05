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

export type ReportShareRequestRevocationReason =
  | 'learner_revoked_report_share'
  | 'guardian_revoked_report_share'
  | 'educator_revoked_report_share'
  | 'site_revoked_report_share'
  | 'hq_revoked_report_share';

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
  explicitConsentId?: string;
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
    ...(params.explicitConsentId ? { explicitConsentId: params.explicitConsentId } : {}),
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

export function expectedReportShareRevocationReason(
  actorRole: ReportShareRequestRole
): ReportShareRequestRevocationReason | null {
  if (actorRole === 'learner') return 'learner_revoked_report_share';
  if (actorRole === 'parent') return 'guardian_revoked_report_share';
  if (actorRole === 'educator') return 'educator_revoked_report_share';
  if (actorRole === 'site' || actorRole === 'siteLead') return 'site_revoked_report_share';
  if (actorRole === 'hq' || actorRole === 'admin') return 'hq_revoked_report_share';
  return null;
}

export function isReportShareRevocationReasonAllowedForActor(params: {
  reason: string;
  actorRole: ReportShareRequestRole;
}): boolean {
  return params.reason === expectedReportShareRevocationReason(params.actorRole);
}

function readOptionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : null;
}

function readObject(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function buildReportShareRequestRevocationAuditDetails(params: {
  data: Record<string, unknown>;
  reason: ReportShareRequestRevocationReason;
}): Record<string, unknown> {
  const sharePolicy = readObject(params.data.sharePolicy);
  const provenance = readObject(params.data.provenance);
  return {
    reason: params.reason,
    previousStatus: readOptionalString(params.data.status),
    createdBy: readOptionalString(params.data.createdBy),
    createdByRole: readOptionalString(params.data.createdByRole),
    audience: readOptionalString(params.data.audience),
    visibility: readOptionalString(params.data.visibility),
    reportAction: readOptionalString(params.data.reportAction),
    reportDelivery: readOptionalString(params.data.reportDelivery),
    deliveryAuditId: readOptionalString(params.data.deliveryAuditId),
    source: readOptionalString(params.data.source),
    surface: readOptionalString(params.data.surface),
    cta: readOptionalString(params.data.cta),
    fileName: readOptionalString(params.data.fileName),
    sharePolicy: sharePolicy
      ? {
          requiresEvidenceProvenance: sharePolicy.requiresEvidenceProvenance === true,
          requiresGuardianContext: sharePolicy.requiresGuardianContext === true,
          allowsExternalSharing: sharePolicy.allowsExternalSharing === true,
          includesLearnerIdentifiers: sharePolicy.includesLearnerIdentifiers === true,
        }
      : null,
    provenance: provenance
      ? {
          meetsProvenanceContract: provenance.meetsProvenanceContract === true,
          meetsDeliveryContract: provenance.meetsDeliveryContract === true,
          sharePolicyDeclared: provenance.sharePolicyDeclared === true,
        }
      : null,
  };
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
