/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MiloOSLearnerSupportSnapshot } from '@/src/components/dashboards/MiloOSLearnerSupportSnapshot';
import {
  getMiloOSLearnerLoopInsights,
  type MiloOSLearnerLoopInsights,
} from '@/src/lib/miloos/learnerLoopInsights';

jest.mock('next/dynamic', () => ({
  __esModule: true,
  default: () => function MockDynamicComponent({
    onLearnerLoopUpdated,
  }: {
    onLearnerLoopUpdated?: () => void | Promise<void>;
  }) {
    return (
      <button type="button" data-testid="mock-ai-coach" onClick={() => onLearnerLoopUpdated?.()}>
        Mock MiloOS coach
      </button>
    );
  },
}));

jest.mock('@/src/lib/miloos/learnerLoopInsights', () => ({
  getMiloOSLearnerLoopInsights: jest.fn(),
}));

const getInsightsMock = getMiloOSLearnerLoopInsights as jest.MockedFunction<
  typeof getMiloOSLearnerLoopInsights
>;

function buildInsights(
  overrides: Partial<MiloOSLearnerLoopInsights> = {}
): MiloOSLearnerLoopInsights {
  return {
    siteId: 'site-1',
    learnerId: 'learner-1',
    lookbackDays: 30,
    state: {
      cognition: 0.82,
      engagement: 0.74,
      integrity: 0.93,
    },
    trend: {
      cognitionDelta: 0.2,
      engagementDelta: 0.16,
      integrityDelta: 0.09,
      improvementScore: 0.144,
    },
    stateAvailability: {
      validSamples: 2,
      hasCurrentState: true,
      hasTrendBaseline: true,
    },
    eventCounts: {
      ai_help_opened: 2,
      ai_help_used: 2,
      ai_coach_response: 2,
      explain_it_back_submitted: 1,
    },
    verification: {
      aiHelpOpened: 2,
      aiHelpUsed: 2,
      explainBackSubmitted: 1,
      pendingExplainBack: 1,
    },
    mvl: {
      active: 0,
      passed: 0,
      failed: 0,
    },
    activeGoals: [],
    generatedAt: '2026-04-27T00:00:00.000Z',
    ...overrides,
  };
}

describe('MiloOSLearnerSupportSnapshot', () => {
  beforeEach(() => {
    getInsightsMock.mockReset();
  });

  it('renders support journey verification gaps without presenting them as mastery', async () => {
    getInsightsMock.mockResolvedValue(buildInsights());

    render(<MiloOSLearnerSupportSnapshot learnerId="learner-1" siteId="site-1" />);

    expect(await screen.findByText('MiloOS Support Snapshot')).toBeInTheDocument();
    expect(screen.getByText('Server-read learning support signals, separate from capability mastery.'))
      .toBeInTheDocument();
    expect(screen.getByText('2 support sessions opened')).toBeInTheDocument();
    expect(screen.getByText('1 explain-backs / 1 pending')).toBeInTheDocument();
    expect(screen.getByText('Support signals are strengthening')).toBeInTheDocument();
    expect(screen.getByText('2 state samples')).toBeInTheDocument();
    expect(screen.getByText('0 active verification checks')).toBeInTheDocument();
    expect(screen.queryByText(/mastery level/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/capability score/i)).not.toBeInTheDocument();

    await waitFor(() => {
      expect(getInsightsMock).toHaveBeenCalledWith({
        learnerId: 'learner-1',
        siteId: 'site-1',
        lookbackDays: 30,
      });
    });
  });

  it('refreshes support journey when the embedded coach records learner-loop events', async () => {
    getInsightsMock
      .mockResolvedValueOnce(buildInsights())
      .mockResolvedValueOnce(buildInsights({
        eventCounts: {
          ai_help_opened: 2,
          ai_help_used: 2,
          ai_coach_response: 2,
          explain_it_back_submitted: 2,
        },
        verification: {
          aiHelpOpened: 2,
          aiHelpUsed: 2,
          explainBackSubmitted: 2,
          pendingExplainBack: 0,
        },
      }));

    render(<MiloOSLearnerSupportSnapshot learnerId="learner-1" siteId="site-1" />);

    expect(await screen.findByText('1 explain-backs / 1 pending')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Open MiloOS coach' }));
    fireEvent.click(screen.getByTestId('mock-ai-coach'));

    expect(await screen.findByText('2 explain-backs / 0 pending')).toBeInTheDocument();
    expect(getInsightsMock).toHaveBeenCalledTimes(2);
  });
});