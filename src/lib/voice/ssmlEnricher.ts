type SpeechRate = 'slow' | 'measured' | 'normal' | 'fast';
type SpeechTone = 'supportive' | 'engaging' | 'encouraging' | 'professional';

interface ProsodyOptions {
  locale: string;
  speechRate: SpeechRate;
  tone: SpeechTone;
  emotionalState: string;
  gradeBand: string;
  needsScaffold: boolean;
}

const RATE_MAP: Record<SpeechRate, string> = {
  slow: '80%',
  measured: '90%',
  normal: '100%',
  fast: '110%',
};

const TONE_PITCH_MAP: Record<SpeechTone, string> = {
  supportive: '+3%',
  engaging: '+5%',
  encouraging: '+2%',
  professional: '+0%',
};

function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function insertSentenceBreaks(text: string, emotionalState: string): string {
  const breakMs = emotionalState === 'frustrated' || emotionalState === 'confused' ? 400 : 250;
  return text.replace(/([.!?。！？])\s+/g, `$1 <break time="${breakMs}ms"/> `);
}

export function enrichWithProsody(text: string, options: ProsodyOptions): string {
  if (!text.trim()) return text;

  const rate = RATE_MAP[options.speechRate] ?? RATE_MAP.normal;
  const pitch = TONE_PITCH_MAP[options.tone] ?? TONE_PITCH_MAP.professional;

  let body = escapeXml(text);
  body = insertSentenceBreaks(body, options.emotionalState);

  if (options.gradeBand === 'K-5' && options.needsScaffold) {
    body = body.replace(/([.!?。！？])\s+/g, `$1 <break time="500ms"/> `);
  }

  return `<speak><prosody rate="${rate}" pitch="${pitch}">${body}</prosody></speak>`;
}

export function stripSsml(ssml: string): string {
  return ssml.replace(/<[^>]+>/g, '').trim();
}
