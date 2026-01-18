'use client';

import React from 'react';

// TODO: This component needs to be updated to use the new motivationEngine structure
// Temporarily disabled to unblock build

interface MotivationNudgesProps {
  siteId: string;
  maxNudges?: number;
  showInline?: boolean;
  onNudgeAction?: (nudgeId: string, action: 'accepted' | 'dismissed' | 'snoozed') => void;
}

export function MotivationNudges(_props: MotivationNudgesProps) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <p className="text-gray-500">Motivation nudges temporarily unavailable - under maintenance</p>
    </div>
  );
}

export function NudgeIndicator({ count }: { count?: number }) {
  return null;
}
