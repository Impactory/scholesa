'use client';

import React from 'react';

// TODO: This component needs to be updated to use the new motivationEngine structure
// Temporarily disabled to unblock build

interface ClassInsightsProps {
  siteId: string;
  sessionOccurrenceId?: string;
  learnerIds?: string[];
  onSelectLearner?: (learnerId: string) => void;
}

export function ClassInsights(_props: ClassInsightsProps) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <p className="text-gray-500">Class insights temporarily unavailable - under maintenance</p>
    </div>
  );
}

export function ClassInsightsCompact({
  siteId: _siteId,
  onViewFull: _onViewFull,
}: {
  siteId: string;
  onViewFull?: () => void;
}) {
  return (
    <div className="p-4 bg-gray-50 rounded-lg border border-gray-200">
      <p className="text-gray-500 text-sm">Class insights temporarily unavailable</p>
    </div>
  );
}
