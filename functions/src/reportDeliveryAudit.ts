import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

export type ReportDeliveryAuditRole =
  | 'learner'
  | 'educator'
  | 'parent'
  | 'site'
  | 'siteLead'
  | 'partner'
  | 'hq'
  | 'admin';

export type ReportDeliveryAuditAction = 'share' | 'export_text' | 'export_html' | 'export_pdf';

export type ReportDeliveryAuditStatus =
  | 'shared'
  | 'copied'
  | 'downloaded'
  | 'unavailable'
  | 'aborted'
  | 'contract-failed';

export interface ReportDeliveryAuditWriteParams {
  actorId: string;
  actorRole: ReportDeliveryAuditRole;
  learnerId: string;
  reportAction: ReportDeliveryAuditAction;
  reportDelivery: ReportDeliveryAuditStatus;
  siteId?: string;
  reportBlockReason?: string;
  details?: Record<string, unknown>;
  collectionName?: string;
}

const ALLOWED_REPORT_SHARE_LIFECYCLE_SKIPPED_REASONS = new Set([
  'incomplete_delivery',
  'missing_metadata',
  'failed_delivery_contract',
  'missing_share_policy',
  'not_family_safe',
  'external_sharing_enabled',
  'unsupported_audience',
  'unsupported_visibility',
  'actor_policy_misaligned',
]);

export function validateReportShareLifecycleMetadata(params: {
  metadata: Record<string, unknown>;
  shareRequestId?: string;
}) {
  const { metadata, shareRequestId } = params;
  const expected = metadata.report_share_request_lifecycle_expected;
  const outcome = metadata.report_share_request_lifecycle_outcome;
  const created = metadata.report_share_request_created;
  const skippedReason = metadata.report_share_request_skipped_reason;
  const hasLifecycleMetadata =
    expected !== undefined ||
    outcome !== undefined ||
    created !== undefined ||
    skippedReason !== undefined;
  if (!hasLifecycleMetadata) return;

  if (outcome !== 'created' && outcome !== 'skipped' && outcome !== 'expected_but_missing') {
    throw new HttpsError('failed-precondition', 'Invalid report share lifecycle outcome.');
  }

  if (shareRequestId) {
    if (expected !== true || outcome !== 'created' || created !== true || skippedReason !== null) {
      throw new HttpsError(
        'failed-precondition',
        'Report share lifecycle metadata conflicts with linked share request.'
      );
    }
    return;
  }

  if (outcome === 'created' || created === true) {
    throw new HttpsError(
      'failed-precondition',
      'Report share lifecycle metadata requires a linked share request.'
    );
  }
  if (outcome === 'skipped' && (expected !== false || typeof skippedReason !== 'string')) {
    throw new HttpsError(
      'failed-precondition',
      'Skipped report share lifecycle requires a reason.'
    );
  }
  if (
    outcome === 'skipped' &&
    (typeof skippedReason !== 'string' ||
      !ALLOWED_REPORT_SHARE_LIFECYCLE_SKIPPED_REASONS.has(skippedReason))
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Skipped report share lifecycle reason is unsupported.'
    );
  }
  if (outcome === 'expected_but_missing' && (expected !== true || created !== false)) {
    throw new HttpsError(
      'failed-precondition',
      'Missing report share lifecycle requires expected-but-missing metadata.'
    );
  }
}

export function buildReportDeliveryAuditRecord(params: ReportDeliveryAuditWriteParams) {
  const details = {
    ...(params.details ?? {}),
    learnerId: params.learnerId,
    reportAction: params.reportAction,
    reportDelivery: params.reportDelivery,
    ...(params.reportBlockReason ? { reportBlockReason: params.reportBlockReason } : {}),
  };

  return {
    actorId: params.actorId,
    actorRole: params.actorRole,
    userId: params.actorId,
    action:
      params.reportDelivery === 'contract-failed'
        ? 'report.delivery_blocked'
        : 'report.delivery_recorded',
    entityType: 'learnerReport',
    entityId: params.learnerId,
    targetType: 'learner',
    targetId: params.learnerId,
    siteId: params.siteId,
    details,
    metadata: details,
    createdAt: FieldValue.serverTimestamp(),
  };
}

export async function persistReportDeliveryAuditRecord(params: ReportDeliveryAuditWriteParams) {
  const collectionName = params.collectionName ?? 'auditLogs';
  const auditRef = admin.firestore().collection(collectionName).doc();
  await auditRef.set(buildReportDeliveryAuditRecord(params));
  return auditRef.id;
}
