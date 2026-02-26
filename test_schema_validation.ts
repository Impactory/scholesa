import Ajv from 'ajv';
import { describe, it, expect } from '@jest/globals';

// Assume schemas are loaded from the /src/telemetry/schemas directory
import canonicalEventSchema from '../../src/telemetry/schemas/canonical_event.v1.schema.json';
import sessionStartedSchema from '../../src/telemetry/schemas/learning/session_started.v1.schema.json';

describe('Telemetry Schema Validation', () => {
  const ajv = new Ajv();

  // Pre-compile schemas for performance
  const validateCanonical = ajv.compile(canonicalEventSchema);
  const validateSessionStarted = ajv.compile(sessionStartedSchema);

  it('should validate a correct session_started event', () => {
    const validEvent = {
      event_name: 'session_started',
      event_version: '1.0.0',
      timestamp_ms: Date.now(),
      session_id: 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
      learner_id_hash: 'hashed_learner_id',
      device_id_hash: 'hashed_device_id',
      actor: 'learner',
      context: { grade_band: '4-6', mission_id: 'm-123' },
      privacy: { consent_state: 'granted', data_class: 'pseudonymous' },
      payload: {
        user_agent: 'Mozilla/5.0...',
        screen_width: 1920,
        screen_height: 1080,
        client_platform: 'web',
      },
    };

    const isCanonicalValid = validateCanonical(validEvent);
    expect(isCanonicalValid).toBe(true);

    const isPayloadValid = validateSessionStarted(validEvent.payload);
    expect(isPayloadValid).toBe(true);
  });

  it('should reject an event with a missing required field', () => {
    const invalidEvent = {
      event_name: 'session_started',
      // Missing event_version and other fields...
    };
    const isValid = validateCanonical(invalidEvent);
    expect(isValid).toBe(false);
    expect(validateCanonical.errors).not.toBeNull();
  });
});