// src/telemetry/validator.ts
import Ajv from 'ajv';

const ajv = new Ajv();

const canonicalEventSchema = {
  type: 'object',
  properties: {
    event_name: { type: 'string' },
    event_version: { type: 'string' },
    timestamp_ms: { type: 'integer' },
    session_id: { type: 'string' },
    learner_id_hash: { type: 'string' },
    device_id_hash: { type: 'string' },
    actor: { enum: ['learner', 'teacher', 'system'] },
    context: {
      type: 'object',
      properties: {
        grade_band: { enum: ['1-3', '4-6', '7-9', '10-12'] },
        subject: { enum: ['math', 'reading', 'science', 'general'] },
      },
      required: ['grade_band', 'subject'],
    },
    privacy: {
      type: 'object',
      properties: {
        consent_state: { enum: ['unknown', 'granted', 'revoked'] },
        data_class: { enum: ['anonymous', 'pseudonymous', 'restricted'] },
      },
      required: ['consent_state', 'data_class'],
    },
  },
  required: [
    'event_name',
    'timestamp_ms',
    'session_id',
    'learner_id_hash',
    'actor',
    'context',
    'privacy',
  ],
};

const validateEvent = ajv.compile(canonicalEventSchema);

export const isValidEvent = (event: any): boolean => {
  const valid = validateEvent(event);
  if (!valid) {
    console.error('Schema Validation Failed:', validateEvent.errors);
  }
  return valid as boolean;
};