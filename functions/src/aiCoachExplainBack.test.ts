import {
  buildExplainBackSubmittedEvent,
  explainBackRecordedFeedback,
} from './aiCoachExplainBack';

describe('aiCoachExplainBack', () => {
  it('builds a linked explain-back interaction event from the AI help session', () => {
    const explainBack = ' I learned how to test the handler before shipping it. ';
    const payload = buildExplainBackSubmittedEvent({
      actorId: 'learner-1',
      aiHelpOpenedEventId: 'interaction-123',
      explainBack,
      openedEvent: {
        siteId: 'site-42',
        gradeBand: 'G7_9',
        sessionOccurrenceId: 'session-7',
        missionId: 'mission-3',
        checkpointId: 'checkpoint-2',
        payload: {
          mode: 'debug',
        },
      },
    });

    expect(payload).toEqual({
      eventType: 'explain_it_back_submitted',
      siteId: 'site-42',
      actorId: 'learner-1',
      actorRole: 'learner',
      gradeBand: 'G7_9',
      sessionOccurrenceId: 'session-7',
      missionId: 'mission-3',
      checkpointId: 'checkpoint-2',
      payload: {
        aiHelpOpenedEventId: 'interaction-123',
        explainBackLength: explainBack.trim().length,
        approved: true,
        feedback: explainBackRecordedFeedback,
        mode: 'debug',
      },
    });
  });

  it('normalizes missing linked values to null', () => {
    const payload = buildExplainBackSubmittedEvent({
      actorId: 'learner-2',
      aiHelpOpenedEventId: 'interaction-999',
      explainBack: 'Reviewed the evidence.',
      openedEvent: {
        siteId: 'site-9',
        payload: {},
      },
    });

    expect(payload.gradeBand).toBeNull();
    expect(payload.sessionOccurrenceId).toBeNull();
    expect(payload.missionId).toBeNull();
    expect(payload.checkpointId).toBeNull();
    expect(payload.payload.mode).toBeNull();
  });
});