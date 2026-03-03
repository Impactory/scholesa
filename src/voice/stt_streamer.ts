// src/voice/stt_streamer.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export interface STTStreamerCallbacks {
  onFinalTranscript?: (transcript: string, confidence: number) => void;
}

export class STTStreamer {
  private emitter: TelemetryEmitter;
  private partialResultTimer: ReturnType<typeof setTimeout> | null = null;
  private partialTimer: ReturnType<typeof setTimeout> | null = null;
  private streaming = false;
  private callbacks: STTStreamerCallbacks;

  constructor(emitter: TelemetryEmitter, callbacks: STTStreamerCallbacks = {}) {
    this.emitter = emitter;
    this.callbacks = callbacks;
  }

  // Simulate streaming STT
  async startStream(): Promise<void> {
    this.stopStream({ emitStopEvent: false });
    this.streaming = true;

    this.emitter.emit({
      event_name: 'stt_stream_started',
      payload: {}
    });

    // Simulate partial results
    this.partialResultTimer = setTimeout(() => {
      if (!this.streaming) {
        return;
      }
      this.emitter.emit({
        event_name: 'stt_stream_partial',
        payload: {
          transcript: 'I think the answer is',
          confidence: 0.72
        }
      });
      this.partialResultTimer = null;
    }, 300);

    this.partialTimer = setTimeout(() => {
      if (!this.streaming) {
        return;
      }

      const finalTranscript = 'I think the answer is photosynthesis.';
      const finalConfidence = 0.91;

      this.emitter.emit({
        event_name: 'stt_final_transcript',
        payload: {
          transcript: finalTranscript,
          duration_ms: 900
        }
      });
      this.emitter.emit({
        event_name: 'stt_confidence_scored',
        payload: {
          confidence: finalConfidence
        }
      });
      this.callbacks.onFinalTranscript?.(finalTranscript, finalConfidence);
      this.streaming = false;
      this.partialTimer = null;
    }, 900);
  }

  stopStream(options: { emitStopEvent?: boolean } = {}): void {
    if (this.partialResultTimer) {
      clearTimeout(this.partialResultTimer);
      this.partialResultTimer = null;
    }

    if (this.partialTimer) {
      clearTimeout(this.partialTimer);
      this.partialTimer = null;
    }

    const shouldEmitStopEvent = options.emitStopEvent ?? this.streaming;
    this.streaming = false;

    if (shouldEmitStopEvent) {
      this.emitter.emit({
        event_name: 'stt_stream_stopped',
        payload: {}
      });
    }
  }
}