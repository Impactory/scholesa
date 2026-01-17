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
import { sdtMotivation, type AICoachRequest, type AICoachResponse } from '@/src/lib/motivation/sdtMotivation';
import { getPolicyForGrade, getAICoachModesForGrade } from '@/src/lib/policies/gradeBandPolicy';
import { trackAICoachUse } from '@/src/lib/telemetry/sdtTelemetry';

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
  siteId: string;
  grade: number;
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
  siteId,
  grade,
  sprintSessionId,
  missionId
}: AICoachPopupProps) {
  const [isMinimized, setIsMinimized] = useState(true);
  const [mode, setMode] = useState<CoachMode | null>(null);
  const [question, setQuestion] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [response, setResponse] = useState<AICoachResponse | null>(null);
  const [explainBack, setExplainBack] = useState('');
  const [loading, setLoading] = useState(false);
  
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const policy = getPolicyForGrade(grade);
  const availableModes = getAICoachModesForGrade(grade);

  // Initialize speech recognition
  useEffect(() => {
    if (typeof window !== 'undefined' && 'webkitSpeechRecognition' in window) {
      const SpeechRecognitionAPI = window.webkitSpeechRecognition || window.SpeechRecognition;
      if (!SpeechRecognitionAPI) return;
      
      recognitionRef.current = new SpeechRecognitionAPI();
      recognitionRef.current.continuous = false;
      recognitionRef.current.interimResults = false;
      
      recognitionRef.current.onresult = (event) => {
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

      const request: AICoachRequest = {
        mode,
        studentQuestion: question,
        context: {
          missionId,
          sprintId: sprintSessionId
        }
      };

      const aiResponse = await sdtMotivation.requestAICoach(learnerId, siteId, request);
      setResponse(aiResponse);

      // Track telemetry
      if (sprintSessionId) {
        await trackAICoachUse(
          learnerId,
          siteId,
          grade,
          sprintSessionId,
          mode,
          false // explain-back tracked separately
        );
      }
    } catch (err) {
      console.error('AI Coach error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitExplainBack = async () => {
    if (!explainBack.trim()) return;

    // Track explain-back telemetry
    if (sprintSessionId) {
      await trackAICoachUse(learnerId, siteId, grade, sprintSessionId, mode || 'hint', true);
    }

    // Clear and reset
    setResponse(null);
    setQuestion('');
    setExplainBack('');
    setMode(null);
    
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
              <p className="text-gray-700 whitespace-pre-wrap">{response.response}</p>
            </div>

            {/* Rubric alignment */}
            {response.rubricAlignment && response.rubricAlignment.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 space-y-2 text-sm">
                <p className="font-medium text-gray-900">How you're doing:</p>
                {response.rubricAlignment.map((item, idx) => (
                  <div key={idx}>
                    <p className="font-medium text-gray-700">{item.criterion}</p>
                    <p className="text-gray-600 text-xs">
                      Current: {item.currentLevel} → Target: {item.targetLevel}
                    </p>
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
