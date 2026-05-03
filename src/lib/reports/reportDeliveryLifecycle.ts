import {
  recordReportDeliveryAudit,
  type ReportDeliveryAuditAction,
  type ReportDeliveryAuditStatus,
} from './reportDeliveryAudit';
import {
  createReportShareRequest,
  reportShareRequestLifecycleMetadata,
} from './reportShareRequests';
import type { ReportProvenanceMetadata } from './shareExport';

interface ReportDeliveryLifecycleParams {
  siteId?: string | null;
  learnerId?: string | null;
  reportAction: ReportDeliveryAuditAction;
  reportDelivery: ReportDeliveryAuditStatus;
  metadata?: ReportProvenanceMetadata | null;
  module: string;
  surface: string;
  cta: string;
  fileName?: string;
  shareRequestActorPolicyAligned?: boolean;
}

export async function recordReportDeliveryLifecycle(
  params: ReportDeliveryLifecycleParams
): Promise<{ shareRequestId: string | null; deliveryAuditId: string | null }> {
  const shareRequestId = await createReportShareRequest(params);
  const deliveryAuditId = await recordReportDeliveryAudit({
    ...params,
    metadata: params.metadata
      ? {
          ...params.metadata,
          ...reportShareRequestLifecycleMetadata(
            params.reportDelivery,
            params.metadata,
            shareRequestId,
            params.shareRequestActorPolicyAligned
          ),
        }
      : params.metadata,
    shareRequestId,
  });
  return { shareRequestId, deliveryAuditId };
}
