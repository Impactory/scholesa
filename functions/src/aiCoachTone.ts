function stripLegacyAssistantIntro(message: string): string {
  return message
    .replace(/^hello\s+[^,]+,?\s*this is your ai coach\.?\s*/i, '')
    .replace(/^hello\s+[^,]+,?\s*this is miloos\.?\s*/i, '')
    .replace(/^hello\s+[^,]+,?\s*this is ai help\.?\s*/i, '')
    .replace(/^hi\s+[^,]+,?\s*this is your ai coach\.?\s*/i, '')
    .replace(/^hi\s+[^,]+,?\s*this is miloos\.?\s*/i, '')
    .replace(/^hi\s+[^,]+,?\s*this is ai help\.?\s*/i, '')
    .replace(/^hello\s+/i, '')
    .trim();
}

export function applyKidFriendlyConversationalTone(
  message: string,
  displayName: string,
  personaHint?: string,
): string {
  const trimmed = (message || '').replace(/\s+/g, ' ').trim();
  if (!trimmed) {
    return `${displayName}, you are doing fine. Let's take one small step together. What do you want to try first?`;
  }

  const encouragementRegex = /\b(great|good|nice|awesome|well done|you can do this|you've got this|let's|i'm here|we'll)\b/i;
  const hasEncouragement = encouragementRegex.test(trimmed);
  const hasQuestion = /\?/.test(trimmed);
  const skipFollowupQuestion = /no\s+question/i.test(personaHint ?? '');
  const normalized = stripLegacyAssistantIntro(trimmed);

  let shaped = hasEncouragement ? normalized : `${displayName}, nice effort. ${normalized}`;
  shaped = shaped
    .replace(/\bAI coach\b/gi, 'MiloOS')
    .replace(/\bai coach\b/g, 'MiloOS')
    .replace(/\bAI help\b/gi, 'MiloOS');

  if (!hasQuestion && !skipFollowupQuestion) {
    shaped = `${shaped} What feels like the best first move?`;
  }

  return shaped.trim();
}

export const __aiCoachToneInternals = {
  stripLegacyAssistantIntro,
};