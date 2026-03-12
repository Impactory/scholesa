// src/safety/consent_manager.ts
export class ConsentManager {
  private consentState: 'unknown' | 'granted' | 'revoked';

  constructor() {
    this.consentState = 'unknown';
  }

  // Set consent state
  setConsent(state: 'unknown' | 'granted' | 'revoked'): void {
    this.consentState = state;
  }

  // Check if consent is granted
  isConsentGranted(): boolean {
    return this.consentState === 'granted';
  }

  // Check if safe mode should be activated
  shouldActivateSafeMode(): boolean {
    return this.consentState === 'revoked';
  }
}