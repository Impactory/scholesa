'use client';

import { useEffect } from 'react';
import { registerServiceWorker } from '@/src/lib/pwa/registerServiceWorker';

export function ServiceWorkerRegister() {
  useEffect(() => {
    registerServiceWorker();
  }, []);

  return null;
}
