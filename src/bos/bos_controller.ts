// src/bos/bos_controller.ts
import { TelemetryEmitter } from '../telemetry/emitter';
import { BOSStateMachine } from './state_machine';
import { ConsentManager } from '../safety/consent_manager';
import { SafeModeHandler } from '../safety/safe_mode_handler';
import { VoiceManager } from '../voice/voice_manager';

export class BosController {
  private stateMachine: BOSStateMachine;
  private emitter: TelemetryEmitter;
  private consentManager: ConsentManager;
  private safeModeHandler: SafeModeHandler;
  private voiceManager: VoiceManager;

  constructor(
    emitter: TelemetryEmitter,
    gradeBand: '1-3' | '4-6' | '7-9' | '10-12',
    learnerId: string,
    deviceId: string
  ) {
    this.emitter = emitter;
    this.stateMachine = new BOSStateMachine();
    this.consentManager = new ConsentManager();
    this.safeModeHandler = new SafeModeHandler(this.consentManager, emitter);
    this.voiceManager = new VoiceManager(emitter, gradeBand);
    
    // Initialize with granted consent
    this.consentManager.setConsent('granted');
  }

  // Handle learner response
  handleLearnerResponse(response: string, confidence: number): void {
    this.emitter.emit({
      event_name: 'learner_response_captured',
      payload: {
        modality: 'voice',
        confidence: confidence,
        redaction_flags: []
      }
    });

    // Check for hallucination risk
    if (this.safeModeHandler.checkHallucinationRisk(response)) {
      this.emitter.emit({
        event_name: 'hallucination_detected',
        payload: {
          transcript: response,
          confidence: confidence
        }
      });
    }

    // Update state machine
    const currentState = this.stateMachine.getState();
    if (currentState.state === 'INSTRUCTION' || currentState.state === 'GUIDED_PRACTICE') {
      // Simulate progress
      this.stateMachine.updateMetrics({
        mastery_delta: 0.1
      });
    }
  }

  // Transition to next state
  transitionToNextState(): void {
    const currentState = this.stateMachine.getState();
    let nextState: BOSStateMachine['state'] = currentState.state;

    switch (currentState.state) {
      case 'ONBOARDING':
        nextState = 'INSTRUCTION';
        break;
      case 'INSTRUCTION':
        nextState = 'GUIDED_PRACTICE';
        break;
      case 'GUIDED_PRACTICE':
        nextState = 'BUILD_TIME';
        break;
      case 'BUILD_TIME':
        nextState = 'CHECKPOINT';
        break;
      case 'CHECKPOINT':
        nextState = 'REFLECTION';
        break;
      case 'REFLECTION':
        nextState = 'COACHING_RECOVERY';
        break;
      case 'COACHING_RECOVERY':
        nextState = 'INSTRUCTION';
        break;
      default:
        nextState = 'INSTRUCTION';
    }

    this.stateMachine.transitionTo(nextState);
    
    this.emitter.emit({
      event_name: 'bos_state_transition',
      payload: {
        from: currentState.state,
        to: nextState,
        timestamp: Date.now()
      }
    });
  }

  // Activate safe mode
  activateSafeMode(): void {
    this.consentManager.setConsent('revoked');
    this.safeModeHandler.activateSafeMode();
    this.stateMachine.transitionTo('SAFE_MODE');
  }

  // Get current state
  getCurrentState(): BOSStateMachine['state'] {
    return this.stateMachine.getState().state;
  }

  // Get state metrics
  getStateMetrics(): BOSStateMachine['metrics'] {
    return this.stateMachine.getState().metrics;
  }

  // Start voice interaction
  startVoiceInteraction(): void {
    this.voiceManager.startListening();
  }

  // Stop voice interaction
  stopVoiceInteraction(): void {
    this.voiceManager.stopListening();
  }

  // Speak response
  speakResponse(text: string): void {
    this.voiceManager.speak(text);
  }
}