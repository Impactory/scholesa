import { CanonicalEvent, createEvent, EventActor, EventContext, EventPrivacy } from './schemas';
import { v4 as uuidv4 } from 'uuid';
import { isValidEvent } from './validator';

type TelemetryEnvelope = {
  event_name: string;
  context?: Partial<EventContext>;
  actor?: EventActor;
  payload?: Record<string, any>;
  metrics?: Record<string, number>;
};

export class TelemetryEmitter {
  private sessionId: string;
  private learnerId: string;
  private deviceId: string;
  private consentState: EventPrivacy['consent_state'];
  private collectorUrl: string;

  constructor(collectorUrl: string, learnerId: string, deviceId: string, consentState: EventPrivacy['consent_state']) {
    this.collectorUrl = collectorUrl;
    this.sessionId = uuidv4();
    this.learnerId = learnerId;
    this.deviceId = deviceId;
    this.consentState = consentState;
  }

  public async emit(
    eventName: string,
    context: EventContext,
    actor?: EventActor,
    payload?: Record<string, any>,
    metrics?: Record<string, number>
  ): Promise<void>;

  public async emit(envelope: TelemetryEnvelope): Promise<void>;

  public async emit(
    eventNameOrEnvelope: string | TelemetryEnvelope,
    context?: EventContext,
    actor: EventActor = 'learner',
    payload: Record<string, any> = {},
    metrics: Record<string, number> = {}
  ): Promise<void> {
    let eventName: string;
    let finalContext: EventContext;
    let finalActor: EventActor;
    let finalPayload: Record<string, any>;
    let finalMetrics: Record<string, number>;

    if (typeof eventNameOrEnvelope === 'string') {
      eventName = eventNameOrEnvelope;
      finalContext = context ?? this.defaultContext();
      finalActor = actor;
      finalPayload = payload;
      finalMetrics = metrics;
    } else {
      const envelope = eventNameOrEnvelope;
      eventName = envelope.event_name;
      finalContext = this.defaultContext(envelope.context);
      finalActor = envelope.actor ?? 'learner';
      finalPayload = envelope.payload ?? {};
      finalMetrics = envelope.metrics ?? {};
    }

    const privacy: EventPrivacy = {
      consent_state: this.consentState,
      data_class: 'pseudonymous', // Default
    };

    const event = createEvent(
      eventName,
      finalActor,
      finalContext,
      privacy,
      finalPayload,
      this.learnerId,
      this.deviceId,
      this.sessionId
    );

    event.metrics = finalMetrics;

    if (!isValidEvent(event)) {
      console.warn(`[Telemetry] Validation failed for event: ${eventName}`);
      return;
    }

    try {
      await this.send(event);
    } catch (error) {
      console.error(`[Telemetry] Failed to emit event: ${eventName}`, error);
      // Fail-closed logic or retry queue would go here
    }
  }

  private defaultContext(partial: Partial<EventContext> = {}): EventContext {
    return {
      grade_band: partial.grade_band ?? '4-6',
      subject: partial.subject ?? 'general',
      mission_id: partial.mission_id,
      step_id: partial.step_id,
    };
  }

  private async send(event: CanonicalEvent): Promise<void> {
    if (!this.collectorUrl) {
      this.logLocalFallback(event);
      return;
    }

    const response = await fetch(this.collectorUrl, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify(event),
    });

    if (!response.ok) {
      throw new Error(`collector responded ${response.status}`);
    }
  }

  private logLocalFallback(event: CanonicalEvent) {
    console.log(`[TelemetryLocal] ${event.event_name}`);
  }
}