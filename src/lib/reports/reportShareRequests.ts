import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type { ReportDeliveryAuditAction, ReportDeliveryAuditStatus } from './reportDeliveryAudit';
import type { ReportProvenanceMetadata } from './shareExport';

interface CreateReportShareRequestParams {
  siteId?: string | null;
  learnerId?: string | null;
  reportAction: ReportDeliveryAuditAction;
  reportDelivery?: ReportDeliveryAuditStatus;
  metadata?: ReportProvenanceMetadata | null;
  module: string;
  surface: string;
  cta: string;
  fileName?: string;
  expiresInDays?: number;
}

interface RevokeReportShareRequestParams {
  shareRequestId?: string | null;
  reason?: string;
}

const completedDeliveryStatuses = new Set<ReportDeliveryAuditStatus>([
  'shared',
  'copied',
  'downloaded',
]);

export function shouldCreateReportShareRequest(
  reportDelivery: ReportDeliveryAuditStatus,
  metadata?: ReportProvenanceMetadata | null,
): boolean {
  return completedDeliveryStatuses.has(reportDelivery) && metadata?.report_meets_delivery_contract === true;
}

export async function createReportShareRequest({
  siteId,
  learnerId,
  reportAction,
  reportDelivery,
  metadata,
  module,
  surface,
  cta,
  fileName,
  expiresInDays,
}: CreateReportShareRequestParams): Promise<string | null> {
  if (!siteId || !learnerId || !metadata || !reportDelivery) return null;
  if (!shouldCreateReportShareRequest(reportDelivery, metadata)) return null;

  try {
    const callable = httpsCallable(functions, 'createReportShareRequest');
    const response = await callable({
      siteId,
      learnerId,
      reportAction,
      reportDelivery,
      module,
      source: module,
      surface,
      cta,
      fileName,
      expiresInDays,
      audience: metadata.report_share_audience,
      visibility: metadata.report_share_visibility,
      metadata,
    });
    const data = response.data as { id?: unknown } | undefined;
    return typeof data?.id === 'string' ? data.id : null;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to create report share request.', error);
    }
    return null;
  }
}

export async function revokeReportShareRequest({
  shareRequestId,
  reason,
}: RevokeReportShareRequestParams): Promise<boolean> {
  if (!shareRequestId) return false;

  try {
    const callable = httpsCallable(functions, 'revokeReportShareRequest');
    await callable({ shareRequestId, reason });
    return true;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to revoke report share request.', error);
    }
    return false;
  }
}