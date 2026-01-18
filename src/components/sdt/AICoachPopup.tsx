'use client';

/**
 * AI Coach Popup
 * 
 * Floating assistant in bottom-right corner
 * - Speech input (for younger learners)
 * - Text input (for older learners)
 * - Age-appropriate modes based on GradeBandPolicy
 */

import React, { useState, useEffect, useRef } from 'react';
import {
  MessageCircleIcon,
  MicIcon,
  SendIcon,
  XIcon,
  LightbulbIcon,
  ClipboardCheckIcon,
  BugIcon,
  SparklesIcon,
  Volume2Icon
} from 'lucide-react';
import { getPolicyForGrade, getAICoachModesForGrade } from '@/src/lib/policies/gradeBandPolicy';
import { useAITracking } from '@/src/hooks/useTelemetry';
import { AIService, recordFeedback as recordAIFeedback } from '@/src/lib/ai/aiService';
import type { AIServiceResponse } from '@/src/lib/ai/aiService';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';

// TypeScript declarations for Web Speech API
interface SpeechRecognition extends EventTarget {
  continuous: boolean;
  interimResults: boolean;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: Event) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
}

interface SpeechRecognitionEvent extends Event {
  results: SpeechRecognitionResultList;
}

interface SpeechRecognitionResultList {
  readonly length: number;
  item(index: number): SpeechRecognitionResult;
  [index: number]: SpeechRecognitionResult;
}

interface SpeechRecognitionResult {
  readonly length: number;
  item(index: number): SpeechRecognitionAlternative;
  [index: number]: SpeechRecognitionAlternative;
  isFinal: boolean;
}

interface SpeechRecognitionAlternative {
  transcript: string;
  confidence: number;
}

declare global {
  interface Window {
    SpeechRecognition?: new () => SpeechRecognition;
    webkitSpeechRecognition?: new () => SpeechRecognition;
  }
}

interface AICoachPopupProps {
  learnerId: string;
  studentName: string;
  siteId: string;
  grade: number;
  studentLevel?: 'emerging' | 'proficient' | 'advanced';
  sprintSessionId?: string;
  missionId?: string;
}

type CoachMode = 'hint' | 'rubric_check' | 'debug' | 'critique';

const MODE_CONFIG = {
  hint: {
    icon: LightbulbIcon,
    label: 'Get a Hint',
    color: 'purple',
    placeholder: 'What are you stuck on?'
  },
  rubric_check: {
    icon: ClipboardCheckIcon,
    label: 'Check My Work',
    color: 'indigo',
    placeholder: 'What did you complete?'
  },
  debug: {
    icon: BugIcon,
    label: 'Help Me Debug',
    color: 'blue',
    placeholder: 'What\'s not working?'
  },
  critique: {
    icon: SparklesIcon,
    label: 'Give Feedback',
    color: 'pink',
    placeholder: 'What would you like feedback on?'
  }
};

export function AICoachPopup({
  learnerId,
  studentName,
  siteId,
  grade,
  studentLevel = 'proficient',
  sprintSessionId,
  missionId
}: AICoachPopupProps) {
  const [isMinimized, setIsMinimized] = useState(true);
  const [mode, setMode] = useState<CoachMode | null>(null);
  const [question, setQuestion] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [response, setResponse] = useState<AIServiceResponse | null>(null);
  const [explainBack, setExplainBack] = useState('');
  const [loading, setLoading] = useState(false);
  const [currentLogId, setCurrentLogId] = useState<string | null>(null);
  const [sdtProfile, setSdtProfile] = useState<{ autonomy: number; competence: number; belonging: number } | null>(null);
  
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const policy = getPolicyForGrade(grade);
  const availableModes = getAICoachModesForGrade(grade);
  const trackAI = useAITracking();

  // Fetch SDT profile for personalization
  useEffect(() => {
    const fetchSDT = async () => {
      try {
        const profile = await TelemetryService.getSDTProfile(learnerId, siteId);
        setSdtProfile(profile);
      } catch (err) {
        console.error('Failed to load SDT profile:', err);
      }
    };
    
    fetchSDT();
  }, [learnerId, siteId]);

  // Initialize speech recognition
  useEffect(() => {
    if (typeof window !== 'undefined' && 'webkitSpeechRecognition' in window) {
      const SpeechRecognitionAPI = (window as WindowWithSpeech).webkitSpeechRecognition || (window as WindowWithSpeech).SpeechRecognition;
      if (!SpeechRecognitionAPI) return;
      
      recognitionRef.current = new SpeechRecognitionAPI();
      recognitionRef.current.continuous = false;
      recognitionRef.current.interimResults = false;
      
      recognitionRef.current.onresult = (event: SpeechRecognitionEvent) => {
        const transcript = event.results[0][0].transcript;
        setQuestion(prev => prev + ' ' + transcript);
        setIsListening(false);
      };
      
      recognitionRef.current.onerror = () => {
        setIsListening(false);
      };
      
      recognitionRef.current.onend = () => {
        setIsListening(false);
      };
    }
  }, []);

  const startListening = () => {
    if (recognitionRef.current) {
      setIsListening(true);
      recognitionRef.current.start();
    }
  };

  const stopListening = () => {
    if (recognitionRef.current && isListening) {
      recognitionRef.current.stop();
      setIsListening(false);
    }
  };

  const handleAsk = async () => {
    if (!question.trim() || !mode) return;

    try {
      setLoading(true);

      // Map mode to task type
      const taskTypeMap = {
        hint: 'hint_generation' as const,
        rubric_check: 'rubric_check' as const,
        debug: 'debug_assistance' as const,
        critique: 'critique_feedback' as const
      };

      // Build personalized context from SDT profile
      let personalizedContext = '';
      if (sdtProfile) {
        const weakDimensions: string[] = [];
        if (sdtProfile.autonomy < 40) weakDimensions.push('autonomy (needs choice-making support)');
        if (sdtProfile.competence < 40) weakDimensions.push('competence (needs skill-building)');
        if (sdtProfile.belonging < 40) weakDimensions.push('belonging (needs community connection)');
        
        const strongDimensions: string[] = [];
        if (sdtProfile.autonomy >= 70) strongDimensions.push('autonomy');
        if (sdtProfile.competence >= 70) strongDimensions.push('competence');
        if (sdtProfile.belonging >= 70) strongDimensions.push('belonging');
        
        personalizedContext = `
Student Motivation Profile:
- Autonomy: ${sdtProfile.autonomy}%
- Competence: ${sdtProfile.competence}%
- Belonging: ${sdtProfile.belonging}%

${weakDimensions.length > 0 ? `Areas needing support: ${weakDimensions.join(', ')}` : ''}
${strongDimensions.length > 0 ? `Strong areas: ${strongDimensions.join(', ')}` : ''}

Guidance: ${
  weakDimensions.includes('autonomy (needs choice-making support)')
    ? 'Offer choices and let them decide next steps. '
    : ''
}${
  weakDimensions.includes('competence (needs skill-building)')
    ? 'Break down skills into smaller steps and celebrate progress. '
    : ''
}${
  weakDimensions.includes('belonging (needs community connection)')
    ? 'Encourage peer collaboration and recognition. '
    : ''
}`;
      }

      // Call new AI service (vendor-agnostic, with redaction & retrieval)
      const aiResponse = await AIService.request({
        learnerId,
        studentName,
        siteId,
        grade,
        studentLevel,
        sessionId: sprintSessionId,
        missionId,
        taskType: taskTypeMap[mode],
        question: personalizedContext 
          ? `${personalizedContext}\n\nStudent Question: ${question}`
          : question
      });

      setResponse(aiResponse);
      setCurrentLogId(aiResponse.logId);

      // Track telemetry
      trackAI('ai_hint_requested', {
        mode,
        question: question.substring(0, 100), // First 100 chars for privacy
        missionId,
        sessionId: sprintSessionId,
        modelUsed: aiResponse.modelUsed
      });
    } catch (err) {
      console.error('AI Coach error:', err);
      // Show friendly error
      setResponse({
        answer: "I'm having trouble right now. Try asking your question in a different way, or ask your teacher for help.",
        modelUsed: 'error',
        logId: 'error'
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitExplainBack = async () => {
    if (!explainBack.trim()) return;

    // Record helpful feedback to training dataset
    if (currentLogId && currentLogId !== 'error') {
      await recordAIFeedback(currentLogId, true, 'Student completed explain-back');
    }

    // Track explain-back telemetry
    trackAI('ai_critique_requested', {
      explainBackLength: explainBack.length,
      sessionId: sprintSessionId,
      missionId
    });

    // Clear and reset
    setResponse(null);
    setQuestion('');
    setExplainBack('');
    setMode(null);
    setCurrentLogId(null);
    
    // Show success
    alert('Great explanation! 🎉');
  };

  const reset = () => {
    setMode(null);
    setQuestion('');
    setResponse(null);
    setExplainBack('');
  };

  // Minimized button
  if (isMinimized) {
    return (
      <button
        onClick={() => setIsMinimized(false)}
        className="fixed bottom-6 right-6 w-16 h-16 bg-gradient-to-br from-purple-600 to-indigo-600 rounded-full shadow-lg hover:shadow-xl transition-all hover:scale-110 flex items-center justify-center z-50 group"
        aria-label="Open AI Coach"
      >
        <MessageCircleIcon className="w-8 h-8 text-white" />
        <div className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full animate-pulse"></div>
        
        {/* Tooltip */}
        <div className="absolute bottom-full right-0 mb-2 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
          Ask AI Coach
        </div>
      </button>
    );
  }

  return (
    <div className="fixed bottom-6 right-6 w-96 bg-white rounded-lg shadow-2xl border border-gray-200 z-50 flex flex-col max-h-[600px]">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-t-lg p-4 flex items-center justify-between">
        <div className="flex items-center gap-2 text-white">
          <MessageCircleIcon className="w-5 h-5" />
          <h3 className="font-semibold">AI Coach</h3>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setIsMinimized(true)}
            className="text-white hover:bg-white/20 rounded p-1 transition-colors"
            aria-label="Minimize"
          >
            <XIcon className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4">
        {/* Teacher guidance notice for K-3 */}
        {policy.aiCoach.requireTeacherGuidance && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4 text-sm">
            <p className="text-yellow-800">💡 Ask your teacher before using AI Coach!</p>
          </div>
        )}

        {/* Mode selection */}
        {!mode && !response && (
          <div className="space-y-3">
            <p className="text-sm text-gray-600 mb-3">How can I help you today?</p>
            {availableModes.map((modeKey) => {
              const config = MODE_CONFIG[modeKey];
              const Icon = config.icon;
              
              // Static color classes
              const colorClasses: Record<string, {
                border: string;
                bg: string;
                iconBg: string;
                iconText: string;
              }> = {
                purple: {
                  border: 'hover:border-purple-500',
                  bg: 'hover:bg-purple-50',
                  iconBg: 'bg-purple-100',
                  iconText: 'text-purple-600'
                },
                indigo: {
                  border: 'hover:border-indigo-500',
                  bg: 'hover:bg-indigo-50',
                  iconBg: 'bg-indigo-100',
                  iconText: 'text-indigo-600'
                },
                blue: {
                  border: 'hover:border-blue-500',
                  bg: 'hover:bg-blue-50',
                  iconBg: 'bg-blue-100',
                  iconText: 'text-blue-600'
                },
                pink: {
                  border: 'hover:border-pink-500',
                  bg: 'hover:bg-pink-50',
                  iconBg: 'bg-pink-100',
                  iconText: 'text-pink-600'
                }
              };
              
              const colors = colorClasses[config.color] || colorClasses.purple;
              
              return (
                <button
                  key={modeKey}
                  onClick={() => setMode(modeKey)}
                  className={`w-full flex items-center gap-3 p-3 rounded-lg border-2 ${colors.border} ${colors.bg} transition-all text-left`}
                >
                  <div className={`w-10 h-10 ${colors.iconBg} rounded-lg flex items-center justify-center flex-shrink-0`}>
                    <Icon className={`w-5 h-5 ${colors.iconText}`} />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">{config.label}</p>
                    <p className="text-xs text-gray-600">{config.placeholder}</p>
                  </div>
                </button>
              );
            })}
          </div>
        )}

        {/* Question input */}
        {mode && !response && (
          <div className="space-y-3">
            <button
              onClick={reset}
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              ← Back
            </button>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                {MODE_CONFIG[mode].placeholder}
              </label>
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder="Type your question or use the microphone..."
                className="w-full h-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none text-sm"
                disabled={loading}
              />
            </div>

            {/* Speech input button */}
            {recognitionRef.current && (
              <button
                onClick={isListening ? stopListening : startListening}
                disabled={loading}
                className={`w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium transition-colors ${
                  isListening
                    ? 'bg-red-600 text-white hover:bg-red-700'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {isListening ? (
                  <>
                    <Volume2Icon className="w-5 h-5 animate-pulse" />
                    <span>Listening...</span>
                  </>
                ) : (
                  <>
                    <MicIcon className="w-5 h-5" />
                    <span>Speak Your Question</span>
                  </>
                )}
              </button>
            )}

            {/* Send button */}
            <button
              onClick={handleAsk}
              disabled={!question.trim() || loading}
              className="w-full bg-purple-600 text-white px-4 py-3 rounded-lg font-medium hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                  <span>Thinking...</span>
                </>
              ) : (
                <>
                  <SendIcon className="w-5 h-5" />
                  <span>Ask</span>
                </>
              )}
            </button>
          </div>
        )}

        {/* AI Response */}
        {response && (
          <div className="space-y-3">
            <div className="bg-purple-50 rounded-lg p-3 text-sm">
              <p className="font-medium text-purple-900 mb-2">AI Coach:</p>
              <p className="text-gray-700 whitespace-pre-wrap">{response.answer}</p>
              
              {/* Model attribution */}
              {response.modelUsed && response.modelUsed !== 'error' && (
                <p className="text-xs text-gray-500 mt-2">Powered by {response.modelUsed}</p>
              )}
            </div>

            {/* Feedback buttons (was this helpful?) */}
            {currentLogId && currentLogId !== 'error' && (
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-600">Was this helpful?</span>
                <button
                  onClick={async () => {
                    await recordAIFeedback(currentLogId, true, 'Student marked helpful');
                    alert('Thanks for the feedback! 👍');
                  }}
                  className="px-3 py-1 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors"
                >
                  👍 Yes
                </button>
                <button
                  onClick={async () => {
                    await recordAIFeedback(currentLogId, false, 'Student marked not helpful');
                    alert('Thanks for letting us know. Try asking differently.');
                  }}
                  className="px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                >
                  👎 No
                </button>
              </div>
            )}

            {/* Citations (if any) */}
            {response.citations && response.citations.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 space-y-2 text-sm">
                <p className="font-medium text-gray-900">Based on:</p>
                {response.citations.map((citation, idx) => (
                  <div key={idx} className="text-gray-700 text-xs">
                    • {citation.type}: {citation.title}
                  </div>
                ))}
              </div>
            )}

            {/* Next steps */}
            {response.suggestedNextSteps && response.suggestedNextSteps.length > 0 && (
              <div className="bg-blue-50 rounded-lg p-3 text-sm">
                <p className="font-medium text-blue-900 mb-2">Try these next:</p>
                <ul className="list-disc list-inside space-y-1 text-blue-800 text-xs">
                  {response.suggestedNextSteps.map((step, idx) => (
                    <li key={idx}>{step}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Explain-it-back (if required by policy) */}
            {response.requiresExplainBack && policy.aiCoach.explainBackRequired && (
              <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-3 space-y-2">
                <p className="font-medium text-yellow-900 text-sm">Now explain it back!</p>
                <textarea
                  value={explainBack}
                  onChange={(e) => setExplainBack(e.target.value)}
                  placeholder="Tell me what you learned..."
                  className="w-full h-20 px-3 py-2 border border-yellow-300 rounded-lg text-sm resize-none"
                />
                <button
                  onClick={handleSubmitExplainBack}
                  disabled={!explainBack.trim()}
                  className="w-full bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 disabled:bg-gray-300 text-sm"
                >
                  Submit Explanation
                </button>
              </div>
            )}

            <button
              onClick={reset}
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              ← Ask another question
            </button>
          </div>
        )}
      </div>

      {/* Footer tip */}
      <div className="border-t border-gray-200 p-3 bg-gray-50 rounded-b-lg">
        <p className="text-xs text-gray-600 text-center">
          💡 Remember: AI helps you think, not do the work!
        </p>
      </div>
    </div>
  );
}
