'use client';

import { useEffect } from 'react';
import { registerServiceWorker } from '@/src/lib/pwa/registerServiceWorker';

export function ServiceWorkerLoader() {
  useEffect(() => {
    registerServiceWorker();
  }, []);

  return null;
}