import {
  buildExplainBackSubmittedEvent,
  explainBackRecordedFeedback,
  verifyExplainBack,
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

describe('verifyExplainBack', () => {
  const aiResponse = 'The function transforms input data by applying a normalization step followed by a calibration pass to produce the final output values';

  it('rejects explanations that are too short', () => {
    const result = verifyExplainBack('yes I got it', aiResponse);
    expect(result.approved).toBe(false);
    expect(result.rejectionReason).toBe('too_short');
  });

  it('rejects copied AI response (high word overlap)', () => {
    // Nearly identical to AI response
    const copy = 'The function transforms input data by applying a normalization step followed by a calibration pass to produce the final output values';
    const result = verifyExplainBack(copy, aiResponse);
    expect(result.approved).toBe(false);
    expect(result.rejectionReason).toBe('copied_ai_response');
    expect(result.wordOverlapWithAiResponse).toBeGreaterThanOrEqual(0.75);
  });

  it('approves genuine explanation with enough detail', () => {
    const genuine = 'I learned that the handler first normalizes the raw measurements, then runs a calibration algorithm to adjust for sensor drift, and finally returns corrected readings for downstream use';
    const result = verifyExplainBack(genuine, aiResponse);
    expect(result.approved).toBe(true);
    expect(result.feedback).toContain('Great');
  });

  it('handles undefined aiResponseText gracefully', () => {
    const explanation = 'I learned that the function processes data through multiple transformation stages before returning the results to the caller for rendering in the dashboard view';
    const result = verifyExplainBack(explanation, undefined);
    expect(result.approved).toBe(true);
  });

  it('handles empty aiResponseText gracefully', () => {
    const explanation = 'I learned that the function processes data through multiple transformation stages before returning the results to the caller for rendering in the dashboard view';
    const result = verifyExplainBack(explanation, '  ');
    expect(result.approved).toBe(true);
  });

  it('rejects insufficient detail when AI response is available', () => {
    const tooShort = 'It does something with data and stuff';
    const result = verifyExplainBack(tooShort, aiResponse);
    expect(result.approved).toBe(false);
    expect(result.rejectionReason).toBe('insufficient_detail');
  });
});