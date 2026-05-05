import { httpsCallable } from 'firebase/functions';
import { functions } from '@/src/firebase/client-init';
import type { ReportDeliveryAuditAction, ReportDeliveryAuditStatus } from './reportDeliveryAudit';
import type {
  ReportProvenanceMetadata,
  ReportShareAudience,
  ReportShareVisibility,
} from './shareExport';

export type ReportShareConsentScope =
  | 'family'
  | 'staff'
  | 'site'
  | 'partner'
  | 'external'
  | 'public';

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

interface RequestReportShareConsentParams {
  siteId?: string | null;
  learnerId?: string | null;
  scope: ReportShareConsentScope;
  audience: ReportShareAudience;
  visibility: ReportShareVisibility;
  purpose: string;
  evidenceSummary: string;
  expiresInDays?: number;
}

interface CreateExplicitConsentReportShareRequestParams extends CreateReportShareRequestParams {
  explicitConsentId?: string | null;
  audience: ReportShareAudience;
  visibility: ReportShareVisibility;
}

interface RevokeReportShareRequestParams {
  shareRequestId?: string | null;
  reason?: string;
}

interface ReportShareConsentDecisionParams {
  consentId?: string | null;
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

export async function requestReportShareConsent({
  siteId,
  learnerId,
  scope,
  audience,
  visibility,
  purpose,
  evidenceSummary,
  expiresInDays,
}: RequestReportShareConsentParams): Promise<string | null> {
  if (!siteId || !learnerId || !purpose.trim() || !evidenceSummary.trim()) return null;

  try {
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { requestE2EReportShareConsent } = await import('@/src/testing/e2e/fakeWebBackend');
      const response = await requestE2EReportShareConsent({
        siteId,
        learnerId,
        scope,
        audience,
        visibility,
        purpose: purpose.trim(),
        evidenceSummary: evidenceSummary.trim(),
        expiresInDays,
      });
      return response.id;
    }

    const callable = httpsCallable(functions, 'requestReportShareConsent');
    const response = await callable({
      siteId,
      learnerId,
      scope,
      audience,
      visibility,
      purpose: purpose.trim(),
      evidenceSummary: evidenceSummary.trim(),
      expiresInDays,
    });
    const data = response.data as { id?: unknown } | undefined;
    return typeof data?.id === 'string' ? data.id : null;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to request report share consent.', error);
    }
    return null;
  }
}

export async function createExplicitConsentReportShareRequest({
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
  explicitConsentId,
  audience,
  visibility,
}: CreateExplicitConsentReportShareRequestParams): Promise<string | null> {
  if (!siteId || !learnerId || !metadata || !reportDelivery || !explicitConsentId) return null;
  if (!completedDeliveryStatuses.has(reportDelivery)) return null;
  if (metadata.report_meets_delivery_contract !== true) return null;
  if (metadata.report_share_policy_declared !== true) return null;
  if (metadata.report_share_audience !== audience || metadata.report_share_visibility !== visibility) {
    return null;
  }

  try {
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { createExplicitE2EReportShareRequest } = await import('@/src/testing/e2e/fakeWebBackend');
      const response = await createExplicitE2EReportShareRequest({
        siteId,
        learnerId,
        reportAction,
        reportDelivery,
        module,
        surface,
        cta,
        fileName,
        expiresInDays,
        audience,
        visibility,
        explicitConsentId,
        metadata,
      });
      return response.id;
    }

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
      audience,
      visibility,
      explicitConsentId,
      metadata,
    });
    const data = response.data as { id?: unknown } | undefined;
    return typeof data?.id === 'string' ? data.id : null;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to create explicit-consent report share request.', error);
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

export async function grantReportShareConsent({
  consentId,
}: ReportShareConsentDecisionParams): Promise<boolean> {
  if (!consentId) return false;

  try {
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { grantE2EReportShareConsent } = await import('@/src/testing/e2e/fakeWebBackend');
      await grantE2EReportShareConsent(consentId);
      return true;
    }

    const callable = httpsCallable(functions, 'grantReportShareConsent');
    await callable({ consentId });
    return true;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to grant report share consent.', error);
    }
    return false;
  }
}

export async function revokeReportShareConsent({
  consentId,
}: ReportShareConsentDecisionParams): Promise<boolean> {
  if (!consentId) return false;

  try {
    if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
      const { revokeE2EReportShareConsent } = await import('@/src/testing/e2e/fakeWebBackend');
      await revokeE2EReportShareConsent(consentId);
      return true;
    }

    const callable = httpsCallable(functions, 'revokeReportShareConsent');
    await callable({ consentId });
    return true;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('Unable to revoke report share consent.', error);
    }
    return false;
  }
}
