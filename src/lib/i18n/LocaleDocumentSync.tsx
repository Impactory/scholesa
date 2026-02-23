'use client';

import { useEffect } from 'react';
import { normalizeLocale } from './config';

export function LocaleDocumentSync({ locale }: { locale: string }) {
  useEffect(() => {
    const normalized = normalizeLocale(locale);
    document.documentElement.lang = normalized;
  }, [locale]);

  return null;
}
