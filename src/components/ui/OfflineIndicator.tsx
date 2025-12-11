'use client';

import { useOnlineStatus } from '@/src/lib/hooks/useOnlineStatus';
import { AnimatePresence, motion } from 'framer-motion';

export function OfflineIndicator() {
  const isOnline = useOnlineStatus();

  return (
    <AnimatePresence>
      {!isOnline && (
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          exit={{ height: 0, opacity: 0 }}
          className="bg-red-500 text-white text-center text-sm py-1"
        >
          You are currently offline. Changes will sync when connection is restored.
        </motion.div>
      )}
    </AnimatePresence>
  );
}
