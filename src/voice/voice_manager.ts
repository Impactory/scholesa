// src/voice/voice_manager.ts
import { TelemetryEmitter } from '../telemetry/emitter';
import { STTStreamer } from './stt_streamer';
import { TTSEngine } from './tts_engine';
import { TurnManager } from './turn_manager';

export class VoiceManager {
  private emitter: TelemetryEmitter;
  private sttStreamer: STTStreamer;
  private ttsEngine: TTSEngine;
  private turnManager: TurnManager;

  constructor(emitter: TelemetryEmitter, gradeBand: '1-3' | '4-6' | '7-9' | '10-12') {
    this.emitter = emitter;
    this.sttStreamer = new STTStreamer(emitter);
    this.ttsEngine = new TTSEngine(emitter);
    this.turnManager = new TurnManager(emitter, gradeBand);
  }

  // Start voice interaction
  async startListening(): Promise<void> {
    console.log('Starting voice listening...');
    await this.sttStreamer.startStream();
  }

  // Stop voice interaction
  stopListening(): void {
    console.log('Stopping voice listening...');
  }

  // Speak a response
  async speak(text: string): Promise<void> {
    console.log('Speaking:', text);
    await this.ttsEngine.speak(text);
  }

  // Handle silence detection
  detectSilence(duration: number): void {
    this.turnManager.detectSilence(duration);
  }
}