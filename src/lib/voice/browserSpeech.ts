function normalizeSpokenText(text: string): string {
  return text
    .replace(/\s+/g, ' ')
    .replace(/\s+([,.;!?])/g, '$1')
    .replace(/([.!?])\s+/g, '$1 ')
    .trim();
}

export function canUseBrowserSpeechSynthesis(): boolean {
  return typeof window !== 'undefined'
    && 'speechSynthesis' in window
    && typeof SpeechSynthesisUtterance !== 'undefined';
}

export function stopBrowserSpeech(): void {
  if (!canUseBrowserSpeechSynthesis()) {
    return;
  }

  window.speechSynthesis.cancel();
}

function pickVoice(locale?: string): SpeechSynthesisVoice | null {
  if (!canUseBrowserSpeechSynthesis()) {
    return null;
  }

  const voices = window.speechSynthesis.getVoices();
  if (!voices.length) {
    return null;
  }

  const requestedLocale = locale?.trim().toLowerCase();
  if (requestedLocale) {
    const exactVoice = voices.find((voice) => voice.lang.toLowerCase() === requestedLocale);
    if (exactVoice) {
      return exactVoice;
    }

    const requestedLanguage = requestedLocale.split('-')[0];
    const partialVoice = voices.find((voice) => voice.lang.toLowerCase().startsWith(`${requestedLanguage}-`));
    if (partialVoice) {
      return partialVoice;
    }
  }

  return voices.find((voice) => voice.default) ?? voices[0] ?? null;
}

export function speakBrowserText(text: string, locale?: string): boolean {
  if (!canUseBrowserSpeechSynthesis()) {
    return false;
  }

  const trimmedText = normalizeSpokenText(text);
  if (!trimmedText) {
    return false;
  }

  const utterance = new SpeechSynthesisUtterance(trimmedText);
  const voice = pickVoice(locale);
  utterance.lang = locale?.trim() || voice?.lang || window.navigator.language || 'en-US';
  utterance.rate = 0.96;
  utterance.pitch = 1.02;
  utterance.volume = 1;
  if (voice) {
    utterance.voice = voice;
  }
  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(utterance);
  return true;
}