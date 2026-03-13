import { readInteractionSignalObservation } from './fdmInteractionSignals';

describe('fdmInteractionSignals', () => {
  it('derives cognition and engagement boosts from keystroke summaries', () => {
    const observation = readInteractionSignalObservation({
      eventType: 'interaction_signal_observed',
      payload: {
        signalFamily: 'keystroke',
        interactionCount: 7,
        charsAdded: 28,
        charsRemoved: 3,
      },
    });

    expect(observation).not.toBeNull();
    expect(observation?.family).toBe('keystroke');
    expect(observation?.engagementDelta).toBeGreaterThan(0.05);
    expect(observation?.cognitionDelta).toBeGreaterThan(0.03);
    expect(observation?.integrityDelta).toBeGreaterThan(0);
  });

  it('derives lightweight engagement signal from pointer summaries', () => {
    const observation = readInteractionSignalObservation({
      eventType: 'interaction_signal_observed',
      payload: {
        signalFamily: 'pointer',
        interactionCount: 1,
        trigger: 'click',
      },
    });

    expect(observation).not.toBeNull();
    expect(observation?.family).toBe('pointer');
    expect(observation?.engagementDelta).toBeGreaterThan(0);
    expect(observation?.cognitionDelta).toBeGreaterThan(0);
    expect(observation?.integrityDelta).toBe(0);
  });

  it('ignores unsupported payload families', () => {
    const observation = readInteractionSignalObservation({
      eventType: 'interaction_signal_observed',
      payload: { signalFamily: 'raw_text' },
    });

    expect(observation).toBeNull();
  });
});