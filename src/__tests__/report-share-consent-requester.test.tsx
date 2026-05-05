/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { getDocs } from 'firebase/firestore';
import { ReportShareConsentRequester } from '@/src/components/reports/ReportShareConsentRequester';
import {
  createExplicitConsentReportShareRequest,
  requestReportShareConsent,
} from '@/src/lib/reports/reportShareRequests';

jest.mock('firebase/firestore', () => ({
  getDocs: jest.fn(),
  query: jest.fn((...args) => args),
  where: jest.fn((...args) => args),
}));

jest.mock('@/src/lib/firestore/collections', () => ({
  reportShareConsentsCollection: { path: 'reportShareConsents' },
  reportShareRequestsCollection: { path: 'reportShareRequests' },
}));

jest.mock('@/src/lib/reports/reportShareRequests', () => ({
  createExplicitConsentReportShareRequest: jest.fn(async () => 'share-request-1'),
  requestReportShareConsent: jest.fn(async () => 'consent-request-1'),
}));

const mockGetDocs = getDocs as jest.MockedFunction<typeof getDocs>;
const mockRequestReportShareConsent = requestReportShareConsent as jest.MockedFunction<
  typeof requestReportShareConsent
>;
const mockCreateExplicitConsentReportShareRequest =
  createExplicitConsentReportShareRequest as jest.MockedFunction<
    typeof createExplicitConsentReportShareRequest
  >;

function timestamp(date: string) {
  return { toDate: () => new Date(date) };
}

function consentDoc(id: string, overrides: Record<string, unknown>) {
  return {
    id,
    data: () => ({
      id: `stored-${id}`,
      siteId: 'site-1',
      learnerId: 'learner-1',
      requesterId: 'educator-1',
      requesterRole: 'educator',
      status: 'pending',
      scope: 'external',
      audience: 'external',
      visibility: 'external',
      purpose: 'Share verified learner evidence with an approved reviewer.',
      evidenceSummary: 'Verified portfolio evidence only.',
      expiresAt: timestamp('2099-05-01T00:00:00.000Z'),
      ...overrides,
    }),
  };
}

function docsSnapshot(docs: Array<ReturnType<typeof consentDoc>>) {
  return { docs } as unknown as Awaited<ReturnType<typeof getDocs>>;
}

function renderRequester() {
  return render(
    <ReportShareConsentRequester
      siteId="site-1"
      learnerId="learner-1"
      reportText={[
        'Evidence id: evidence-1',
        'Mission attempt id: attempt-1',
        'Proof-of-learning proof status: verified',
        'AI disclosure status: learner AI disclosure present',
        'Reviewed by educator: educator-1',
        'Verification prompt: verify next with learner explanation.',
      ].join('\n')}
      expectedSignals={['evidence', 'mission', 'proof', 'aiDisclosure', 'reviewer', 'verificationPrompt']}
      module="passport"
      surface="educator_evidence_review"
      cta="educator_request_broader_report_share"
    />
  );
}

describe('ReportShareConsentRequester', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('requests explicit consent without granting it in requester UI', async () => {
    mockGetDocs.mockResolvedValue(docsSnapshot([]));

    renderRequester();

    expect(await screen.findByText('Broader report sharing')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Grant' })).not.toBeInTheDocument();

    fireEvent.click(await screen.findByRole('button', { name: 'Request consent' }));

    await waitFor(() => {
      expect(mockRequestReportShareConsent).toHaveBeenCalledWith({
        siteId: 'site-1',
        learnerId: 'learner-1',
        scope: 'external',
        audience: 'external',
        visibility: 'external',
        purpose: 'Share verified learner evidence with an approved reviewer.',
        evidenceSummary:
          'Evidence-backed learner report with provenance, proof status, and AI disclosure context.',
      });
    });
  });

  it('activates a broader share only from matching granted consent', async () => {
    mockGetDocs.mockImplementation(async (queryArgs: unknown) => {
      const collectionArg = Array.isArray(queryArgs) ? queryArgs[0] : null;
      if (collectionArg && typeof collectionArg === 'object' && 'path' in collectionArg) {
        if ((collectionArg as { path: string }).path === 'reportShareConsents') {
          return docsSnapshot([consentDoc('consent-granted', { status: 'granted' })]);
        }
      }
      return docsSnapshot([]);
    });

    renderRequester();

    expect(await screen.findByText(/Consent status:/)).toBeInTheDocument();
    fireEvent.click(await screen.findByRole('button', { name: 'Activate share' }));

    await waitFor(() => {
      expect(mockCreateExplicitConsentReportShareRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          siteId: 'site-1',
          learnerId: 'learner-1',
          reportAction: 'share',
          reportDelivery: 'shared',
          explicitConsentId: 'consent-granted',
          audience: 'external',
          visibility: 'external',
          module: 'passport',
          surface: 'educator_evidence_review',
          cta: 'educator_request_broader_report_share',
        })
      );
    });
  });
});
