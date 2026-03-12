// src/bos/engine.ts
import { TelemetryEmitter } from '../telemetry/emitter';

export interface BOSState {
  state: 'ONBOARDING' | 'INSTRUCTION' | 'GUIDED_PRACTICE' | 'BUILD_TIME' | 'CHECKPOINT' | 'REFLECTION' | 'COACHING_RECOVERY' | 'SAFE_MODE';
  last_transition: number;
  metrics: {
    confusion_count: number;
    hint_count: number;
    mastery_delta: number;
    silence_duration: number;
  };
}

export class BOSController {
  private state: BOSState;
  private emitter: TelemetryEmitter;

  constructor(emitter: TelemetryEmitter) {
    this.emitter = emitter;
    this.state = {
      state: 'ONBOARDING',
      last_transition: Date.now(),
      metrics: {
        confusion_count: 0,
        hint_count: 0,
        mastery_delta: 0,
        silence_duration: 0
      }
    };
  }

  // Evaluate policy and update state
  evaluatePolicy(event: any): void {
    // Example policy evaluation logic
    if (event.event_name === 'confusion_detected') {
      this.state.metrics.confusion_count += 1;
      if (this.state.metrics.confusion_count > 3) {
        this.transitionTo('COACHING_RECOVERY');
      }
    } else if (event.event_name === 'hint_delivered') {
      this.state.metrics.hint_count += 1;
      if (this.state.metrics.hint_count > 2) {
        this.transitionTo('COACHING_RECOVERY');
      }
    } else if (event.event_name === 'learner_response_captured') {
      // Check if response was confident
      if (event.payload.confidence < 0.7) {
        this.state.metrics.silence_duration += 1000;
      } else {
        this.state.metrics.silence_duration = 0;
      }
    }

    // Check for long silence
    if (this.state.metrics.silence_duration > 30000) {
      this.transitionTo('COACHING_RECOVERY');
    }
  }

  // Transition between states
  private transitionTo(newState: BOSState['state']): void {
    const oldState = this.state.state;
    this.state.state = newState;
    this.state.last_transition = Date.now();

    // Emit state change event
    this.emitter.emit({
      event_name: 'bos_state_transition',
      payload: {
        from: oldState,
        to: newState
      }
    });
  }

  // Get current state
  getState(): BOSState {
    return this.state;
  }

  // Apply decision to voice prompt
  applyDecision(): string {
    switch (this.state.state) {
      case 'COACHING_RECOVERY':
        return "Let's take a step back. Can you explain what you're thinking?";
      case 'INSTRUCTION':
        return "Great job! Let's try another example.";
      default:
        return "Let's get started!";
    }
  }
}