'use client';

import { useEffect, useRef, useState } from 'react';
import { speakBrowserText, stopBrowserSpeech } from '@/src/lib/voice/browserSpeech';

type SpokenDeliveryMode = 'audio' | 'browser' | 'none';

interface SpokenResponsePayload {
  text: string;
  audioUrl?: string | null;
}

interface UseSpokenResponseOptions {
  locale?: string;
  audioSuccessMessage?: string;
  browserSuccessMessage?: string;
  unavailableMessage?: string;
  onAudioPlaybackError?: (error: unknown) => void;
}

export function useSpokenResponse({
  locale,
  audioSuccessMessage = 'AI Help answered out loud. Replay the spoken response if you need to hear it again.',
  browserSuccessMessage = 'AI Help answered out loud using this device audio. Replay the spoken response if you need to hear it again.',
  unavailableMessage = 'AI Help prepared a spoken response, but this device could not play it out loud. Turn on audio and try Replay.',
  onAudioPlaybackError,
}: UseSpokenResponseOptions) {
  const [spokenResponseStatus, setSpokenResponseStatus] = useState<string | null>(null);
  const [spokenResponsePayload, setSpokenResponsePayload] = useState<SpokenResponsePayload | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
      }
      audioRef.current = null;
      stopBrowserSpeech();
    };
  }, []);

  const describeDelivery = (deliveryMode: SpokenDeliveryMode): string => {
    if (deliveryMode === 'audio') {
      return audioSuccessMessage;
    }
    if (deliveryMode === 'browser') {
      return browserSuccessMessage;
    }
    return unavailableMessage;
  };

  const deliverSpokenResponse = async (text: string, audioUrl?: string | null): Promise<SpokenDeliveryMode> => {
    if (audioRef.current) {
      audioRef.current.pause();
    }
    audioRef.current = null;
    stopBrowserSpeech();

    if (audioUrl) {
      const audio = new Audio(audioUrl);
      audioRef.current = audio;
      try {
        await audio.play();
        return 'audio';
      } catch (error) {
        onAudioPlaybackError?.(error);
      }
    }

    if (speakBrowserText(text, locale)) {
      return 'browser';
    }

    return 'none';
  };

  const play = async (text: string, audioUrl?: string | null) => {
    setSpokenResponsePayload({ text, audioUrl });
    const deliveryMode = await deliverSpokenResponse(text, audioUrl);
    setSpokenResponseStatus(describeDelivery(deliveryMode));
    return deliveryMode;
  };

  const replay = async () => {
    if (!spokenResponsePayload) {
      return null;
    }
    const deliveryMode = await deliverSpokenResponse(
      spokenResponsePayload.text,
      spokenResponsePayload.audioUrl,
    );
    setSpokenResponseStatus(describeDelivery(deliveryMode));
    return deliveryMode;
  };

  const clear = () => {
    setSpokenResponseStatus(null);
    setSpokenResponsePayload(null);
  };

  return {
    spokenResponseStatus,
    spokenResponsePayload,
    play,
    replay,
    clear,
  };
}