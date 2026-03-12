// src/voice/tts_engine.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export class TTSEngine {
  private emitter: TelemetryEmitter;
  private firstByteTimer: ReturnType<typeof setTimeout> | null = null;
  private completeTimer: ReturnType<typeof setTimeout> | null = null;
  private speaking = false;
  private onStopResolve: (() => void) | null = null;

  constructor(emitter: TelemetryEmitter) {
    this.emitter = emitter;
  }

  // Simulate TTS
  async speak(text: string): Promise<void> {
    this.stop({ emitBargeIn: false });

    this.emitter.emit({
      event_name: 'tts_request_started',
      payload: {
        text: text
      }
    });

    this.speaking = true;

    await new Promise<void>((resolve) => {
      let resolved = false;
      const finish = () => {
        if (resolved) {
          return;
        }
        resolved = true;
        this.onStopResolve = null;
        resolve();
      };

      this.onStopResolve = finish;

      // Simulate time to first byte
      this.firstByteTimer = setTimeout(() => {
        if (!this.speaking) {
          finish();
          return;
        }

        this.emitter.emit({
          event_name: 'tts_audio_first_byte',
          payload: {
            time_ms: 300
          }
        });
        this.firstByteTimer = null;
      }, 300);

      // Simulate playback
      this.completeTimer = setTimeout(() => {
        if (!this.speaking) {
          finish();
          return;
        }

        console.log('Speaking:', text);
        this.emitter.emit({
          event_name: 'tts_audio_completed',
          payload: {
            duration_ms: 1000
          }
        });
        this.speaking = false;
        this.completeTimer = null;
        finish();
      }, 1000);
    });
  }

  stop(options: { emitBargeIn?: boolean } = {}): void {
    if (this.firstByteTimer) {
      clearTimeout(this.firstByteTimer);
      this.firstByteTimer = null;
    }

    if (this.completeTimer) {
      clearTimeout(this.completeTimer);
      this.completeTimer = null;
    }

    const wasSpeaking = this.speaking;
    this.speaking = false;

    if (this.onStopResolve) {
      const finish = this.onStopResolve;
      this.onStopResolve = null;
      finish();
    }

    if ((options.emitBargeIn ?? false) && wasSpeaking) {
      this.emitter.emit({
        event_name: 'barge_in_detected',
        payload: {}
      });
    }
  }
}