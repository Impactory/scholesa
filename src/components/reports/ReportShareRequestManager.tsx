'use client';

import { useCallback, useEffect, useState } from 'react';
import { getDocs, query, where } from 'firebase/firestore';
import { reportShareRequestsCollection } from '@/src/lib/firestore/collections';
import { revokeReportShareRequest } from '@/src/lib/reports/reportShareRequests';
import type { ReportShareRequest } from '@/src/types/schema';

interface ReportShareRequestManagerProps {
  siteId: string | null | undefined;
  learnerId: string | null | undefined;
  viewer: 'learner' | 'guardian';
}

type ReportShareRequestRow = ReportShareRequest & { id: string };

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

export function ReportShareRequestManager({
  siteId,
  learnerId,
  viewer,
}: ReportShareRequestManagerProps) {
  const [requests, setRequests] = useState<ReportShareRequestRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [revokingId, setRevokingId] = useState<string | null>(null);

  const loadRequests = useCallback(async () => {
    if (!siteId || !learnerId) {
      setRequests([]);
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
      setRequests(activeRequests);
    } catch {
      setRequests([]);
      setFeedback('Active report shares could not be loaded.');
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
            External/public sharing remains blocked until explicit consent workflow support exists.
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
        <p className="mt-3 text-xs text-gray-600">Loading active report shares...</p>
      ) : requests.length === 0 ? (
        <p className="mt-3 text-xs text-gray-600">No active report shares for this learner.</p>
      ) : (
        <ul className="mt-3 space-y-2">
          {requests.map((request) => (
            <li
              key={request.id}
              className="flex flex-wrap items-start justify-between gap-3 rounded-md border border-gray-200 bg-white p-3"
            >
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
                  {request.provenance.meetsDeliveryContract ? 'passed' : 'needs review'} · expected:{' '}
                  {formatSignalList(request.provenance.expectedSignals)} · missing:{' '}
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
              </div>
              <button
                type="button"
                onClick={() => void handleRevoke(request.id)}
                disabled={revokingId === request.id || !isRevocableForViewer(request, viewer)}
                className="rounded-md border border-red-200 bg-white px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {revokingId === request.id
                  ? 'Revoking...'
                  : isRevocableForViewer(request, viewer)
                    ? 'Revoke'
                    : 'Visible'}
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
