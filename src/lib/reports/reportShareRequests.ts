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
  shareRequestActorPolicyAligned?: boolean;
}

interface RevokeReportShareRequestParams {
  shareRequestId?: string | null;
  reason?: string;
}

export type ReportShareRequestSkipReason =
  | 'incomplete_delivery'
  | 'missing_metadata'
  | 'failed_delivery_contract'
  | 'missing_share_policy'
  | 'not_family_safe'
  | 'external_sharing_enabled'
  | 'unsupported_audience'
  | 'unsupported_visibility'
  | 'actor_policy_misaligned';

export type ReportShareRequestLifecycleOutcome = 'created' | 'skipped' | 'expected_but_missing';

const completedDeliveryStatuses = new Set<ReportDeliveryAuditStatus>([
  'shared',
  'copied',
  'downloaded',
]);

const supportedClientShareAudiences = new Set<ReportProvenanceMetadata['report_share_audience']>([
  'learner',
  'guardian',
]);

const supportedClientShareVisibilities = new Set<
  ReportProvenanceMetadata['report_share_visibility']
>(['private', 'family']);

export function shouldCreateReportShareRequest(
  reportDelivery: ReportDeliveryAuditStatus,
  metadata?: ReportProvenanceMetadata | null,
  shareRequestActorPolicyAligned = true
): boolean {
  return (
    resolveReportShareRequestSkipReason(
      reportDelivery,
      metadata,
      shareRequestActorPolicyAligned
    ) === null
  );
}

export function resolveReportShareRequestSkipReason(
  reportDelivery: ReportDeliveryAuditStatus,
  metadata?: ReportProvenanceMetadata | null,
  shareRequestActorPolicyAligned = true
): ReportShareRequestSkipReason | null {
  if (!completedDeliveryStatuses.has(reportDelivery)) return 'incomplete_delivery';
  if (!metadata) return 'missing_metadata';
  if (!shareRequestActorPolicyAligned) return 'actor_policy_misaligned';
  if (metadata.report_meets_delivery_contract !== true) return 'failed_delivery_contract';
  if (metadata.report_share_policy_declared !== true) return 'missing_share_policy';
  if (metadata.report_share_family_safe !== true) return 'not_family_safe';
  if (metadata.report_share_allows_external_sharing === true) return 'external_sharing_enabled';
  if (!supportedClientShareAudiences.has(metadata.report_share_audience)) {
    return 'unsupported_audience';
  }
  if (!supportedClientShareVisibilities.has(metadata.report_share_visibility)) {
    return 'unsupported_visibility';
  }
  return null;
}

export function reportShareRequestLifecycleMetadata(
  reportDelivery: ReportDeliveryAuditStatus,
  metadata?: ReportProvenanceMetadata | null,
  shareRequestId?: string | null,
  shareRequestActorPolicyAligned = true
): Record<string, unknown> {
  const skippedReason = resolveReportShareRequestSkipReason(
    reportDelivery,
    metadata,
    shareRequestActorPolicyAligned
  );
  if (skippedReason) {
    return {
      report_share_request_lifecycle_expected: false,
      report_share_request_lifecycle_outcome:
        'skipped' satisfies ReportShareRequestLifecycleOutcome,
      report_share_request_created: false,
      report_share_request_skipped_reason: skippedReason,
    };
  }
  return {
    report_share_request_lifecycle_expected: true,
    report_share_request_lifecycle_outcome: (shareRequestId
      ? 'created'
      : 'expected_but_missing') satisfies ReportShareRequestLifecycleOutcome,
    report_share_request_created: Boolean(shareRequestId),
    report_share_request_skipped_reason: null,
  };
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
  shareRequestActorPolicyAligned,
}: CreateReportShareRequestParams): Promise<string | null> {
  if (!siteId || !learnerId || !metadata || !reportDelivery) return null;
  if (!shouldCreateReportShareRequest(reportDelivery, metadata, shareRequestActorPolicyAligned)) {
    return null;
  }

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
