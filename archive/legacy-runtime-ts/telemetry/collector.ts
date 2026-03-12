// src/telemetry/collector.ts
import type { CanonicalEvent } from './schemas';
import { isValidEvent } from './validator';

export class TelemetryCollector {
  private readonly endpoint?: string;
  private readonly buffer: CanonicalEvent[] = [];

  constructor(endpoint?: string) {
    this.endpoint = endpoint;
  }

  // Collect and store events
  async collect(event: CanonicalEvent): Promise<void> {
    if (!this.validate(event)) return;

    if (!this.endpoint) {
      this.buffer.push(event);
      return;
    }

    try {
      await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
        },
        body: JSON.stringify(event),
      });
    } catch (error) {
      this.buffer.push(event);
      console.error('[TelemetryCollector] event delivery failed; buffered for retry', error);
    }
  }

  // Validate event schema
  validate(event: CanonicalEvent): boolean {
    return isValidEvent(event);
  }

  // Flush buffered events once endpoint becomes available/reachable.
  async flushBuffered(): Promise<void> {
    if (!this.endpoint || this.buffer.length === 0) return;

    const pending = [...this.buffer];
    this.buffer.length = 0;

    for (const event of pending) {
      await this.collect(event);
    }
  }
}