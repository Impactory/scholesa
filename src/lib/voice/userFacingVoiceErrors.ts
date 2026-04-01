export function getUserFacingVoiceTranscriptionError(error: unknown): string {
  const message = error instanceof Error ? error.message.trim() : '';

  if (!message) {
    return 'MiloOS could not clearly capture what you said. Please try again.';
  }

  if (/sign in to use ai help by voice/i.test(message)) {
    return 'Sign in to use MiloOS by voice.';
  }

  if (/voice help is unavailable right now/i.test(message)) {
    return 'Voice help is not available right now. Complete voice setup and try again.';
  }

  if (/voice help took too long to respond/i.test(message)) {
    return 'Voice help took too long to respond. Please try again.';
  }

  return 'MiloOS could not clearly capture what you said. Please try again.';
}