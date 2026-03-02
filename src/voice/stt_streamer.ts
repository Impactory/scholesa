// src/voice/stt_streamer.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export class STTStreamer {
  private emitter: TelemetryEmitter;
  private partialTimer: ReturnType<typeof setTimeout> | null = null;

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
        event_name: 'stt_partial_result',
        payload: {
          transcript: 'I think the answer is',
          confidence: 0.72
        }
      });
    }, 300);

    this.partialTimer = setTimeout(() => {
      this.emitter.emit({
        event_name: 'stt_stream_completed',
        payload: {
          transcript: 'I think the answer is photosynthesis.',
          confidence: 0.91,
          duration_ms: 900
        }
      });
      this.partialTimer = null;
    }, 900);
  }

  stopStream(): void {
    if (this.partialTimer) {
      clearTimeout(this.partialTimer);
      this.partialTimer = null;
    }

    this.emitter.emit({
      event_name: 'stt_stream_stopped',
      payload: {}
    });
  }
}