'use client';

import { useCallback, useEffect, useState } from 'react';
import { getDocs, query, where } from 'firebase/firestore';
import {
  reportShareConsentsCollection,
  reportShareRequestsCollection,
} from '@/src/lib/firestore/collections';
import {
  grantReportShareConsent,
  revokeReportShareConsent,
  revokeReportShareRequest,
} from '@/src/lib/reports/reportShareRequests';
import type { ReportShareConsent, ReportShareRequest } from '@/src/types/schema';

interface ReportShareRequestManagerProps {
  siteId: string | null | undefined;
  learnerId: string | null | undefined;
  viewer: 'learner' | 'guardian';
}

type ReportShareRequestRow = ReportShareRequest & { id: string };
type ReportShareConsentRow = ReportShareConsent & { id: string };

function timestampToDate(value: unknown): Date | null {
  if (!value || typeof value !== 'object') return null;
  const candidate = value as { toDate?: () => Date };
  if (typeof candidate.toDate !== 'function') return null;
  try {
    return candidate.toDate();
  } catch {
    return null;
  }
}

function formatDate(value: unknown): string {
  const date = timestampToDate(value);
  if (!date) return 'date unavailable';
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function isUnexpiredShare(request: ReportShareRequestRow): boolean {
  const expiresAt = timestampToDate(request.expiresAt);
  return Boolean(expiresAt && expiresAt.getTime() > Date.now());
}

function isUnexpiredConsent(consent: ReportShareConsentRow): boolean {
  const expiresAt = timestampToDate(consent.expiresAt);
  return Boolean(expiresAt && expiresAt.getTime() > Date.now());
}

function isVisibleConsent(consent: ReportShareConsentRow): boolean {
  return (consent.status === 'pending' || consent.status === 'granted') && isUnexpiredConsent(consent);
}

function isVisibleForViewer(request: ReportShareRequestRow, viewer: 'learner' | 'guardian') {
  const isGuardianFamilyShare = request.audience === 'guardian' && request.visibility === 'family';
  if (viewer === 'guardian') return isGuardianFamilyShare;
  return (
    isGuardianFamilyShare || (request.audience === 'learner' && request.visibility === 'private')
  );
}

function isRevocableForViewer(request: ReportShareRequestRow, viewer: 'learner' | 'guardian') {
  if (viewer === 'guardian') {
    return request.audience === 'guardian' && request.visibility === 'family';
  }
  return request.audience === 'learner' && request.visibility === 'private';
}

function labelForAction(action: ReportShareRequest['reportAction']): string {
  switch (action) {
    case 'export_html':
      return 'HTML export';
    case 'export_pdf':
      return 'PDF export';
    case 'export_text':
      return 'Text export';
    default:
      return 'Family share';
  }
}

function formatSignalList(signals: string[] | undefined): string {
  if (!signals || signals.length === 0) return 'none';
  return signals.join(', ');
}

function labelForDelivery(delivery: ReportShareRequest['reportDelivery']): string {
  if (!delivery) return 'recorded';
  return delivery.replace(/-/g, ' ');
}

function revocationActionLabel(request: ReportShareRequestRow, viewer: 'learner' | 'guardian') {
  if (isRevocableForViewer(request, viewer)) return 'Revoke active report share';
  return 'Visible for transparency; revocation belongs to the share audience';
}

function labelForConsentStatus(status: ReportShareConsent['status']): string {
  if (status === 'pending') return 'Consent requested';
  if (status === 'granted') return 'Consent granted';
  return status;
}

export function ReportShareRequestManager({
  siteId,
  learnerId,
  viewer,
}: ReportShareRequestManagerProps) {
  const [requests, setRequests] = useState<ReportShareRequestRow[]>([]);
  const [consents, setConsents] = useState<ReportShareConsentRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [revokingId, setRevokingId] = useState<string | null>(null);
  const [decidingConsentId, setDecidingConsentId] = useState<string | null>(null);

  const loadRequests = useCallback(async () => {
    if (!siteId || !learnerId) {
      setRequests([]);
      setConsents([]);
      return;
    }

    setLoading(true);
    setFeedback(null);
    try {
      const snap = await getDocs(
        query(
          reportShareRequestsCollection,
          where('siteId', '==', siteId),
          where('learnerId', '==', learnerId),
          where('status', '==', 'active')
        )
      );
      const activeRequests = snap.docs
        .map((docSnap) => {
          const { id: _storedId, ...data } = docSnap.data();
          return { ...data, id: docSnap.id } as ReportShareRequestRow;
        })
        .filter(isUnexpiredShare)
        .filter((request) => isVisibleForViewer(request, viewer))
        .slice(0, 25);
      const consentSnap = await getDocs(
        query(
          reportShareConsentsCollection,
          where('siteId', '==', siteId),
          where('learnerId', '==', learnerId)
        )
      );
      const visibleConsents = consentSnap.docs
        .map((docSnap) => {
          const { id: _storedId, ...data } = docSnap.data();
          return { ...data, id: docSnap.id } as ReportShareConsentRow;
        })
        .filter(isVisibleConsent)
        .slice(0, 25);
      setRequests(activeRequests);
      setConsents(visibleConsents);
    } catch {
      setRequests([]);
      setConsents([]);
      setFeedback('Active report shares or consent requests could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [learnerId, siteId, viewer]);

  useEffect(() => {
    void loadRequests();
  }, [loadRequests]);

  const handleRevoke = useCallback(
    async (shareRequestId: string) => {
      setRevokingId(shareRequestId);
      setFeedback(null);
      const revoked = await revokeReportShareRequest({
        shareRequestId,
        reason: `${viewer}_revoked_report_share`,
      });
      setRevokingId(null);
      if (!revoked) {
        setFeedback('Share revocation failed. The active share is still listed.');
        return;
      }
      setFeedback('Active report share revoked.');
      await loadRequests();
    },
    [loadRequests, viewer]
  );

  const handleGrantConsent = useCallback(
    async (consentId: string) => {
      setDecidingConsentId(consentId);
      setFeedback(null);
      const granted = await grantReportShareConsent({ consentId });
      setDecidingConsentId(null);
      if (!granted) {
        setFeedback('Consent grant failed. The request is still pending.');
        return;
      }
      setFeedback('Report share consent granted.');
      await loadRequests();
    },
    [loadRequests]
  );

  const handleRevokeConsent = useCallback(
    async (consentId: string) => {
      setDecidingConsentId(consentId);
      setFeedback(null);
      const revoked = await revokeReportShareConsent({ consentId });
      setDecidingConsentId(null);
      if (!revoked) {
        setFeedback('Consent revocation failed. The consent is still listed.');
        return;
      }
      setFeedback('Report share consent revoked.');
      await loadRequests();
    },
    [loadRequests]
  );

  if (!siteId || !learnerId) return null;

  return (
    <section
      className="print:hidden rounded-lg border border-gray-200 bg-gray-50 p-4"
      data-testid={`report-share-request-manager-${learnerId}`}
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold text-gray-900">Active report shares</h3>
          <p className="mt-1 text-xs text-gray-600">
            Family/private report deliveries stay visible here until they expire or are revoked.
            External, partner, staff, site, and public sharing require granted explicit consent.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void loadRequests()}
          className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50"
        >
          Refresh
        </button>
      </div>

      {feedback && (
        <p
          className="mt-3 text-xs font-medium text-gray-700"
          data-testid="report-share-request-feedback"
        >
          {feedback}
        </p>
      )}

      {loading ? (
        <p className="mt-3 text-xs text-gray-600">Loading active report shares and consent requests...</p>
      ) : requests.length === 0 ? (
        <p className="mt-3 text-xs text-gray-600">No active report shares for this learner.</p>
      ) : (
        <ul className="mt-3 space-y-2">
          {requests.map((request) => (
            <li key={request.id} className="rounded-md border border-gray-200 bg-white p-3">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="max-w-3xl text-xs text-gray-600">
                  <p className="font-medium text-gray-900">
                    {labelForAction(request.reportAction)} · {request.visibility}
                  </p>
                  <p className="mt-0.5">
                    {request.fileName ?? request.surface ?? 'Evidence-backed report'} · expires{' '}
                    {formatDate(request.expiresAt)}
                  </p>
                  <p className="mt-1">
                    Audience: {request.audience} · delivery:{' '}
                    {labelForDelivery(request.reportDelivery)}
                  </p>
                  <p className="mt-1">
                    Provenance contract:{' '}
                    {request.provenance.meetsDeliveryContract ? 'passed' : 'needs review'} ·
                    expected: {formatSignalList(request.provenance.expectedSignals)} · missing:{' '}
                    {formatSignalList(request.provenance.missingSignals)}
                  </p>
                  <p className="mt-1">
                    Policy: evidence provenance{' '}
                    {request.sharePolicy.requiresEvidenceProvenance ? 'required' : 'not required'} ·
                    guardian context{' '}
                    {request.sharePolicy.requiresGuardianContext ? 'required' : 'not required'} ·
                    external sharing{' '}
                    {request.sharePolicy.allowsExternalSharing ? 'allowed' : 'blocked'}
                  </p>
                  {!isRevocableForViewer(request, viewer) && (
                    <p className="mt-1 font-medium text-gray-700">
                      Visible for transparency; revocation belongs to the share audience.
                    </p>
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => void handleRevoke(request.id)}
                  disabled={revokingId === request.id || !isRevocableForViewer(request, viewer)}
                  aria-label={revocationActionLabel(request, viewer)}
                  title={revocationActionLabel(request, viewer)}
                  className="rounded-md border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {revokingId === request.id
                    ? 'Revoking...'
                    : isRevocableForViewer(request, viewer)
                      ? 'Revoke'
                      : 'Visible'}
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {!loading && consents.length > 0 && (
        <div className="mt-4 border-t border-gray-200 pt-4">
          <h4 className="text-xs font-semibold uppercase tracking-wide text-gray-700">
            Explicit consent requests
          </h4>
          <ul className="mt-2 space-y-2">
            {consents.map((consent) => (
              <li key={consent.id} className="rounded-md border border-amber-200 bg-white p-3">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="max-w-3xl text-xs text-gray-600">
                    <p className="font-medium text-gray-900">
                      {labelForConsentStatus(consent.status)} · {consent.scope}
                    </p>
                    <p className="mt-0.5">
                      Audience: {consent.audience} · visibility: {consent.visibility} · expires{' '}
                      {formatDate(consent.expiresAt)}
                    </p>
                    <p className="mt-1">Purpose: {consent.purpose}</p>
                    <p className="mt-1">Evidence: {consent.evidenceSummary}</p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {consent.status === 'pending' && (
                      <button
                        type="button"
                        onClick={() => void handleGrantConsent(consent.id)}
                        disabled={decidingConsentId === consent.id}
                        className="rounded-md border border-green-200 bg-white px-3 py-1.5 text-xs font-medium text-green-700 hover:bg-green-50 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        {decidingConsentId === consent.id ? 'Granting...' : 'Grant'}
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => void handleRevokeConsent(consent.id)}
                      disabled={decidingConsentId === consent.id}
                      className="rounded-md border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {decidingConsentId === consent.id ? 'Revoking...' : 'Revoke consent'}
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
