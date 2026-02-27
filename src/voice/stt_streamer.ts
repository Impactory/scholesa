// src/voice/stt_streamer.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export class STTStreamer {
  private emitter: TelemetryEmitter;

  constructor(emitter: TelemetryEmitter) {
    this.emitter = emitter;
  }

  // Simulate streaming STT
  async startStream(): Promise<void> {
    this.emitter.emit({
      event_name: 'stt_stream_started',
      payload: {}
    });

    // Simulate partial results
    setTimeout(() => {
      this.emitter.emit({