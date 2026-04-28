import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type {
  BrowserShareStatus,
  ReportDownloadStatus,
  ReportProvenanceMetadata,
} from './shareExport';

export type ReportDeliveryAuditAction = 'share' | 'export_text' | 'export_html' | 'export_pdf';
export type ReportDeliveryAuditStatus = BrowserShareStatus | ReportDownloadStatus;

interface ReportDeliveryAuditParams {
  siteId?: string | null;
  learnerId?: string | null;
  reportAction: ReportDeliveryAuditAction;
  reportDelivery: ReportDeliveryAuditStatus;
  metadata?: ReportProvenanceMetadata | null;
  module: string;
  surface: string;
  cta: string;
  fileName?: string;
  shareRequestId?: string | null;
}

export function resolveReportDeliveryBlockReason(
  metadata?: ReportProvenanceMetadata | null,
): string | undefined {
  if (!metadata) return undefined;
  if (metadata.report_missing_delivery_contract_fields.includes('sharePolicy')) {
    return 'missing_share_policy';
  }
  if (metadata.report_missing_provenance_signals.length > 0) {
    return 'missing_provenance';
  }
  return undefined;
}

export async function recordReportDeliveryAudit({
  siteId,
  learnerId,
  reportAction,
  reportDelivery,
  metadata,
  module,
  surface,
  cta,
  fileName,
  shareRequestId,
}: ReportDeliveryAuditParams): Promise<string | null> {
  if (!siteId || !learnerId || !metadata) return null;

  try {
    const callable = httpsCallable(functions, 'recordReportDeliveryAudit');
    const response = await callable({
      siteId,
      learnerId,
      reportAction,
      reportDelivery,
      reportBlockReason:
        reportDelivery === 'contract-failed' ? resolveReportDeliveryBlockReason(metadata) : undefined,
      module,
      surface,
      cta,
      fileName,
      shareRequestId: shareRequestId ?? undefined,
      metadata,
    });
    const data = response.data as { id?: unknown } | undefined;
    return typeof data?.id === 'string' ? data.id : null;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to persist report delivery audit.', error);
    }
    return null;
  }
}
