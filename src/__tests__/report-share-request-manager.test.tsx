/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { getDocs } from 'firebase/firestore';
import { ReportShareRequestManager } from '@/src/components/reports/ReportShareRequestManager';
import { revokeReportShareRequest } from '@/src/lib/reports/reportShareRequests';

jest.mock('firebase/firestore', () => ({
  getDocs: jest.fn(),
  query: jest.fn((...args) => args),
  where: jest.fn((...args) => args),
}));

jest.mock('@/src/lib/firestore/collections', () => ({
  reportShareRequestsCollection: { path: 'reportShareRequests' },
}));

jest.mock('@/src/lib/reports/reportShareRequests', () => ({
  revokeReportShareRequest: jest.fn(async () => true),
}));

const mockGetDocs = getDocs as jest.MockedFunction<typeof getDocs>;
const mockRevokeReportShareRequest = revokeReportShareRequest as jest.MockedFunction<
  typeof revokeReportShareRequest
>;

function timestamp(date: string) {
  return { toDate: () => new Date(date) };
}

function shareDoc(id: string, overrides: Record<string, unknown>) {
  return {
    id,
    data: () => ({
      id: `stored-${id}`,
      siteId: 'site-1',
      learnerId: 'learner-1',
      status: 'active',
      reportAction: 'share',
      reportDelivery: 'copied',
      fileName: `${id}.txt`,
      expiresAt: timestamp('2099-05-01T00:00:00.000Z'),
      sharePolicy: {
        requiresEvidenceProvenance: true,
        requiresGuardianContext: true,
        allowsExternalSharing: false,
      },
      provenance: {
        meetsDeliveryContract: true,
        expectedSignals: ['evidence', 'growth'],
        missingSignals: [],
      },
      ...overrides,
    }),
  };
}

describe('ReportShareRequestManager', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('shows learner-private and guardian-family rows to learners but only private rows are learner-revocable', async () => {
    mockGetDocs.mockResolvedValueOnce({
      docs: [
        shareDoc('learner-private', { audience: 'learner', visibility: 'private' }),
        shareDoc('guardian-family', { audience: 'guardian', visibility: 'family' }),
        shareDoc('malformed-family', { audience: 'learner', visibility: 'family' }),
      ],
    } as Awaited<ReturnType<typeof getDocs>>);

    render(<ReportShareRequestManager siteId="site-1" learnerId="learner-1" viewer="learner" />);

    expect(await screen.findByText(/learner-private\.txt/)).toBeInTheDocument();
    expect(screen.getByText(/guardian-family\.txt/)).toBeInTheDocument();
    expect(screen.queryByText(/malformed-family\.txt/)).not.toBeInTheDocument();
    expect(
      screen.getByText('Visible for transparency; revocation belongs to the share audience.')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', {
        name: 'Visible for transparency; revocation belongs to the share audience',
      })
    ).toBeDisabled();

    fireEvent.click(screen.getByRole('button', { name: 'Revoke active report share' }));
    await waitFor(() => {
      expect(mockRevokeReportShareRequest).toHaveBeenCalledWith({
        shareRequestId: 'learner-private',
        reason: 'learner_revoked_report_share',
      });
    });
  });

  it('shows only guardian-family rows to guardians and clears stale rows when loading fails', async () => {
    mockGetDocs
      .mockResolvedValueOnce({
        docs: [
          shareDoc('guardian-family', { audience: 'guardian', visibility: 'family' }),
          shareDoc('learner-private', { audience: 'learner', visibility: 'private' }),
        ],
      } as Awaited<ReturnType<typeof getDocs>>)
      .mockRejectedValueOnce(new Error('permission denied'));

    render(<ReportShareRequestManager siteId="site-1" learnerId="learner-1" viewer="guardian" />);

    expect(await screen.findByText(/guardian-family\.txt/)).toBeInTheDocument();
    expect(screen.queryByText(/learner-private\.txt/)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }));

    await waitFor(() => {
      expect(screen.getByText('Active report shares could not be loaded.')).toBeInTheDocument();
    });
    expect(screen.queryByText(/guardian-family\.txt/)).not.toBeInTheDocument();
    expect(screen.getByText('No active report shares for this learner.')).toBeInTheDocument();
  });
});
