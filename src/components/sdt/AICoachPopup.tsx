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
import { AIService } from '@/src/lib/ai/aiService';
import type { AIServiceResponse } from '@/src/lib/ai/aiService';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { sendCopilotVoiceMessage, transcribeVoiceAudio, voiceApiConfigured } from '@/src/lib/voice/voiceService';

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

function buildModeConfig(t: (key: string) => string) {
  return {
    hint: {
      icon: LightbulbIcon,
      label: t('aiCoach.mode.hint.label'),
      color: 'purple',
      placeholder: t('aiCoach.mode.hint.placeholder')
    },
    rubric_check: {
      icon: ClipboardCheckIcon,
      label: t('aiCoach.mode.rubric.label'),
      color: 'indigo',
      placeholder: t('aiCoach.mode.rubric.placeholder')
    },
    debug: {
      icon: BugIcon,
      label: t('aiCoach.mode.debug.label'),
      color: 'blue',
      placeholder: t('aiCoach.mode.debug.placeholder')
    },
    critique: {
      icon: SparklesIcon,
      label: t('aiCoach.mode.critique.label'),
      color: 'pink',
      placeholder: t('aiCoach.mode.critique.placeholder')
    }
  } satisfies Record<CoachMode, {
    icon: typeof LightbulbIcon;
    label: string;
    color: string;
    placeholder: string;
  }>;
}

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
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [currentLogId, setCurrentLogId] = useState<string | null>(null);
  const [sdtProfile, setSdtProfile] = useState<{ autonomy: number; competence: number; belonging: number } | null>(null);
  
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<BlobPart[]>([]);
  const policy = getPolicyForGrade(grade);
  const availableModes = getAICoachModesForGrade(grade);
  const trackAI = useAITracking();
  const { locale, t } = useI18n();
  const { user } = useAuthContext();
  const modeConfig = buildModeConfig((key) => t(key));
  const hasVoiceInputControl = Boolean(
    recognitionRef.current ||
    (typeof window !== 'undefined' &&
      typeof MediaRecorder !== 'undefined' &&
      Boolean(navigator.mediaDevices?.getUserMedia) &&
      user &&
      voiceApiConfigured())
  );

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

  // Initialize speech recognition fallback
  useEffect(() => {
    if (typeof window !== 'undefined' && ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window)) {
      const SpeechRecognitionAPI = window.webkitSpeechRecognition || window.SpeechRecognition;
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
    return () => {
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
      }
      mediaRecorderRef.current = null;
      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      }
      mediaStreamRef.current = null;
    };
  }, []);

  const startListening = async () => {
    if (loading || isTranscribing) return;

    const canRecordAudio = typeof window !== 'undefined'
      && typeof MediaRecorder !== 'undefined'
      && typeof navigator !== 'undefined'
      && Boolean(navigator.mediaDevices?.getUserMedia)
      && user
      && voiceApiConfigured();

    if (canRecordAudio) {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaStreamRef.current = stream;
        audioChunksRef.current = [];
        const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm' });
        mediaRecorderRef.current = recorder;

        recorder.ondataavailable = (event: BlobEvent) => {
          if (event.data.size > 0) audioChunksRef.current.push(event.data);
        };
        recorder.onerror = () => {
          setIsListening(false);
        };
        recorder.onstop = async () => {
          setIsListening(false);
          mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
          mediaStreamRef.current = null;
          if (!user || audioChunksRef.current.length === 0) return;
          setIsTranscribing(true);
          try {
            const idToken = await user.getIdToken();
            const blob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
            const transcribed = await transcribeVoiceAudio({
              idToken,
              audioBlob: blob,
              locale,
              partial: false,
            });
            setQuestion((prev) => `${prev} ${transcribed.transcript}`.trim());
          } catch (error) {
            console.error('Voice transcription failed; keeping manual input path.', error);
          } finally {
            audioChunksRef.current = [];
            setIsTranscribing(false);
          }
        };

        recorder.start();
        setIsListening(true);
        return;
      } catch (error) {
        console.error('Microphone capture unavailable; falling back to browser speech recognition.', error);
      }
    }

    if (recognitionRef.current) {
      setIsListening(true);
      recognitionRef.current.start();
    }
  };

  const stopListening = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      return;
    }
    if (recognitionRef.current && isListening) {
      recognitionRef.current.stop();
      setIsListening(false);
    }
  };

  const handleAsk = async () => {
    if (!question.trim() || !mode) return;

    try {
      setLoading(true);
      const resolvedGradeBand = grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : grade <= 9 ? 'grades_7_9' : 'grades_10_12';

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

      const composedQuestion = personalizedContext
        ? `${personalizedContext}\n\nStudent Question: ${question}`
        : question;
      let aiResponse: AIServiceResponse | null = null;

      // Primary path: voice system endpoint contract (/copilot/message)
      if (user && voiceApiConfigured()) {
        try {
          const idToken = await user.getIdToken();
          const voiceResponse = await sendCopilotVoiceMessage({
            idToken,
            message: composedQuestion,
            locale,
            screenId: 'ai_coach_popup',
            gradeBand: grade <= 5 ? 'K-5' : grade <= 8 ? '6-8' : '9-12',
            context: {
              learnerId,
              missionId,
              sprintSessionId,
            },
            voice: {
              enabled: true,
              output: true,
            },
          });

          aiResponse = {
            answer: voiceResponse.text,
            hints: voiceResponse.metadata.toolsInvoked.map((tool) => `${tool}`),
            modelUsed: 'voice-orchestrator',
            modelVersion: voiceResponse.metadata.modelVersion,
            logId: voiceResponse.metadata.traceId,
            promptTemplateId: 'voice.copilot.message',
            policyVersion: voiceResponse.metadata.policyVersion,
            safetyOutcome: voiceResponse.metadata.safetyOutcome,
            safetyReasonCode: voiceResponse.metadata.safetyReasonCode,
            toolCallIds: voiceResponse.metadata.toolsInvoked,
            targetLocale: voiceResponse.metadata.locale,
            gradeBand: resolvedGradeBand,
            traceId: voiceResponse.metadata.traceId,
            missionAttemptId: missionId,
          };

          if (voiceResponse.tts.available && voiceResponse.tts.audioUrl) {
            const audio = new Audio(voiceResponse.tts.audioUrl);
            void audio.play().catch((error) => {
              console.error('Voice playback failed in AI coach popup:', error);
            });
          }
        } catch (voiceError) {
          console.error('Voice endpoint request failed; falling back to AI service path.', voiceError);
        }
      }

      // Fallback path: existing integrated AI service
      if (!aiResponse) {
        aiResponse = await AIService.request({
          learnerId,
          studentName,
          siteId,
          grade,
          studentLevel,
          sessionId: sprintSessionId,
          missionId,
          taskType: taskTypeMap[mode],
          targetLocale: locale,
          role: 'learner',
          question: composedQuestion,
        });
      }

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
        answer: t('aiCoach.errorFallback'),
        modelUsed: 'error',
        modelVersion: 'error',
        logId: 'error',
        promptTemplateId: 'coach.error',
        policyVersion: 'i18n-guardrails-2026-02-23',
        safetyOutcome: 'escalated',
        safetyReasonCode: 'client_error',
        toolCallIds: [],
        targetLocale: locale,
        gradeBand: grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : grade <= 9 ? 'grades_7_9' : 'grades_10_12',
        traceId: `ai_popup_${Date.now()}`,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitExplainBack = async () => {
    if (!explainBack.trim()) return;

    // Record helpful feedback to analytics-only interaction log
    // TODO: Re-implement feedback recording when AI service is updated
    // if (currentLogId && currentLogId !== 'error') {
    //   await recordAIFeedback(currentLogId, true, 'Student completed explain-back');
    // }

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
    alert(t('aiCoach.explainBackSuccess'));
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
        aria-label={t('aiCoach.openAria')}
      >
        <MessageCircleIcon className="w-8 h-8 text-white" />
        <div className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full animate-pulse"></div>
        
        {/* Tooltip */}
        <div className="absolute bottom-full right-0 mb-2 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
          {t('aiCoach.tooltip')}
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
          <h3 className="font-semibold">{t('aiCoach.title')}</h3>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setIsMinimized(true)}
            className="text-white hover:bg-white/20 rounded p-1 transition-colors"
            aria-label={t('aiCoach.minimizeAria')}
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
            <p className="text-yellow-800">{t('aiCoach.teacherGuidance')}</p>
          </div>
        )}

        {/* Mode selection */}
        {!mode && !response && (
          <div className="space-y-3">
            <p className="text-sm text-gray-600 mb-3">{t('aiCoach.howCanIHelp')}</p>
            {availableModes.map((modeKey) => {
              const config = modeConfig[modeKey];
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
              {t('aiCoach.back')}
            </button>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                {modeConfig[mode].placeholder}
              </label>
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder={t('aiCoach.questionPlaceholder')}
                className="w-full h-24 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none text-sm"
                disabled={loading}
              />
            </div>

            {/* Speech input button */}
            {hasVoiceInputControl && (
              <button
                onClick={isListening ? stopListening : startListening}
                disabled={loading || isTranscribing}
                className={`w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium transition-colors ${
                  isListening
                    ? 'bg-red-600 text-white hover:bg-red-700'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {isListening ? (
                  <>
                    <Volume2Icon className="w-5 h-5 animate-pulse" />
                    <span>{t('aiCoach.listening')}</span>
                  </>
                ) : (
                  <>
                    <MicIcon className="w-5 h-5" />
                    <span>{t('aiCoach.speakQuestion')}</span>
                  </>
                )}
              </button>
            )}

            {/* Send button */}
            <button
              onClick={handleAsk}
              disabled={!question.trim() || loading || isTranscribing}
              className="w-full bg-purple-600 text-white px-4 py-3 rounded-lg font-medium hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading || isTranscribing ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                  <span>{t('aiCoach.thinking')}</span>
                </>
              ) : (
                <>
                  <SendIcon className="w-5 h-5" />
                  <span>{t('aiCoach.ask')}</span>
                </>
              )}
            </button>
          </div>
        )}

        {/* AI Response */}
        {response && (
          <div className="space-y-3">
            <div className="bg-purple-50 rounded-lg p-3 text-sm">
              <p className="font-medium text-purple-900 mb-2">{t('aiCoach.responseLabel')}</p>
              <p className="text-gray-700 whitespace-pre-wrap">{response.answer}</p>
              
              {/* Model attribution */}
              {response.modelUsed && response.modelUsed !== 'error' && (
                <p className="text-xs text-gray-500 mt-2">
                  {t('aiCoach.poweredBy', { model: response.modelUsed })}
                </p>
              )}
            </div>

            {/* Feedback buttons (was this helpful?) */}
            {currentLogId && currentLogId !== 'error' && (
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-600">{t('aiCoach.wasHelpful')}</span>
                <button
                  onClick={async () => {
                    // TODO: Re-implement feedback recording
                    // await recordAIFeedback(currentLogId, true, 'Student marked helpful');
                    alert(t('aiCoach.feedbackThanks'));
                  }}
                  className="px-3 py-1 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors"
                >
                  {t('aiCoach.helpfulYes')}
                </button>
                <button
                  onClick={async () => {
                    // TODO: Re-implement feedback recording
                    // await recordAIFeedback(currentLogId, false, 'Student marked not helpful');
                    alert(t('aiCoach.feedbackTryDifferent'));
                  }}
                  className="px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                >
                  {t('aiCoach.helpfulNo')}
                </button>
              </div>
            )}

            {/* Citations (if any) */}
            {response.citations && response.citations.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 space-y-2 text-sm">
                <p className="font-medium text-gray-900">{t('aiCoach.basedOn')}</p>
                {response.citations.map((citation, idx) => (
                  <div key={idx} className="text-gray-700 text-xs">
                    • {citation.type}: {citation.snippet}
                  </div>
                ))}
              </div>
            )}

            {/* Next steps - use hints instead of suggestedNextSteps */}
            {response.hints && response.hints.length > 0 && (
              <div className="bg-blue-50 rounded-lg p-3 text-sm">
                <p className="font-medium text-blue-900 mb-2">{t('aiCoach.tryNext')}</p>
                <ul className="list-disc list-inside space-y-1 text-blue-800 text-xs">
                  {response.hints.map((step, idx) => (
                    <li key={idx}>{step}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Explain-it-back (if required by policy) */}
            {policy.aiCoach.explainBackRequired && (
              <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-3 space-y-2">
                <p className="font-medium text-yellow-900 text-sm">{t('aiCoach.explainBackPrompt')}</p>
                <textarea
                  value={explainBack}
                  onChange={(e) => setExplainBack(e.target.value)}
                  placeholder={t('aiCoach.explainBackPlaceholder')}
                  className="w-full h-20 px-3 py-2 border border-yellow-300 rounded-lg text-sm resize-none"
                />
                <button
                  onClick={handleSubmitExplainBack}
                  disabled={!explainBack.trim()}
                  className="w-full bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 disabled:bg-gray-300 text-sm"
                >
                  {t('aiCoach.submitExplanation')}
                </button>
              </div>
            )}

            <button
              onClick={reset}
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              {t('aiCoach.askAnother')}
            </button>
          </div>
        )}
      </div>

      {/* Footer tip */}
      <div className="border-t border-gray-200 p-3 bg-gray-50 rounded-b-lg">
        <p className="text-xs text-gray-600 text-center">
          {t('aiCoach.footerTip')}
        </p>
      </div>
    </div>
  );
}
