// src/voice/voice_manager.ts
import { TelemetryEmitter } from '../telemetry/emitter';
import { STTStreamer } from './stt_streamer';
import { TTSEngine } from './tts_engine';
import { TurnManager } from './turn_manager';

export interface VoiceManagerCallbacks {
  onTranscript?: (transcript: string, confidence: number) => void;
  onTurnTimeout?: (durationMs: number) => void;
  onBargeIn?: () => void;
}

export class VoiceManager {
  private emitter: TelemetryEmitter;
  private sttStreamer: STTStreamer;
  private ttsEngine: TTSEngine;
  private turnManager: TurnManager;
  private listening = false;
  private gradeBand: '1-3' | '4-6' | '7-9' | '10-12';
  private callbacks: VoiceManagerCallbacks;

  constructor(
    emitter: TelemetryEmitter,
    gradeBand: '1-3' | '4-6' | '7-9' | '10-12',
    callbacks: VoiceManagerCallbacks = {},
  ) {
    this.emitter = emitter;
    this.gradeBand = gradeBand;
    this.callbacks = callbacks;
    this.sttStreamer = new STTStreamer(emitter, {
      onFinalTranscript: (transcript, confidence) => {
        this.handleFinalTranscript(transcript, confidence);
      },
    });
    this.ttsEngine = new TTSEngine(emitter);
    this.turnManager = new TurnManager(emitter, gradeBand);
  }

  // Start voice interaction
  async startListening(): Promise<void> {
    this.ttsEngine.stop({ emitBargeIn: false });
    console.log('Starting voice listening...');
    await this.sttStreamer.startStream();
    this.listening = true;
  }

  // Stop voice interaction
  stopListening(): void {
    console.log('Stopping voice listening...');
    this.sttStreamer.stopStream();
    this.listening = false;
  }

  // Speak a response
  async speak(text: string): Promise<void> {
    if (this.listening) {
      this.sttStreamer.stopStream();
      this.listening = false;
    }

    const adaptedText = this.adaptForGradeBand(text);
    console.log('Speaking:', adaptedText);
    await this.ttsEngine.speak(adaptedText);
  }

  // Handle learner barge-in during TTS
  bargeIn(): void {
    this.ttsEngine.stop({ emitBargeIn: true });
    this.callbacks.onBargeIn?.();
    void this.startListening();
  }

  // Handle silence detection
  detectSilence(duration: number): void {
    const timedOut = this.turnManager.detectSilence(duration);
    if (timedOut) {
      this.callbacks.onTurnTimeout?.(duration);
    }
  }

  private handleFinalTranscript(transcript: string, confidence: number): void {
    this.callbacks.onTranscript?.(transcript, confidence);
  }

  private adaptForGradeBand(text: string): string {
    const trimmed = text.trim();
    if (!trimmed) {
      return trimmed;
    }

    if (this.gradeBand === '1-3') {
      return this.makeFriendlySimple(trimmed);
    }

    if (this.gradeBand === '4-6') {
      return this.makeFriendlyStructured(trimmed);
    }

    return trimmed;
  }

  private makeFriendlySimple(text: string): string {
    const cleaned = text
      .replace(/\btherefore\b/gi, 'so')
      .replace(/\butilize\b/gi, 'use')
      .replace(/\bapproximately\b/gi, 'about')
      .replace(/\bconsequently\b/gi, 'so');

    if (/\b(great|nice|awesome|good job)\b/i.test(cleaned)) {
      return cleaned;
    }

    return `Great thinking! ${cleaned} Let's do one small next step together.`;
  }

  private makeFriendlyStructured(text: string): string {
    if (/\bnext step\b/i.test(text)) {
      return text;
    }

    return `${text} Next step: try one part and tell me what you notice.`;
  }
}