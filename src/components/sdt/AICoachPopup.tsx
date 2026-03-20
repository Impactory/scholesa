'use client';

/**
 * AI Coach Popup
 * 
 * Floating assistant in bottom-right corner
 * - Voice-first input and auto-submit
 * - Spoken response when available
 * - Age-appropriate modes based on GradeBandPolicy
 */

import React, { useState, useEffect, useRef } from 'react';
import {
  MessageCircleIcon,
  MicIcon,
  XIcon,
  LightbulbIcon,
  ClipboardCheckIcon,
  BugIcon,
  SparklesIcon,
  Volume2Icon
} from 'lucide-react';
import { getPolicyForGrade, getAICoachModesForGrade } from '@/src/lib/policies/gradeBandPolicy';
import { useAITracking, useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { AIServiceResponse } from '@/src/lib/ai/aiService';
import { recordAIFeedback } from '@/src/lib/ai/interactionLogger';
import { localizedServiceUnavailable } from '@/src/lib/ai/multilingualGuardrails';
import { sdtMotivation } from '@/src/lib/motivation/sdtMotivation';
import { TelemetryService } from '@/src/lib/telemetry/telemetryService';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { sendCopilotVoiceMessage, transcribeVoiceAudio, voiceApiConfigured } from '@/src/lib/voice/voiceService';
import type { UserRole } from '@/src/types/user';

interface AICoachPopupProps {
  actorId: string;
  actorRole: UserRole;
  actorDisplayName: string;
  siteId: string;
  grade: number;
  studentLevel?: 'emerging' | 'proficient' | 'advanced';
  sprintSessionId?: string;
  missionId?: string;
  selectedLearnerId?: string;
  linkedLearnerIds?: string[];
  linkedParentIds?: string[];
  linkedEducatorIds?: string[];
}

type CoachMode = 'hint' | 'rubric_check' | 'debug' | 'critique';

type VoiceTransparencyMeta = CopilotVoiceResponse['metadata'];

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

function buildVoiceTransparencyMessage(metadata: VoiceTransparencyMeta): string | null {
  const understandingSource = metadata.understandingSource ?? null;
  const responseGenerationSource = metadata.responseGenerationSource ?? null;
  const understandingConfidence = metadata.understanding?.confidence ?? null;

  if (responseGenerationSource === 'guardrail' && understandingSource === 'heuristic') {
    return 'MiloOS is being careful here because it could not understand the voice request clearly enough yet.';
  }
  if (responseGenerationSource === 'local' && understandingSource === 'heuristic') {
    return 'MiloOS answered with a simple local hint because it could not confirm the voice request clearly. Treat this as a prompt to think, not a verified reading of what you meant.';
  }
  if (responseGenerationSource === 'model' && understandingSource === 'heuristic') {
    return 'MiloOS used the model to write the reply, but it still could not confirm the voice request clearly.';
  }
  if (understandingSource === 'blended') {
    const confidenceText = typeof understandingConfidence === 'number'
      ? ` Confidence in that reading: ${Math.round(understandingConfidence * 100)}%.`
      : '';
    return `MiloOS used both a quick local check and model support to understand this voice turn.${confidenceText}`;
  }
  if (understandingSource === 'model') {
    return 'MiloOS used model support to understand this voice turn.';
  }
  return null;
}

export function AICoachPopup({
  actorId,
  actorRole,
  actorDisplayName,
  siteId,
  grade,
  studentLevel = 'proficient',
  sprintSessionId,
  missionId,
  selectedLearnerId,
  linkedLearnerIds = [],
  linkedParentIds = [],
  linkedEducatorIds = []
}: AICoachPopupProps) {
  const [isMinimized, setIsMinimized] = useState(true);
  const [mode, setMode] = useState<CoachMode | null>(null);
  const [question, setQuestion] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [response, setResponse] = useState<AIServiceResponse | null>(null);
  const [explainBack, setExplainBack] = useState('');
  const [loading, setLoading] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [voiceInputTraceId, setVoiceInputTraceId] = useState<string | null>(null);
  const [currentLogId, setCurrentLogId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [voiceTransparencyMessage, setVoiceTransparencyMessage] = useState<string | null>(null);
  const [sdtProfile, setSdtProfile] = useState<{ autonomy: number | null; competence: number | null; belonging: number | null } | null>(null);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<BlobPart[]>([]);
  const policy = getPolicyForGrade(grade);
  const availableModes = getAICoachModesForGrade(grade);
  const trackAI = useAITracking();
  const trackInteraction = useInteractionTracking();
  const { locale, t } = useI18n();
  const { user, profile } = useAuthContext();
  const modeConfig = buildModeConfig((key) => t(key));
  const intelligenceLearnerId = actorRole === 'learner' ? actorId : selectedLearnerId;
  const hasVoiceInputControl = typeof window !== 'undefined'
    && typeof MediaRecorder !== 'undefined'
    && Boolean(navigator.mediaDevices?.getUserMedia)
    && Boolean(user)
    && voiceApiConfigured();

  // Fetch learner-only SDT profile for self-scaffolding prompts.
  useEffect(() => {
    if (actorRole !== 'learner' || !intelligenceLearnerId) {
      setSdtProfile(null);
      return;
    }

    let active = true;
    const fetchSDT = async () => {
      try {
        const profile = await TelemetryService.getSDTProfile(intelligenceLearnerId, siteId);
        if (active) {
          setSdtProfile(profile);
        }
      } catch (err) {
        console.error('Failed to load SDT profile:', err);
      }
    };
    
    void fetchSDT();
    return () => {
      active = false;
    };
  }, [actorRole, intelligenceLearnerId, siteId]);

  // Recorder cleanup
  useEffect(() => {
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

    if (!canRecordAudio) {
      setResponse({
        answer: 'Voice capture is unavailable. Please sign in and ensure voice API settings are configured.',
        modelUsed: 'error',
        modelVersion: 'error',
        logId: 'error',
        promptTemplateId: 'coach.voice_unavailable',
        policyVersion: 'i18n-guardrails-2026-02-23',
        safetyOutcome: 'escalated',
        safetyReasonCode: 'voice_unavailable',
        toolCallIds: [],
        targetLocale: locale,
        gradeBand: grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : grade <= 9 ? 'grades_7_9' : 'grades_10_12',
        traceId: `ai_popup_voice_${Date.now()}`,
      });
      return;
    }

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
            siteId,
            locale,
            partial: false,
            traceId: voiceInputTraceId || undefined,
            context: buildBosVoiceContext(voiceInputTraceId),
          });
          const transcriptText = transcribed.transcript.trim();
          if (!transcriptText) {
            setStatusMessage('MiloOS could not clearly capture what you said. Please try again and speak a little more clearly.');
            return;
          }
          setStatusMessage(null);
          setQuestion(transcriptText);
          if (transcribed.metadata?.traceId) {
            setVoiceInputTraceId(transcribed.metadata.traceId);
            trackVoiceTelemetry('voice.transcribe', {
              traceId: transcribed.metadata.traceId,
              latencyMs: transcribed.metadata.latencyMs,
              partial: transcribed.metadata.partial,
            });
          }
        } catch (error) {
          console.error('Voice transcription failed in AI coach popup.', error);
          setStatusMessage(
            error instanceof Error && error.message
              ? error.message
              : 'MiloOS could not clearly capture what you said. Please try again.',
          );
        } finally {
          audioChunksRef.current = [];
          setIsTranscribing(false);
        }
      };

      recorder.start();
      setIsListening(true);
      return;
    } catch (error) {
      console.error('Microphone capture unavailable for BOS voice flow.', error);
      setResponse({
        answer: 'Microphone access is required for voice mode. Please allow microphone permission and try again.',
        modelUsed: 'error',
        modelVersion: 'error',
        logId: 'error',
        promptTemplateId: 'coach.microphone_unavailable',
        policyVersion: 'i18n-guardrails-2026-02-23',
        safetyOutcome: 'escalated',
        safetyReasonCode: 'microphone_unavailable',
        toolCallIds: [],
        targetLocale: locale,
        gradeBand: grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : grade <= 9 ? 'grades_7_9' : 'grades_10_12',
        traceId: `ai_popup_voice_${Date.now()}`,
      });
      setIsListening(false);
    }
  };

  const stopListening = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      return;
    }
    setIsListening(false);
  };

  const trackVoiceTelemetry = (
    event: 'voice.transcribe' | 'voice.message' | 'voice.tts',
    metadata: Record<string, unknown> = {},
  ) => {
    if (!user || !profile) return;
    void TelemetryService.track({
      event,
      category: 'ai_interaction',
      userId: user.uid,
      userRole: profile.role as any,
      siteId,
      metadata: {
        locale,
        surface: 'ai_coach_popup',
        actorRole,
        selectedLearnerId: selectedLearnerId || undefined,
        linkedLearnerCount: linkedLearnerIds.length || undefined,
        ...metadata,
      },
    });
  };

  const buildBosVoiceContext = (traceId?: string | null) => ({
    actorId,
    actorRole,
    learnerId: intelligenceLearnerId,
    selectedLearnerId: selectedLearnerId || (actorRole === 'learner' ? actorId : undefined),
    linkedLearnerIds: linkedLearnerIds.slice(0, 12),
    linkedParentIds: linkedParentIds.slice(0, 12),
    linkedEducatorIds: linkedEducatorIds.slice(0, 12),
    knownNames: actorDisplayName ? [actorDisplayName] : [],
    sessionOccurrenceId: sprintSessionId,
    missionId,
    contextMode: sprintSessionId ? 'in_class' : 'homework',
    conceptTags: [
      'ai_coach_popup',
      'voice',
      `role:${actorRole}`,
      mode ? `mode:${mode}` : null,
    ].filter((tag): tag is string => Boolean(tag)),
    traceId: traceId || undefined,
    voiceTraceId: traceId || undefined,
    voiceInputTraceId: traceId || undefined,
    source: 'ai_coach_popup_voice',
  });

  const handleOpenPopup = () => {
    trackInteraction('help_accessed', {
      cta: 'ai_assistant_open',
      surface: 'floating_assistant',
      locale,
      siteId,
    });
    setIsMinimized(false);
  };

  const handleMinimizePopup = () => {
    trackInteraction('feature_discovered', {
      cta: 'ai_assistant_minimize',
      surface: 'floating_assistant',
      locale,
      siteId,
    });
    setIsMinimized(true);
  };

  const handleAsk = async (questionOverride?: string) => {
    const resolvedQuestion = (questionOverride ?? question).trim();
    if (!resolvedQuestion || !mode) return;

    setQuestion(resolvedQuestion);

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

      // Build learner-only personalization from self telemetry.
      let personalizedContext = '';
      if (
        sdtProfile &&
        actorRole === 'learner' &&
        sdtProfile.autonomy != null &&
        sdtProfile.competence != null &&
        sdtProfile.belonging != null
      ) {
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
        ? `${personalizedContext}\n\nStudent Question: ${resolvedQuestion}`
        : resolvedQuestion;
      if (!user) {
        throw new Error('Authentication is required for BOS AI Coach voice flow.');
      }
      if (!voiceApiConfigured()) {
        throw new Error('Voice API is not configured; BOS AI Coach endpoint unavailable.');
      }

      const idToken = await user.getIdToken();
      const voiceResponse = await sendCopilotVoiceMessage({
        idToken,
        message: composedQuestion,
        siteId,
        locale,
        screenId: 'ai_coach_popup',
        traceId: voiceInputTraceId || undefined,
        gradeBand: grade <= 5 ? 'K-5' : grade <= 8 ? '6-8' : '9-12',
        context: {
          ...buildBosVoiceContext(voiceInputTraceId),
          taskType: taskTypeMap[mode],
          studentLevel,
          linkedLearnerCount: linkedLearnerIds.length,
          linkedParentCount: linkedParentIds.length,
          linkedEducatorCount: linkedEducatorIds.length,
        },
        voice: {
          enabled: true,
          output: true,
        },
      });

      const responseGenerationSource = voiceResponse.metadata.responseGenerationSource ?? 'local';
      const voiceModelUsed = responseGenerationSource === 'model'
        ? 'miloos_voice_model'
        : responseGenerationSource === 'guardrail'
        ? 'miloos_voice_guardrail'
        : 'miloos_voice_local_support';

      const aiResponse: AIServiceResponse = {
        answer: voiceResponse.text,
        modelUsed: voiceModelUsed,
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

      trackVoiceTelemetry('voice.message', {
        traceId: voiceResponse.metadata.traceId,
        locale: voiceResponse.metadata.locale,
        safetyOutcome: voiceResponse.metadata.safetyOutcome,
        redactionApplied: voiceResponse.metadata.redactionApplied,
        redactionCount: voiceResponse.metadata.redactionCount,
        toolsInvokedCount: voiceResponse.metadata.toolsInvoked.length,
      });

      if (voiceResponse.tts.available && voiceResponse.tts.audioUrl) {
        trackVoiceTelemetry('voice.tts', {
          traceId: voiceResponse.metadata.traceId,
          ...(voiceResponse.tts.voiceProfile
            ? { voiceProfile: voiceResponse.tts.voiceProfile }
            : {}),
        });
        const audio = new Audio(voiceResponse.tts.audioUrl);
        void audio.play().catch((error) => {
          console.error('Voice playback failed in AI coach popup:', error);
        });
      }
      setVoiceInputTraceId(voiceResponse.metadata.traceId);
      setVoiceTransparencyMessage(buildVoiceTransparencyMessage(voiceResponse.metadata));

      setResponse(aiResponse);
      setCurrentLogId(aiResponse.logId);

      // Track telemetry
      trackAI('ai_hint_requested', {
        mode,
        actorRole,
        selectedLearnerId: selectedLearnerId || undefined,
        questionLength: resolvedQuestion.length,
        missionId,
        sessionId: sprintSessionId,
        modelUsed: aiResponse.modelUsed,
        locale,
        voiceInputTraceId: voiceInputTraceId || undefined,
      });
    } catch (err) {
      console.error('AI Coach error:', err);
      const traceId = `ai_popup_${Date.now()}`;
      setResponse({
        answer: localizedServiceUnavailable(locale),
        modelUsed: 'service_guard',
        modelVersion: 'service_guard',
        logId: traceId,
        promptTemplateId: 'coach.service_guard',
        policyVersion: 'i18n-guardrails-2026-02-23',
        safetyOutcome: 'escalated',
        safetyReasonCode: 'service_error_guard',
        toolCallIds: [],
        targetLocale: locale,
        gradeBand: grade <= 3 ? 'grades_1_3' : grade <= 6 ? 'grades_4_6' : grade <= 9 ? 'grades_7_9' : 'grades_10_12',
        traceId,
      });
      setVoiceTransparencyMessage('MiloOS could not understand this voice turn reliably, so it switched to a safer fallback reply.');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitExplainBack = async () => {
    if (!explainBack.trim() || !response) return;

    const interactionId = response.traceId?.trim();
    if (actorRole !== 'learner' || !interactionId) {
      setStatusMessage('Open AI Coach from the learner workspace to record explain-back for this session.');
      return;
    }

    try {
      setLoading(true);
      setStatusMessage(null);

      if (currentLogId && currentLogId !== 'error') {
        try {
          await recordAIFeedback(currentLogId, true, 'Student completed explain-back');
        } catch (err) {
          console.warn('Failed to store explain-back feedback', err);
        }
      }

      const result = await sdtMotivation.submitExplainBack(
        actorId,
        siteId,
        interactionId,
        explainBack.trim(),
      );

      trackAI('ai_critique_requested', {
        explainBackLength: explainBack.length,
        sessionId: sprintSessionId,
        missionId,
      });

      setResponse(null);
      setQuestion('');
      setExplainBack('');
      setMode(null);
      setCurrentLogId(null);
      setStatusMessage(
        result.feedback?.trim() || 'Explain-back recorded for this AI coach session.',
      );
    } catch (err) {
      console.error('AI coach popup explain-back error:', err);
      setStatusMessage('Unable to record explain-back right now. Open the learner AI Coach screen or try again later.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!mode) return;
    const transcript = question.trim();
    if (!transcript || isListening || isTranscribing || loading || response) return;
    void handleAsk(transcript);
  }, [mode, question, isListening, isTranscribing, loading, response]);

  const reset = () => {
    setMode(null);
    setQuestion('');
    setResponse(null);
    setExplainBack('');
    setStatusMessage(null);
    setVoiceTransparencyMessage(null);
  };

  // Minimized button
  if (isMinimized) {
    return (
      <button
        onClick={handleOpenPopup}
        className="fixed bottom-6 right-6 z-50 flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-fuchsia-500 via-purple-500 to-cyan-500 shadow-2xl ring-2 ring-white/30 transition-transform hover:scale-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300"
        aria-label={t('aiCoach.openAria')}
        title={t('aiCoach.tooltip')}
      >
        <span className="absolute inset-0 rounded-full bg-gradient-to-br from-white/30 via-transparent to-transparent" />
        <MessageCircleIcon className="relative z-10 w-8 h-8 text-white" />
        <div className="absolute -top-1 -right-1 h-4 w-4 rounded-full bg-amber-400 ring-2 ring-fuchsia-600 animate-pulse" />
      </button>
    );
  }

  return (
    <div className="fixed bottom-6 right-6 w-96 bg-app-surface-raised rounded-lg shadow-2xl border border-app z-50 flex flex-col max-h-[600px]">
      {/* Header */}
      <div className="bg-gradient-to-r from-fuchsia-600 via-purple-600 to-cyan-600 rounded-t-lg p-4 flex items-center justify-between">
        <div className="flex items-center gap-2 text-white">
          <MessageCircleIcon className="w-5 h-5" />
          <h3 className="font-semibold">{t('aiCoach.title')}</h3>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleMinimizePopup}
            className="text-white hover:bg-white/20 rounded p-1 transition-colors"
            aria-label={t('aiCoach.minimizeAria')}
          >
            <XIcon className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4">
        {statusMessage ? (
          <div className="mb-4 rounded-lg border border-blue-200 bg-blue-50 p-3 text-sm text-blue-900">
            {statusMessage}
          </div>
        ) : null}
        {/* Teacher guidance notice for K-3 */}
        {policy.aiCoach.requireTeacherGuidance && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4 text-sm">
            <p className="text-yellow-800">{t('aiCoach.teacherGuidance')}</p>
          </div>
        )}

        {/* Mode selection */}
        {!mode && !response && (
          <div className="space-y-3">
            <p className="mb-3 text-sm text-app-muted">{t('aiCoach.howCanIHelp')}</p>
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
                  bg: 'hover:bg-app-surface-muted',
                  iconBg: 'bg-purple-100',
                  iconText: 'text-purple-600'
                },
                indigo: {
                  border: 'hover:border-indigo-500',
                  bg: 'hover:bg-app-surface-muted',
                  iconBg: 'bg-indigo-100',
                  iconText: 'text-indigo-600'
                },
                blue: {
                  border: 'hover:border-blue-500',
                  bg: 'hover:bg-app-surface-muted',
                  iconBg: 'bg-blue-100',
                  iconText: 'text-blue-600'
                },
                pink: {
                  border: 'hover:border-pink-500',
                  bg: 'hover:bg-app-surface-muted',
                  iconBg: 'bg-pink-100',
                  iconText: 'text-pink-600'
                }
              };
              
              const colors = colorClasses[config.color] || colorClasses.purple;
              
              return (
                <button
                  key={modeKey}
                  onClick={() => setMode(modeKey)}
                  className={`w-full flex items-center gap-3 p-3 rounded-lg border-2 border-app ${colors.border} ${colors.bg} transition-all text-left`}
                >
                  <div className={`w-10 h-10 ${colors.iconBg} rounded-lg flex items-center justify-center flex-shrink-0`}>
                    <Icon className={`w-5 h-5 ${colors.iconText}`} />
                  </div>
                  <div>
                    <p className="font-medium text-app-foreground">{config.label}</p>
                    <p className="text-xs text-app-muted">{config.placeholder}</p>
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
              className="text-sm text-app-muted hover:text-app-foreground"
            >
              {t('aiCoach.back')}
            </button>

            <div className="rounded-lg border border-app bg-app-surface-muted p-3">
              <label className="mb-2 block text-sm font-medium text-app-foreground">
                {modeConfig[mode].placeholder}
              </label>
              <p className="text-xs text-app-muted">
                {hasVoiceInputControl
                  ? t('aiCoach.speakQuestion')
                  : t('aiCoach.questionPlaceholder')}
              </p>
              <p className="mt-2 min-h-10 rounded-lg bg-app-surface px-3 py-2 text-sm text-app-foreground">
                {question || '...'}
              </p>
            </div>

            {/* Speech input button */}
            <button
              onClick={isListening ? stopListening : startListening}
              disabled={!hasVoiceInputControl || loading || isTranscribing}
              className={`w-full flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium transition-colors ${
                isListening
                  ? 'bg-red-600 text-white hover:bg-red-700'
                  : 'bg-gradient-to-r from-fuchsia-600 via-purple-600 to-cyan-600 text-white hover:opacity-95 disabled:cursor-not-allowed disabled:opacity-50'
              }`}
            >
              {isListening ? (
                <>
                  <Volume2Icon className="w-5 h-5 animate-pulse" />
                  <span>{t('aiCoach.listening')}</span>
                </>
              ) : isTranscribing ? (
                <>
                  <div className="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  <span>{t('aiCoach.thinking')}</span>
                </>
              ) : loading ? (
                <>
                  <div className="h-5 w-5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  <span>{t('aiCoach.thinking')}</span>
                </>
              ) : (
                <>
                  <MicIcon className="w-5 h-5" />
                  <span>{t('aiCoach.speakQuestion')}</span>
                </>
              )}
            </button>

            {!hasVoiceInputControl && (
              <p className="text-xs text-red-500">{t('aiCoach.voiceRequirements')}</p>
            )}
          </div>
        )}

        {/* AI Response */}
        {response && (
          <div className="space-y-3">
            <div className="bg-purple-50 rounded-lg p-3 text-sm">
              <p className="font-medium text-purple-900 mb-2">{t('aiCoach.responseLabel')}</p>
              <p className="whitespace-pre-wrap text-app-foreground">{response.answer}</p>
              
              {/* Model attribution */}
              {response.modelUsed === 'miloos_voice_model' && response.modelVersion && (
                <p className="mt-2 text-xs text-app-muted">
                  {t('aiCoach.poweredBy', { model: response.modelUsed })}
                </p>
              )}
            </div>

            {voiceTransparencyMessage ? (
              <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">
                {voiceTransparencyMessage}
              </div>
            ) : null}

            {/* Feedback buttons (was this helpful?) */}
            {currentLogId && currentLogId !== 'error' && (
              <div className="flex items-center gap-2 text-sm">
                <span className="text-app-muted">{t('aiCoach.wasHelpful')}</span>
                <button
                  onClick={async () => {
                    try {
                      await recordAIFeedback(currentLogId, true, 'Student marked helpful');
                    } catch (err) {
                      console.warn('Failed to store helpful feedback', err);
                    }
                    setStatusMessage(t('aiCoach.feedbackThanks'));
                  }}
                  className="px-3 py-1 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors"
                >
                  {t('aiCoach.helpfulYes')}
                </button>
                <button
                  onClick={async () => {
                    try {
                      await recordAIFeedback(currentLogId, false, 'Student marked not helpful');
                    } catch (err) {
                      console.warn('Failed to store not-helpful feedback', err);
                    }
                    setStatusMessage(t('aiCoach.feedbackTryDifferent'));
                  }}
                  className="px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                >
                  {t('aiCoach.helpfulNo')}
                </button>
              </div>
            )}

            {/* Citations (if any) */}
            {response.citations && response.citations.length > 0 && (
              <div className="space-y-2 rounded-lg bg-app-surface-muted p-3 text-sm">
                <p className="font-medium text-app-foreground">{t('aiCoach.basedOn')}</p>
                {response.citations.map((citation, idx) => (
                  <div key={idx} className="text-xs text-app-muted">
                    • {citation.type || 'Context unavailable'}: {citation.snippet}
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
            {actorRole === 'learner' && policy.aiCoach.explainBackRequired && (
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
                  disabled={!explainBack.trim() || loading}
                  className="w-full rounded-lg bg-yellow-600 px-4 py-2 text-sm font-medium text-white hover:bg-yellow-700 disabled:bg-app-surface-muted disabled:text-app-muted"
                >
                  {loading ? 'Submitting...' : t('aiCoach.submitExplanation')}
                </button>
              </div>
            )}

            <button
              onClick={reset}
              className="text-sm text-app-muted hover:text-app-foreground"
            >
              {t('aiCoach.askAnother')}
            </button>
          </div>
        )}
      </div>

      {/* Footer tip */}
      <div className="border-t border-app p-3 bg-app-surface-muted rounded-b-lg">
        <p className="text-xs text-app-muted text-center">
          {t('aiCoach.footerTip')}
        </p>
      </div>
    </div>
  );
}
