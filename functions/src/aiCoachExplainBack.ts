type UnknownRecord = Record<string, unknown>;

const DEFAULT_EXPLAIN_BACK_FEEDBACK = 'Explain-back recorded for review.';

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export interface ExplainBackOpenedEvent {
  siteId: string;
  gradeBand?: unknown;
  sessionOccurrenceId?: unknown;
  missionId?: unknown;
  checkpointId?: unknown;
  payload?: UnknownRecord;
}

export interface ExplainBackSubmittedEvent {
  eventType: 'explain_it_back_submitted';
  siteId: string;
  actorId: string;
  actorRole: 'learner';
  gradeBand: string | null;
  sessionOccurrenceId: string | null;
  missionId: string | null;
  checkpointId: string | null;
  payload: {
    aiHelpOpenedEventId: string;
    explainBackLength: number;
    approved: true;
    feedback: string;
    mode: string | null;
  };
}

export function buildExplainBackSubmittedEvent(params: {
  actorId: string;
  aiHelpOpenedEventId: string;
  explainBack: string;
  openedEvent: ExplainBackOpenedEvent;
}): ExplainBackSubmittedEvent {
  const { actorId, aiHelpOpenedEventId, explainBack, openedEvent } = params;

  return {
    eventType: 'explain_it_back_submitted',
    siteId: openedEvent.siteId,
    actorId,
    actorRole: 'learner',
    gradeBand: asTrimmedString(openedEvent.gradeBand),
    sessionOccurrenceId: asTrimmedString(openedEvent.sessionOccurrenceId),
    missionId: asTrimmedString(openedEvent.missionId),
    checkpointId: asTrimmedString(openedEvent.checkpointId),
    payload: {
      aiHelpOpenedEventId,
      explainBackLength: explainBack.trim().length,
      approved: true,
      feedback: DEFAULT_EXPLAIN_BACK_FEEDBACK,
      mode: asTrimmedString(openedEvent.payload?.mode),
    },
  };
}

export const explainBackRecordedFeedback = DEFAULT_EXPLAIN_BACK_FEEDBACK;