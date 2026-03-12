// src/telemetry/schemas.ts
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';

export type EventActor = 'learner' | 'teacher' | 'system';
export type GradeBand = '1-3' | '4-6' | '7-9' | '10-12';
export type Subject = 'math' | 'reading' | 'science' | 'general';
export type ConsentState = 'unknown' | 'granted' | 'revoked';
export type DataClass = 'anonymous' | 'pseudonymous' | 'restricted';

export interface EventContext {
  grade_band: GradeBand;
  subject: Subject;
  mission_id?: string;
  step_id?: string;
}

export interface EventPrivacy {
  consent_state: ConsentState;
  data_class: DataClass;
}

export interface CanonicalEvent {
  event_name: string;
  event_version: string;
  timestamp_ms: number;
  session_id: string;
  learner_id_hash: string;
  device_id_hash: string;
  actor: EventActor;
  context: EventContext;
  privacy: EventPrivacy;
  payload: Record<string, any>;
  metrics?: Record<string, number>;
  trace?: {
    trace_id: string;
    span_id: string;
  };
}

export const createEvent = (
  name: string,
  actor: EventActor,
  context: EventContext,
  privacy: EventPrivacy,
  payload: Record<string, any>,
  learnerId: string,
  deviceId: string,
  sessionId: string = uuidv4()
): CanonicalEvent => {
  return {
    event_name: name,
    event_version: '1.0.0',
    timestamp_ms: Date.now(),
    session_id: sessionId,
    learner_id_hash: crypto.createHash('sha256').update(learnerId).digest('hex'),
    device_id_hash: crypto.createHash('sha256').update(deviceId).digest('hex'),
    actor,
    context,
    privacy,
    payload,
  };
};
