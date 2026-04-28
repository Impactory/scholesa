import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

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

export async function persistReportDeliveryAuditRecord(
  params: ReportDeliveryAuditWriteParams,
) {
  const collectionName = params.collectionName ?? 'auditLogs';
  const auditRef = admin.firestore().collection(collectionName).doc();
  await auditRef.set(buildReportDeliveryAuditRecord(params));
  return auditRef.id;
}
