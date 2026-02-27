// src/main.ts
import { BosController } from './bos/bos_controller';
import { TelemetryEmitter } from './telemetry/emitter';
import { ConsentManager } from './safety/consent_manager';
import { PiiDetector } from './safety/pii_detector';
import { VoiceManager } from './voice/voice_manager';
import { STTStreamer } from './voice/stt_streamer';
import { TTSEngine } from './voice/tts_engine';
import { TurnManager } from './voice/turn_manager';

// Main application entry point
class VIBEMaster {
  private bosController: BosController;
  private emitter: TelemetryEmitter;
  private consentManager: ConsentManager;
  private voiceManager: VoiceManager;

  constructor() {
    // Initialize telemetry
    this.emitter = new TelemetryEmitter(
      'learner_123', 
      'device_456', 
      'granted'
    );
    
    // Initialize components
    this.consentManager = new ConsentManager();
    this.bosController = new BosController(
      this.emitter,
      '4-6', // grade band
      'learner_123',
      'device_456'
    );
    
    this.voiceManager = new VoiceManager(this.emitter, '4-6');
  }

  // Start the VIBE Master system
  async start(): Promise<void> {
    console.log('Starting VIBE Master system...');
    
    // Emit system start event
    this.emitter.emit({
      event_name: 'system_started',
      payload: {
        version: '1.0.0',
        grade_band: '4-6'
      }
    });

    // Start voice interaction
    this.bosController.startVoiceInteraction();
    
    // Simulate learner interaction
    setTimeout(() => {
      this.bosController.handleLearnerResponse('I think 5 plus 3 equals 8.', 0.92);
    }, 2000);
    
    // Simulate state transition
    setTimeout(() => {
      this.bosController.transitionToNextState();
    }, 5000);
    
    // Simulate safe mode activation
    setTimeout(() => {
      this.bosController.activateSafeMode();
    }, 10000);
  }

  // Process learner response
  processLearnerResponse(transcript: string, confidence: number): void {
    // Detect PII
    const pii = PiiDetector.detect(transcript);
    if (pii.length > 0) {
      console.log('PII detected:', pii);
      // Redact PII
      const redacted = PiiDetector.redact(transcript);
      console.log('Redacted transcript:', redacted);
    }
    
    // Handle response through BOS
    this.bosController.handleLearnerResponse(transcript, confidence);
  }
}

// Initialize and start the system
const vibeMaster = new VIBEMaster();
vibeMaster.start();

// Export for use in other modules
export { VIBEMaster, BosController, TelemetryEmitter, ConsentManager, VoiceManager };