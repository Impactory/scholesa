import { __aiCoachToneInternals, applyKidFriendlyConversationalTone } from './aiCoachTone';

describe('aiCoachTone honesty shaping', () => {
  it('removes legacy AI coach and MiloOS self-introductions from spoken guidance', () => {
    expect(
      __aiCoachToneInternals.stripLegacyAssistantIntro('Hello Sam, this is your AI coach. Try one small step.'),
    ).toBe('Try one small step.');

    expect(
      __aiCoachToneInternals.stripLegacyAssistantIntro('Hi Sam, this is MiloOS. Start with one clue.'),
    ).toBe('Start with one clue.');
  });

  it('rewrites legacy assistant labels to MiloOS and keeps a natural follow-up question', () => {
    const shaped = applyKidFriendlyConversationalTone(
      'Hello Sam, this is your AI coach. AI help can help you test one example.',
      'Sam',
    );

    expect(shaped).toContain('MiloOS can help you test one example.');
    expect(shaped).toContain('What feels like the best first move?');
    expect(shaped).not.toContain('AI coach');
    expect(shaped).not.toContain('AI help');
  });

  it('keeps strong encouraging replies concise when no extra question is requested', () => {
    const shaped = applyKidFriendlyConversationalTone(
      'Great persistence. Try checking the first example again.',
      'Sam',
      'no question',
    );

    expect(shaped).toBe('Great persistence. Try checking the first example again.');
  });
});