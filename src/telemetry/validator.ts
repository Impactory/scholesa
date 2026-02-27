// src/telemetry/validator.ts
import Ajv from 'ajv';
import { CanonicalEvent } from './emitter';

// Event schema definition
const eventSchema = {
  type: "object",
  required: ["event_name", "event_version", "timestamp_ms", "session_id", "learner_id_hash", "device_id_hash", "actor", "context", "privacy", "payload"],
  properties: {
    event_name: { type: "string" },
    event_version: { type: "string" },
    timestamp_ms: { type: "integer" },
    session_id: { type: "string" },
    learner_id_hash: { type: "string" },
    device_id_hash: { type: "string" },
    actor: { type: "string", enum: ["learner", "teacher", "system"] },
    context: {
      type: "object",
      required: ["grade_band", "subject", "mission_id", "step_id"],
      properties: {
        grade_band: { type: "string", enum: ["1-3", "4-6", "7-9", "10-12"] },
        subject: { type: "string" },
        mission_id: { type: "string" },
        step_id: { type: "string" }
      }
    },
    privacy: {
      type: "object",
      required: ["consent_state", "data_class"],
      properties: {
        consent_state: { type: "string", enum: ["unknown", "granted", "revoked"] },
        data_class: { type: "string", enum: ["anonymous", "pseudonymous", "restricted"] }
      }
    },
    payload: { type: "object" },
    metrics: { type: "object" },
    trace: {
      type: "object",
      properties: {
        trace_id: { type: "string" },
        span_id: { type: "string" }
      }
    }
  }
};

export class SchemaValidator {
  private ajv: Ajv;

  constructor() {
    this.ajv = new Ajv();
    this.ajv.addSchema(eventSchema, 'event');
  }

  validate(event: CanonicalEvent): boolean {
    const valid = this.ajv.validate('event', event);
    if (!valid) {
      console.error('Validation error:', this.ajv.errors);
    }
    return valid;
  }
}