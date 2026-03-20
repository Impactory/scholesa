'use client';

/**
 * AI Coach Screen
 * 
 * Level 1: Must-have for flow and retention
 * Three modes: Hint / Rubric Check / Debug-by-Questions + Explain-it-back box
 * Guardrails: Student must explain back and show proof of work
 */

import React, { useEffect, useState } from 'react';
import {
  LightbulbIcon,
  ClipboardCheckIcon,
  BugIcon,
  SendIcon,
  CheckCircle2Icon,
  AlertCircleIcon,
  Volume2Icon
} from 'lucide-react';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { sdtMotivation, type AICoachRequest, type AICoachResponse } from '@/src/lib/motivation/sdtMotivation';
import { speakBrowserText, stopBrowserSpeech } from '@/src/lib/voice/browserSpeech';

interface AICoachScreenProps {
  learnerId: string;
  siteId: string;
  sprintSessionId?: string;
  missionId?: string;
}

type CoachMode = 'hint' | 'verify' | 'debug';

export function AICoachScreen({
  learnerId,
  siteId,
  sprintSessionId,
  missionId
}: AICoachScreenProps) {
  const trackInteraction = useInteractionTracking();
  const [mode, setMode] = useState<CoachMode | null>(null);
  const [question, setQuestion] = useState('');
  const [response, setResponse] = useState<AICoachResponse | null>(null);
  const [explainBack, setExplainBack] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [spokenResponseStatus, setSpokenResponseStatus] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      stopBrowserSpeech();
    };
  }, []);

  const playSpokenResponse = (text: string): boolean => {
    stopBrowserSpeech();
    return speakBrowserText(text);
  };

  const describeSpokenResponse = (wasSpoken: boolean): string => {
    if (wasSpoken) {
      return 'AI Help answered out loud. Replay the spoken response if you need to hear it again.';
    }

    return 'AI Help prepared a spoken response, but this browser could not play it out loud. Turn on audio and try Replay.';
  };

  const handleSubmitQuestion = async () => {
    if (!question.trim() || !mode) return;

    trackInteraction('help_accessed', {
      cta: 'ai_coach_submit_question',
      mode,
      hasMissionContext: Boolean(missionId),
    });

    try {
      setLoading(true);
      setError(null);
      setStatusMessage(null);
      setSpokenResponseStatus(null);

      const request: AICoachRequest = {
        mode,
        studentInput: question,
        missionId,
        sessionOccurrenceId: sprintSessionId,
      };

      const aiResponse = await sdtMotivation.requestAICoach(learnerId, siteId, request);
      setResponse(aiResponse);
      setSpokenResponseStatus(describeSpokenResponse(playSpokenResponse(aiResponse.message)));
    } catch (err) {
      console.error('AI Coach error:', err);
      setError('Unable to get AI help right now. Try again or ask your teacher!');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitExplainBack = async () => {
    if (!explainBack.trim() || !response) return;

    const interactionId = response.meta.aiHelpOpenedEventId?.trim();
    if (!interactionId) {
      setError('Unable to submit your explanation right now. Try again or ask your teacher to review it.');
      return;
    }

    trackInteraction('feature_discovered', {
      cta: 'ai_coach_submit_explain_back',
      mode,
      explainLength: explainBack.trim().length,
    });

    try {
      setLoading(true);
      setError(null);

      const result = await sdtMotivation.submitExplainBack(
        learnerId,
        siteId,
        interactionId,
        explainBack.trim(),
      );

      setExplainBack('');
      setStatusMessage(
        result.feedback?.trim() ||
          (result.approved
            ? 'Explain-back submitted. Your reflection is now attached to this AI help session.'
            : 'Explain-back submitted for review.'),
      );
      setResponse((current) =>
        current
          ? {
              ...current,
              requiresExplainBack: false,
            }
          : current,
      );
      trackInteraction('help_accessed', {
        cta: 'ai_coach_explain_back_recorded',
        mode,
        approved: result.approved,
      });
    } catch (err) {
      console.error('AI Coach explain-back error:', err);
      setError('Unable to submit your explanation right now. Try again or ask your teacher to review it.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-500 to-indigo-600 rounded-lg p-6 text-white">
        <h1 className="text-2xl font-bold mb-2">AI Help</h1>
        <p className="text-purple-100">
          Get help when you're stuck - but remember, you still need to understand and explain it!
        </p>
      </div>

      {/* Guardrails Notice */}
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 flex gap-3">
        <AlertCircleIcon className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
        <div className="text-sm text-yellow-800">
          <p className="font-medium mb-1">Remember:</p>
          <ul className="list-disc list-inside space-y-1">
            <li>AI can give hints, not answers</li>
            <li>You must explain what you learned</li>
            <li>Show your work and version history</li>
          </ul>
        </div>
      </div>

      {/* Mode Selection */}
      {!mode && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'ai_coach_mode_hint' });
              setMode('hint');
            }}
            className="group bg-white border-2 border-gray-200 rounded-lg p-6 hover:border-purple-500 hover:shadow-lg transition-all"
          >
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-3 group-hover:bg-purple-200">
              <LightbulbIcon className="w-6 h-6 text-purple-600" />
            </div>
            <h3 className="font-bold text-gray-900 mb-2">Give me a hint</h3>
            <p className="text-sm text-gray-600">Get a nudge in the right direction without giving away the answer</p>
          </button>

          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'ai_coach_mode_rubric_check' });
              setMode('verify');
            }}
            className="group bg-white border-2 border-gray-200 rounded-lg p-6 hover:border-indigo-500 hover:shadow-lg transition-all"
          >
            <div className="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center mx-auto mb-3 group-hover:bg-indigo-200">
              <ClipboardCheckIcon className="w-6 h-6 text-indigo-600" />
            </div>
            <h3 className="font-bold text-gray-900 mb-2">Check my work vs rubric</h3>
            <p className="text-sm text-gray-600">See how your work compares to what "good" looks like</p>
          </button>

          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'ai_coach_mode_debug' });
              setMode('debug');
            }}
            className="group bg-white border-2 border-gray-200 rounded-lg p-6 hover:border-blue-500 hover:shadow-lg transition-all"
          >
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-3 group-hover:bg-blue-200">
              <BugIcon className="w-6 h-6 text-blue-600" />
            </div>
            <h3 className="font-bold text-gray-900 mb-2">Help me debug</h3>
            <p className="text-sm text-gray-600">I'll ask you questions to help you find the problem yourself</p>
          </button>
        </div>
      )}

      {/* Question Input */}
      {mode && !response && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'ai_coach_back_to_modes' });
              setMode(null);
              setQuestion('');
            }}
            className="text-sm text-gray-600 hover:text-gray-900 mb-4"
          >
            ← Back to modes
          </button>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                What do you need help with?
              </label>
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder={
                  mode === 'hint'
                    ? 'Example: I\'m trying to make the button change color but it\'s not working...'
                    : mode === 'verify'
                    ? 'Example: I finished my project. Can you check if I met all the requirements?'
                    : 'Example: My code runs but the answer is wrong. I\'ve checked my logic three times...'
                }
                className="w-full h-32 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                disabled={loading}
              />
            </div>

            <button
              onClick={handleSubmitQuestion}
              disabled={!question.trim() || loading}
              className="w-full bg-indigo-600 text-white px-4 py-3 rounded-lg font-medium hover:bg-indigo-700 disabled:bg-gray-300 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                  <span>Thinking...</span>
                </>
              ) : (
                <>
                  <SendIcon className="w-5 h-5" />
                  <span>Ask AI Help</span>
                </>
              )}
            </button>
          </div>
        </div>
      )}

      {/* AI Response */}
      {response && (
        <div className="bg-white border border-gray-200 rounded-lg p-6 space-y-4">
          {statusMessage ? (
            <div className="rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm text-blue-900">
              {statusMessage}
            </div>
          ) : null}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
              <LightbulbIcon className="w-5 h-5 text-purple-600" />
            </div>
            <div className="flex-1">
              <p className="font-medium text-gray-900 mb-2">AI Help answered out loud.</p>
              <p className="text-gray-700">
                {spokenResponseStatus || 'Replay the spoken response if you need to hear it again.'}
              </p>
              <button
                onClick={() => setSpokenResponseStatus(describeSpokenResponse(playSpokenResponse(response.message)))}
                className="mt-3 inline-flex items-center gap-2 rounded-lg bg-purple-100 px-3 py-2 text-sm font-medium text-purple-900 transition-colors hover:bg-purple-200"
              >
                <Volume2Icon className="w-4 h-4" />
                <span>Replay spoken response</span>
              </button>
            </div>
          </div>

          {/* Suggested Next Steps */}
          {response.suggestedNextSteps && response.suggestedNextSteps.length > 0 && (
            <div className="bg-blue-50 rounded-lg p-4">
              <p className="font-medium text-blue-900 mb-2">Try these next:</p>
              <ul className="list-disc list-inside space-y-1 text-sm text-blue-800">
                {response.suggestedNextSteps.map((step, idx) => (
                  <li key={idx}>{step}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Explain-it-Back (if required) */}
          {response.requiresExplainBack && (
            <div className="bg-yellow-50 border-2 border-yellow-300 rounded-lg p-4 space-y-3">
              <div className="flex items-start gap-2">
                <CheckCircle2Icon className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                <div className="flex-1">
                  <p className="font-medium text-yellow-900 mb-2">Now explain it back!</p>
                  <p className="text-sm text-yellow-800 mb-3">
                    In your own words, tell me what you learned and how you'll use it:
                  </p>
                  <textarea
                    value={explainBack}
                    onChange={(e) => setExplainBack(e.target.value)}
                    placeholder="Example: I learned that I need to use addEventListener to make the button interactive. I'll add that to my code and test it..."
                    className="w-full h-24 px-3 py-2 border border-yellow-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent"
                  />
                  <button
                    onClick={handleSubmitExplainBack}
                    disabled={!explainBack.trim() || loading}
                    className="mt-3 w-full bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
                  >
                    {loading ? 'Submitting...' : 'Submit Explanation'}
                  </button>
                </div>
              </div>
            </div>
          )}

          <button
            onClick={() => {
              trackInteraction('feature_discovered', { cta: 'ai_coach_ask_another_question' });
              setResponse(null);
              setQuestion('');
              setExplainBack('');
              setMode(null);
              setStatusMessage(null);
              setSpokenResponseStatus(null);
            }}
            className="text-sm text-gray-600 hover:text-gray-900"
          >
            ← Ask another question
          </button>
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-800">
          {error}
        </div>
      )}

      {/* Safety Reminder */}
      <div className="bg-gray-50 rounded-lg p-4 text-sm text-gray-600">
        <p className="font-medium text-gray-700 mb-1">💡 Pro tip:</p>
        <p>
          AI Help is here to help you think, not to do the work for you. 
          The best learning happens when you struggle a bit and figure things out!
        </p>
      </div>
    </div>
  );
}
