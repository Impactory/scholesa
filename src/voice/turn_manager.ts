// src/voice/turn_manager.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export class TurnManager {
  private emitter: TelemetryEmitter;
  private silenceThreshold: number; // in ms

  constructor(emitter: TelemetryEmitter, gradeBand: '1-3' | '4-6' | '7-9' | '10-12') {
    this.emitter = emitter;
    this.silenceThreshold = this.getSilenceThreshold(gradeBand);
  }

  private getSilenceThreshold(gradeBand: '1-3' | '4-6' | '7-9' | '10-12'): number {
    switch (gradeBand) {
      case '1-3': return 3000;
      case '4-6': return 6000;
      case '7-9': return 8000;
      case '10-12': return 12000;
      default: return 6000;
    }
  }

  // Simulate silence detection
  detectSilence(duration: number): void {
    if (duration > this.silenceThreshold) {
      this.emitter.emit({
        event_name: 'turn_taking_timeout',
        payload: {
          duration: duration
        }
      });
    }
  }
}