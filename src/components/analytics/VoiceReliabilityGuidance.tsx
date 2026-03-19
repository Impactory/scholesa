import React from 'react';

export const VOICE_RELIABILITY_HELPER_TEXT = {
  siteUnavailable: 'Unavailable means Scholesa does not yet have enough verified voice capture evidence for this period.',
  platformUnavailable: 'Unavailable means Scholesa does not yet have enough verified voice capture evidence across sites for this period.',
  siteTrustBoundary: 'This measures how often MiloOS captured usable voice input. Low capture weakens the trustworthiness of voice-derived support analytics.',
  platformTrustBoundary: 'When capture is weak, downstream voice-derived support analytics should be treated as less trustworthy operational evidence.',
  platformMetricNote: 'Low capture reduces confidence in voice-derived support analytics across sites.',
  trendInterpretation: 'Green bars indicate strong capture, amber means voice support should be interpreted cautiously, and red means voice-derived support evidence is materially unreliable for that period.',
} as const;

export function VoiceReliabilityLegend() {
  return (
    <div className="mt-4 flex flex-wrap gap-2 text-xs text-gray-600">
      <span className="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-2.5 py-1">
        <span className="h-2 w-2 rounded-full bg-emerald-500" />
        Strong: 80%+
      </span>
      <span className="inline-flex items-center gap-2 rounded-full bg-amber-50 px-2.5 py-1">
        <span className="h-2 w-2 rounded-full bg-amber-500" />
        Watch: 50-79%
      </span>
      <span className="inline-flex items-center gap-2 rounded-full bg-red-50 px-2.5 py-1">
        <span className="h-2 w-2 rounded-full bg-red-500" />
        Critical: below 50%
      </span>
    </div>
  );
}