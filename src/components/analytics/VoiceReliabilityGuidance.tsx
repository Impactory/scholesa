import React from 'react';

export const VOICE_RELIABILITY_HELPER_TEXT = {
  siteUnavailable: 'Unavailable means Scholesa does not yet have enough verified voice capture evidence for this period.',
  platformUnavailable: 'Unavailable means Scholesa does not yet have enough verified voice capture evidence across sites for this period.',
  siteTrustBoundary: 'This shows how often MiloOS captured voice input clearly enough to use. Low capture means the voice-based support numbers here may miss part of the picture.',
  platformTrustBoundary: 'When capture is weak, voice-based support numbers across sites may miss part of the picture and should be read carefully.',
  platformMetricNote: 'Low capture lowers confidence because there are fewer clear voice examples across sites.',
  trendInterpretation: 'Green bars mean capture stayed strong, amber means read voice support trends carefully, and red means there was not enough clear voice evidence to rely on for that period.',
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