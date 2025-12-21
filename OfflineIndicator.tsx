'use client';

import { useOnlineStatus } from '@/src/lib/hooks/useOnlineStatus';

export function OfflineIndicator() {
  const isOnline = useOnlineStatus();

  if (isOnline) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow-lg ring-1 ring-white/10">
      <div className="flex items-center gap-2">
        <div className="h-2 w-2 rounded-full bg-red-500 animate-pulse" />
        <span>You are offline. Changes will sync later.</span>
      </div>
    </div>
  );
}