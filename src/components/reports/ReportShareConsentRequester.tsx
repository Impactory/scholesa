'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { getDocs, query, where } from 'firebase/firestore';
import { reportShareConsentsCollection, reportShareRequestsCollection } from '@/src/lib/firestore/collections';
import {
  createExplicitConsentReportShareRequest,
  requestReportShareConsent,
  type ReportShareConsentScope,
} from '@/src/lib/reports/reportShareRequests';
import {
  reportProvenanceMetadata,
  type ReportProvenanceSignal,
  type ReportShareAudience,
  type ReportSharePolicy,
  type ReportShareVisibility,
} from '@/src/lib/reports/shareExport';
import type { ReportShareConsent, ReportShareRequest } from '@/src/types/schema';

interface PolicyOption {
  scope: Exclude<ReportShareConsentScope, 'family'>;
  label: string;
  audience: ReportShareAudience;
  visibility: ReportShareVisibility;
  allowsExternalSharing: boolean;
}

interface ReportShareConsentRequesterProps {
  siteId?: string | null;
  learnerId?: string | null;
  reportText: string;
  expectedSignals: readonly ReportProvenanceSignal[];
  module: string;
  surface: string;
  cta: string;
  fileName?: string;
  defaultScope?: Exclude<ReportShareConsentScope, 'family'>;
  defaultPurpose?: string;
  defaultEvidenceSummary?: string;
}

const policyOptions: PolicyOption[] = [
  {
    scope: 'staff',
    label: 'Staff',
    audience: 'educator',
    visibility: 'staff',
    allowsExternalSharing: false,
  },
  {
    scope: 'site',
    label: 'Site',
    audience: 'site',
    visibility: 'site',
    allowsExternalSharing: false,
  },
  {
    scope: 'partner',
    label: 'Partner',
    audience: 'partner',
    visibility: 'external',
    allowsExternalSharing: true,
  },
  {
    scope: 'external',
    label: 'External',
    audience: 'external',
    visibility: 'external',
    allowsExternalSharing: true,
  },
  {
    scope: 'public',
    label: 'Public',
    audience: 'external',
    visibility: 'public',
    allowsExternalSharing: true,
  },
];

function toDate(value: unknown): Date | null {
  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as { toDate: () => Date }).toDate === 'function'
  ) {
    return (value as { toDate: () => Date }).toDate();
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function isActiveConsent(consent: ReportShareConsent): boolean {
  if (consent.status !== 'granted' && consent.status !== 'pending') return false;
  const expiresAt = toDate(consent.expiresAt);
  return !expiresAt || expiresAt.getTime() > Date.now();
}

function isActiveShare(request: ReportShareRequest): boolean {
  if (request.status !== 'active') return false;
  const expiresAt = toDate(request.expiresAt);
  return Boolean(expiresAt && expiresAt.getTime() > Date.now());
}

function readConsentDoc(doc: { id: string; data: () => Partial<ReportShareConsent> }): ReportShareConsent {
  const data = doc.data();
  return { ...data, id: doc.id } as ReportShareConsent;
}

function readShareDoc(doc: { id: string; data: () => Partial<ReportShareRequest> }): ReportShareRequest {
  const data = doc.data();
  return { ...data, id: doc.id } as ReportShareRequest;
}

export function ReportShareConsentRequester({
  siteId,
  learnerId,
  reportText,
  expectedSignals,
  module,
  surface,
  cta,
  fileName,
  defaultScope = 'external',
  defaultPurpose = 'Share verified learner evidence with an approved reviewer.',
  defaultEvidenceSummary = 'Evidence-backed learner report with provenance, proof status, and AI disclosure context.',
}: ReportShareConsentRequesterProps) {
  const defaultPolicy = policyOptions.find((option) => option.scope === defaultScope) ?? policyOptions[3];
  const [selectedScope, setSelectedScope] = useState(defaultPolicy.scope);
  const [purpose, setPurpose] = useState(defaultPurpose);
  const [evidenceSummary, setEvidenceSummary] = useState(defaultEvidenceSummary);
  const [consents, setConsents] = useState<ReportShareConsent[]>([]);
  const [shareRequests, setShareRequests] = useState<ReportShareRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  const selectedPolicy = useMemo(
    () => policyOptions.find((option) => option.scope === selectedScope) ?? defaultPolicy,
    [defaultPolicy, selectedScope]
  );

  const sharePolicy = useMemo<ReportSharePolicy>(() => ({
    audience: selectedPolicy.audience,
    visibility: selectedPolicy.visibility,
    requiresEvidenceProvenance: true,
    requiresGuardianContext: true,
    allowsExternalSharing: selectedPolicy.allowsExternalSharing,
    includesLearnerIdentifiers: true,
  }), [selectedPolicy]);

  const metadata = useMemo(
    () => reportProvenanceMetadata({ text: reportText, expectedSignals, sharePolicy }),
    [expectedSignals, reportText, sharePolicy]
  );

  const matchingConsents = useMemo(
    () => consents.filter((consent) => (
      consent.scope === selectedPolicy.scope &&
      consent.audience === selectedPolicy.audience &&
      consent.visibility === selectedPolicy.visibility &&
      isActiveConsent(consent)
    )),
    [consents, selectedPolicy]
  );
  const grantedConsent = matchingConsents.find((consent) => consent.status === 'granted');
  const pendingConsent = matchingConsents.find((consent) => consent.status === 'pending');
  const activeShare = shareRequests.find((request) => (
    request.explicitConsentId === grantedConsent?.id && isActiveShare(request)
  ));

  const loadRecords = useCallback(async () => {
    if (!siteId || !learnerId) {
      setConsents([]);
      setShareRequests([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      if (process.env.NEXT_PUBLIC_E2E_TEST_MODE === '1') {
        const { getE2ECollection } = await import('@/src/testing/e2e/fakeWebBackend');
        setConsents(getE2ECollection('reportShareConsents')
          .filter((record) => record.siteId === siteId && record.learnerId === learnerId)
          .map((record) => record as unknown as ReportShareConsent));
        setShareRequests(getE2ECollection('reportShareRequests')
          .filter((record) => record.siteId === siteId && record.learnerId === learnerId)
          .map((record) => record as unknown as ReportShareRequest));
        setFeedback(null);
        return;
      }

      const [consentSnap, shareSnap] = await Promise.all([
        getDocs(
          query(
            reportShareConsentsCollection,
            where('siteId', '==', siteId),
            where('learnerId', '==', learnerId)
          )
        ),
        getDocs(
          query(
            reportShareRequestsCollection,
            where('siteId', '==', siteId),
            where('learnerId', '==', learnerId),
            where('status', '==', 'active')
          )
        ),
      ]);
      setConsents(consentSnap.docs.map(readConsentDoc));
      setShareRequests(shareSnap.docs.map(readShareDoc));
      setFeedback(null);
    } catch {
      setConsents([]);
      setShareRequests([]);
      setFeedback('Report share consent records could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const handleRequestConsent = async () => {
    setSaving(true);
    setFeedback(null);
    const consentId = await requestReportShareConsent({
      siteId,
      learnerId,
      scope: selectedPolicy.scope,
      audience: selectedPolicy.audience,
      visibility: selectedPolicy.visibility,
      purpose,
      evidenceSummary,
    });
    setFeedback(consentId ? 'Consent requested.' : 'Consent request failed.');
    await loadRecords();
    setSaving(false);
  };

  const handleCreateShare = async () => {
    if (!grantedConsent) return;
    setSaving(true);
    setFeedback(null);
    const shareRequestId = await createExplicitConsentReportShareRequest({
      siteId,
      learnerId,
      reportAction: 'share',
      reportDelivery: 'shared',
      metadata,
      module,
      surface,
      cta,
      fileName,
      explicitConsentId: grantedConsent.id,
      audience: selectedPolicy.audience,
      visibility: selectedPolicy.visibility,
    });
    setFeedback(shareRequestId ? 'Broader report share activated.' : 'Broader report share failed.');
    await loadRecords();
    setSaving(false);
  };

  return (
    <section
      className="rounded-lg border border-app bg-app-surface p-4 space-y-3"
      data-testid={`report-share-consent-requester-${learnerId ?? 'missing'}`}
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h4 className="text-sm font-semibold text-app-foreground">Broader report sharing</h4>
          <p className="mt-1 text-xs text-app-muted">
            Explicit consent required before staff, site, partner, external, or public sharing.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void loadRecords()}
          className="rounded-md border border-app px-3 py-1.5 text-xs font-medium text-app-foreground hover:bg-app-canvas"
        >
          Refresh
        </button>
      </div>

      <div className="flex flex-wrap gap-1 rounded-md border border-app bg-app-canvas p-1">
        {policyOptions.map((option) => (
          <button
            key={option.scope}
            type="button"
            onClick={() => setSelectedScope(option.scope)}
            className={`rounded px-2.5 py-1 text-xs font-medium ${
              selectedScope === option.scope
                ? 'bg-primary text-primary-foreground'
                : 'text-app-muted hover:text-app-foreground'
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>

      <label className="block text-xs font-medium text-app-muted">
        Purpose
        <textarea
          value={purpose}
          onChange={(event) => setPurpose(event.target.value)}
          rows={2}
          className="mt-1 w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
        />
      </label>

      <label className="block text-xs font-medium text-app-muted">
        Evidence summary
        <textarea
          value={evidenceSummary}
          onChange={(event) => setEvidenceSummary(event.target.value)}
          rows={2}
          className="mt-1 w-full rounded-md border border-app bg-app-canvas px-3 py-2 text-sm text-app-foreground"
        />
      </label>

      <div className="grid gap-2 text-xs text-app-muted sm:grid-cols-2">
        <div>
          Delivery contract:{' '}
          <span className={metadata.report_meets_delivery_contract ? 'text-green-700' : 'text-amber-700'}>
            {metadata.report_meets_delivery_contract ? 'ready' : 'missing provenance'}
          </span>
        </div>
        <div>
          Consent status:{' '}
          <span className={grantedConsent ? 'text-green-700' : pendingConsent ? 'text-amber-700' : 'text-app-muted'}>
            {grantedConsent ? 'granted' : pendingConsent ? 'pending' : 'not requested'}
          </span>
        </div>
      </div>

      {loading ? (
        <p className="text-xs text-app-muted">Loading report share consent...</p>
      ) : (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            disabled={saving || Boolean(pendingConsent) || Boolean(grantedConsent) || !purpose.trim() || !evidenceSummary.trim()}
            onClick={() => void handleRequestConsent()}
            className="rounded-md border border-app px-3 py-2 text-xs font-semibold text-app-foreground hover:bg-app-canvas disabled:opacity-50"
          >
            Request consent
          </button>
          <button
            type="button"
            disabled={saving || !grantedConsent || Boolean(activeShare) || !metadata.report_meets_delivery_contract}
            onClick={() => void handleCreateShare()}
            className="rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          >
            Activate share
          </button>
        </div>
      )}

      {activeShare && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-xs text-green-800">
          Active share: {activeShare.id}
        </p>
      )}
      {feedback && <p className="text-xs text-app-muted">{feedback}</p>}
    </section>
  );
}
