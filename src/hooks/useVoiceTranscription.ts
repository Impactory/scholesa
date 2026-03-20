'use client';

import { useEffect, useRef, useState } from 'react';
import { transcribeVoiceAudio, voiceApiConfigured, type TranscribeVoiceResponse } from '@/src/lib/voice/voiceService';

interface VoiceUserLike {
  getIdToken(): Promise<string>;
}

interface UseVoiceTranscriptionOptions {
  user: VoiceUserLike | null;
  siteId?: string;
  locale?: string;
  disabled?: boolean;
  getTraceId?: () => string | undefined;
  buildContext?: () => Record<string, unknown>;
  onTranscript: (payload: { transcript: string; metadata: TranscribeVoiceResponse['metadata'] }) => Promise<void> | void;
  onUnavailable: () => void;
  onCaptureError: (error: unknown) => void;
  onEmptyTranscript: () => void;
  onTranscriptionError: (error: unknown) => void;
  onListeningStarted?: () => void;
  onListeningStopped?: () => void;
}

export function useVoiceTranscription({
  user,
  siteId,
  locale,
  disabled = false,
  getTraceId,
  buildContext,
  onTranscript,
  onUnavailable,
  onCaptureError,
  onEmptyTranscript,
  onTranscriptionError,
  onListeningStarted,
  onListeningStopped,
}: UseVoiceTranscriptionOptions) {
  const [isListening, setIsListening] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<BlobPart[]>([]);

  const canUseVoiceInput = typeof window !== 'undefined'
    && typeof MediaRecorder !== 'undefined'
    && typeof navigator !== 'undefined'
    && Boolean(navigator.mediaDevices?.getUserMedia)
    && Boolean(user)
    && voiceApiConfigured();

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

  const stopListening = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
      return;
    }

    setIsListening(false);
    onListeningStopped?.();
  };

  const startListening = async () => {
    if (disabled || isTranscribing) {
      return;
    }

    if (!canUseVoiceInput) {
      onUnavailable();
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      audioChunksRef.current = [];
      const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm' });
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (event: BlobEvent) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      recorder.onerror = () => {
        setIsListening(false);
        onListeningStopped?.();
      };

      recorder.onstop = async () => {
        setIsListening(false);
        onListeningStopped?.();
        mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
        mediaStreamRef.current = null;

        if (!user || audioChunksRef.current.length === 0) {
          return;
        }

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
            traceId: getTraceId?.(),
            context: buildContext ? buildContext() : undefined,
          });

          const transcriptText = transcribed.transcript.trim();
          if (!transcriptText) {
            onEmptyTranscript();
            return;
          }

          await onTranscript({ transcript: transcriptText, metadata: transcribed.metadata });
        } catch (error) {
          onTranscriptionError(error);
        } finally {
          audioChunksRef.current = [];
          setIsTranscribing(false);
        }
      };

      recorder.start();
      setIsListening(true);
      onListeningStarted?.();
    } catch (error) {
      setIsListening(false);
      onCaptureError(error);
    }
  };

  return {
    canUseVoiceInput,
    isListening,
    isTranscribing,
    startListening,
    stopListening,
  };
}