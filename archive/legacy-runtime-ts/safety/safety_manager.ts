// src/safety/safety_manager.ts
import { ConsentManager } from './consent_manager';
import { PiiDetector } from './pii_detector';
import { TelemetryEmitter } from '../telemetry/emitter';

export class SafetyManager {
  private consentManager: ConsentManager;
  private emitter: TelemetryEmitter;

  constructor(emitter: TelemetryEmitter) {
    this.emitter = emitter;
    this.consentManager = new ConsentManager();
  }

  // Check if learner has given consent
  isConsentGranted(): boolean {
    return this.consentManager.isConsentGranted();
  }

  // Process transcript for PII
  processTranscript(transcript: string): {
    original: string;
    redacted: string;
    piiDetected: string[];
  } {
    const piiDetected = PiiDetector.detect(transcript);
    const redacted = PiiDetector.redact(transcript);
    
    this.emitter.emit({
      event_name: 'pii_detection',
      payload: {
        original: transcript,
        redacted: redacted,
        pii_detected: piiDetected
      }
    });
    
    return {
      original: transcript,
      redacted: redacted,
      piiDetected: piiDetected
    };
  }

  // Activate safe mode
  activateSafeMode(): void {
    this.consentManager.setConsent('revoked');
    this.emitter.emit({
      event_name: 'SAFE_MODE_ACTIVATED',
      payload: {
        reason: 'consent_revoked'
      }
    });
  }

  // Deactivate safe mode
  deactivateSafeMode(): void {
    this.consentManager.setConsent('granted');
    this.emitter.emit({
      event_name: 'SAFE_MODE_DEACTIVATED',
      payload: {}
    });
  }
}