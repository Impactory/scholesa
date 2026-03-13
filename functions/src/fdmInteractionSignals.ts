export interface InteractionSignalObservation {
  family: 'keystroke' | 'pointer';
  interactionCount: number;
  cognitionDelta: number;
  engagementDelta: number;
  integrityDelta: number;
}

function clamp(value: number, min: number = 0, max: number = 1): number {
  return Math.min(max, Math.max(min, value));
}

function normalizeString(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function toFiniteNumber(value: unknown, fallback: number = 0): number {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return numeric;
}

export function readInteractionSignalObservation(event: Record<string, unknown> | null | undefined): InteractionSignalObservation | null {
  if (!event || event.eventType !== 'interaction_signal_observed') {
    return null;
  }

  const payload = event.payload && typeof event.payload === 'object'
    ? event.payload as Record<string, unknown>
    : {};
  const family = normalizeString(payload.signalFamily)?.toLowerCase();
  const interactionCount = Math.max(1, Math.round(toFiniteNumber(payload.interactionCount, 1)));

  if (family === 'keystroke') {
    const charsAdded = Math.max(0, toFiniteNumber(payload.charsAdded, 0));
    const charsRemoved = Math.max(0, toFiniteNumber(payload.charsRemoved, 0));
    const engagementDelta = clamp(0.02 + (Math.min(interactionCount, 12) * 0.007) + (Math.min(charsAdded, 80) * 0.001) - (Math.min(charsRemoved, 30) * 0.0005), 0, 0.18);
    const cognitionDelta = clamp((Math.min(charsAdded, 90) * 0.0008) + (Math.min(interactionCount, 10) * 0.003), 0, 0.12);
    const integrityDelta = charsAdded > 0 ? 0.015 : 0;
    return {
      family: 'keystroke',
      interactionCount,
      cognitionDelta,
      engagementDelta,
      integrityDelta,
    };
  }

  if (family === 'pointer') {
    const engagementDelta = clamp(0.015 + (Math.min(interactionCount, 4) * 0.01), 0, 0.06);
    const cognitionDelta = 0.01;
    return {
      family: 'pointer',
      interactionCount,
      cognitionDelta,
      engagementDelta,
      integrityDelta: 0,
    };
  }

  return null;
}