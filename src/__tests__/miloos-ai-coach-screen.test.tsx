/** @jest-environment jsdom */

import '@testing-library/jest-dom';
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AICoachScreen } from '@/src/components/sdt/AICoachScreen';
import { sdtMotivation } from '@/src/lib/motivation/sdtMotivation';

jest.mock('@/src/hooks/useTelemetry', () => ({
  useInteractionTracking: () => jest.fn(),
}));

jest.mock('@/src/firebase/auth/AuthProvider', () => ({
  useAuthContext: () => ({ user: { uid: 'learner-1' } }),
}));

jest.mock('@/src/lib/i18n/useI18n', () => ({
  useI18n: () => ({ locale: 'en' }),
}));

jest.mock('@/src/hooks/useVoiceTranscription', () => ({
  useVoiceTranscription: () => ({
    isListening: false,
    isTranscribing: false,
    startListening: jest.fn(),
    stopListening: jest.fn(),
  }),
}));

const mockPlaySpokenResponse = jest.fn();
const mockReplaySpokenResponse = jest.fn();
const mockClearSpokenResponse = jest.fn();
let mockSpokenResponseStatus: string | null = null;

jest.mock('@/src/hooks/useSpokenResponse', () => ({
  useSpokenResponse: () => ({
    spokenResponseStatus: mockSpokenResponseStatus,
    play: mockPlaySpokenResponse,
    replay: mockReplaySpokenResponse,
    clear: mockClearSpokenResponse,
  }),
}));

jest.mock('@/src/lib/motivation/sdtMotivation', () => ({
  sdtMotivation: {
    requestAICoach: jest.fn(),
    submitExplainBack: jest.fn(),
  },
}));

const requestAICoachMock = sdtMotivation.requestAICoach as jest.MockedFunction<
  typeof sdtMotivation.requestAICoach
>;
const submitExplainBackMock = sdtMotivation.submitExplainBack as jest.MockedFunction<
  typeof sdtMotivation.submitExplainBack
>;

describe('AICoachScreen learner-loop refresh', () => {
  beforeEach(() => {
    requestAICoachMock.mockReset();
    submitExplainBackMock.mockReset();
    mockPlaySpokenResponse.mockReset().mockResolvedValue('browser');
    mockReplaySpokenResponse.mockReset().mockResolvedValue('browser');
    mockClearSpokenResponse.mockReset();
    mockSpokenResponseStatus = null;
  });

  it('notifies the parent read model after support response and explain-back submission', async () => {
    const onLearnerLoopUpdated = jest.fn();
    requestAICoachMock.mockResolvedValue({
      message: 'Try changing one prototype variable and compare the result.',
      mode: 'hint',
      requiresExplainBack: true,
      suggestedNextSteps: ['Run one comparison test'],
      learnerState: null,
      risk: {
        reliability: { riskType: 'none', method: 'test', riskScore: 0, threshold: 1 },
        autonomy: { riskType: 'none', signals: [], riskScore: 0, threshold: 1 },
      },
      mvl: { gateActive: false, episodeId: null, reason: null },
      meta: {
        version: 'test',
        gradeBand: 'G9_12',
        conceptTags: ['prototype'],
        aiHelpOpenedEventId: 'opened-1',
      },
    });
    submitExplainBackMock.mockResolvedValue({
      approved: true,
      feedback: 'Explain-back submitted. Your reflection is now attached to this MiloOS session.',
    });

    render(
      <AICoachScreen
        learnerId="learner-1"
        siteId="site-1"
        onLearnerLoopUpdated={onLearnerLoopUpdated}
      />
    );

    fireEvent.click(screen.getByText('Give me a hint'));
    fireEvent.change(screen.getByPlaceholderText(/I'm trying to make the button change color/i), {
      target: { value: 'How do I compare this prototype tradeoff?' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ask MiloOS' }));

    expect(await screen.findByText('Now explain it back!')).toBeInTheDocument();
    expect(requestAICoachMock).toHaveBeenCalledWith(
      'learner-1',
      'site-1',
      expect.objectContaining({
        mode: 'hint',
        studentInput: 'How do I compare this prototype tradeoff?',
      })
    );
    expect(onLearnerLoopUpdated).toHaveBeenCalledTimes(1);

    fireEvent.change(screen.getByPlaceholderText(/I learned that I need to use addEventListener/i), {
      target: {
        value:
          'I learned to change one variable, compare the result, and explain why that tradeoff helps our prototype goal.',
      },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Submit Explanation' }));

    await waitFor(() => {
      expect(submitExplainBackMock).toHaveBeenCalledWith(
        'learner-1',
        'site-1',
        'opened-1',
        'I learned to change one variable, compare the result, and explain why that tradeoff helps our prototype goal.'
      );
    });
    expect(await screen.findByText('Explain-back submitted. Your reflection is now attached to this MiloOS session.'))
      .toBeInTheDocument();
    expect(onLearnerLoopUpdated).toHaveBeenCalledTimes(2);
  });

  it('shows a readable transcript when spoken playback is unavailable', async () => {
    requestAICoachMock.mockResolvedValue({
      message: 'Change one prototype variable, run one comparison, and explain what changed.',
      mode: 'hint',
      requiresExplainBack: true,
      suggestedNextSteps: ['Run one comparison test'],
      learnerState: null,
      risk: {
        reliability: { riskType: 'none', method: 'test', riskScore: 0, threshold: 1 },
        autonomy: { riskType: 'none', signals: [], riskScore: 0, threshold: 1 },
      },
      mvl: { gateActive: false, episodeId: null, reason: null },
      meta: {
        version: 'test',
        gradeBand: 'G9_12',
        conceptTags: ['prototype'],
        aiHelpOpenedEventId: 'opened-1',
      },
    });
    mockPlaySpokenResponse.mockResolvedValue('none');

    render(<AICoachScreen learnerId="learner-1" siteId="site-1" />);

    fireEvent.click(screen.getByText('Give me a hint'));
    fireEvent.change(screen.getByPlaceholderText(/I'm trying to make the button change color/i), {
      target: { value: 'How should I test this change?' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ask MiloOS' }));

    expect(await screen.findByText('MiloOS response transcript')).toBeInTheDocument();
    expect(screen.getByText('Change one prototype variable, run one comparison, and explain what changed.'))
      .toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent(
      'Audio was not available, so read the MiloOS answer below before explaining it back.'
    );
    expect(screen.queryByText(/Unable to get MiloOS help right now/i)).not.toBeInTheDocument();
  });

  it('keeps the transcript available when spoken playback throws', async () => {
    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    requestAICoachMock.mockResolvedValue({
      message: 'Describe the bug in one sentence, then test the smallest possible change.',
      mode: 'debug',
      requiresExplainBack: true,
      suggestedNextSteps: ['Write the smallest failing case'],
      learnerState: null,
      risk: {
        reliability: { riskType: 'none', method: 'test', riskScore: 0, threshold: 1 },
        autonomy: { riskType: 'none', signals: [], riskScore: 0, threshold: 1 },
      },
      mvl: { gateActive: false, episodeId: null, reason: null },
      meta: {
        version: 'test',
        gradeBand: 'G9_12',
        conceptTags: ['debugging'],
        aiHelpOpenedEventId: 'opened-2',
      },
    });
    mockPlaySpokenResponse.mockRejectedValue(new Error('speech failed'));

    render(<AICoachScreen learnerId="learner-1" siteId="site-1" />);

    fireEvent.click(screen.getByText('Help me debug'));
    fireEvent.change(screen.getByPlaceholderText(/My code runs but the answer is wrong/i), {
      target: { value: 'How do I debug this?' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ask MiloOS' }));

    expect(await screen.findByText('MiloOS response transcript')).toBeInTheDocument();
    expect(screen.getByText('Describe the bug in one sentence, then test the smallest possible change.'))
      .toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent(
      'Spoken playback did not start, so read the MiloOS answer below before explaining it back.'
    );
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'MiloOS spoken response error:',
      expect.any(Error)
    );
    consoleErrorSpy.mockRestore();
  });
});
