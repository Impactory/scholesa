// src/bos/state_machine.ts
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

export class BOSStateMachine {
  private currentState: BOSState;

  constructor() {
    this.currentState = {
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

  // Transition to a new state
  transitionTo(newState: BOSState['state']): void {
    const oldState = this.currentState.state;
    this.currentState.state = newState;
    this.currentState.last_transition = Date.now();
    
    console.log(`BOS Transition: ${oldState} -> ${newState}`);
  }

  // Get current state
  getState(): BOSState {
    return this.currentState;
  }

  // Update metrics
  updateMetrics(metrics: Partial<BOSState['metrics']>): void {
    this.currentState.metrics = {
      ...this.currentState.metrics,
      ...metrics
    };
  }
}