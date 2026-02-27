// src/safety/safe_mode_handler.ts
import { ConsentManager } from './consent_manager';
import { TelemetryEmitter } from '../telemetry/emitter';

export class SafeModeHandler {
  private consentManager: ConsentManager;
  private emitter: TelemetryEmitter;

  constructor(consentManager: ConsentManager, emitter: TelemetryEmitter) {
    this.consentManager = consentManager;
    this.emitter = emitter;
  }

  // Activate safe mode if needed
  activateSafeMode(): void {
    if (this.consentManager.shouldActivateSafeMode()) {
      this.emitter.emit({
        event_name: 'SAFE_MODE_ACTIVATED',
        payload: {
          reason: 'consent_revoked'
        }
      });
    }
  }

  // Check for hallucination risk
  checkHallucinationRisk(transcript: string): boolean {
    // Simple check for common hallucination patterns
    const hallucinationIndicators = [
      'I am not sure', 'I don\'t know', 'I think I might be wrong'
    ];

    return hallucinationIndicators.some(indicator => 
      transcript.toLowerCase().includes(indicator)
    );
  }
}