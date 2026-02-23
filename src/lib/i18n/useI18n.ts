'use client';

import { useMemo } from 'react';
import { useParams } from 'next/navigation';
import { normalizeLocale, type SupportedLocale } from './config';
import { translate } from './messages';

type TranslationParams = Record<string, string | number>;

export function useI18n() {
  const params = useParams<{ locale?: string }>();
  const locale = useMemo<SupportedLocale>(
    () => normalizeLocale(params?.locale),
    [params?.locale],
  );

  const t = useMemo(
    () => (key: string, interpolation?: TranslationParams) =>
      translate(locale, key, interpolation),
    [locale],
  );

  return {
    locale,
    t,
  };
}
