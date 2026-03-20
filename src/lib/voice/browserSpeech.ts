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

export function speakBrowserText(text: string): boolean {
  if (!canUseBrowserSpeechSynthesis()) {
    return false;
  }

  const trimmedText = text.trim();
  if (!trimmedText) {
    return false;
  }

  const utterance = new SpeechSynthesisUtterance(trimmedText);
  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(utterance);
  return true;
}