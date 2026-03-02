import { CanonicalEvent, createEvent, EventActor, EventContext, EventPrivacy } from './schemas';
import { v4 as uuidv4 } from 'uuid';

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
    actor: EventActor = 'learner',
    payload: Record<string, any> = {},
    metrics: Record<string, number> = {}
  ): Promise<void> {
    const privacy: EventPrivacy = {
      consent_state: this.consentState,
      data_class: 'pseudonymous', // Default
    };

    const event = createEvent(
      eventName,
      actor,
      context,
      privacy,
      payload,
      this.learnerId,
      this.deviceId,
      this.sessionId
    );

    event.metrics = metrics;

    try {
      // In a real implementation, this would be an HTTP POST
      // console.log(`[Telemetry] Emitting event: ${eventName}`, JSON.stringify(event, null, 2));
      // await axios.post(this.collectorUrl, event);
      this.mockSend(event);
    } catch (error) {
      console.error(`[Telemetry] Failed to emit event: ${eventName}`, error);
      // Fail-closed logic or retry queue would go here
    }
  }

  private mockSend(event: CanonicalEvent) {
    // console.log(`[MockTransport] Sent ${event.event_name}`);
  }
}