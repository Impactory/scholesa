// src/telemetry/emitter.ts
import { v4 as uuidv4 } from 'uuid';
import { createHash } from 'crypto';

// Canonical Event Envelope
interface CanonicalEvent {
  event_name: string;
  event_version: string;
  timestamp_ms: number;
  session_id: string;
  learner_id_hash: string;
  device_id_hash: string;
  actor: 'learner' | 'teacher' | 'system';
  context: {
    grade_band: '1-3' | '4-6' | '7-9' | '10-12';
    subject: string;
    mission_id: string;
    step_id: string;
  };
  privacy: {
    consent_state: 'unknown' | 'granted' | 'revoked';
    data_class: 'anonymous' | 'pseudonymous' | 'restricted';
  };
  payload: object;
  metrics: object;
  trace: {
    trace_id: string;
    span_id: string;
  };
}

// Telemetry Emitter Class
export class TelemetryEmitter {
  private session_id: string;
  private learner_id: string;
  private device_id: string;
  private consent_state: 'unknown' | 'granted' | 'revoked';

  constructor(
    learner_id: string,
    device_id: string,
    consent_state: 'unknown' | 'granted' | 'revoked'
  ) {
    this.session_id = uuidv4();
    this.learner_id = learner_id;
    this.device_id = device_id;
    this.consent_state = consent_state;
  }

  // Hash learner and device IDs
  private hashId(id: string): string {
    return createHash('sha256').update(id).digest('hex');
  }

  // Emit event
  emit(event: Omit<CanonicalEvent, 'session_id' | 'learner_id_hash' | 'device_id_hash' | 'timestamp_ms'>): void {
    const eventWithMeta: CanonicalEvent = {
      ...event,
      session_id: this.session_id,
      learner_id_hash: this.hashId(this.learner_id),
      device_id_hash: this.hashId(this.device_id),
      timestamp_ms: Date.now(),
      trace: {
        trace_id: uuidv4(),
        span_id: uuidv4()
      }
    };

    // Send to collector (mocked for now)
    console.log('Emitting event:', JSON.stringify(eventWithMeta, null, 2));
  }
}