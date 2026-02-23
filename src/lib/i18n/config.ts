export const SUPPORTED_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'] as const;

export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];

const LOCALE_ALIASES: Record<string, SupportedLocale> = {
  en: 'en',
  'en-us': 'en',
  'en-gb': 'en',
  zh: 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-hans': 'zh-CN',
  'zh-sg': 'zh-CN',
  'zh-tw': 'zh-TW',
  'zh-hant': 'zh-TW',
  'zh-hk': 'zh-TW',
  th: 'th',
  'th-th': 'th'
};

export function normalizeLocale(rawLocale: string | null | undefined): SupportedLocale {
  if (!rawLocale) return 'en';
  const normalized = rawLocale.trim();
  if (!normalized) return 'en';

  if (SUPPORTED_LOCALES.includes(normalized as SupportedLocale)) {
    return normalized as SupportedLocale;
  }

  const alias = LOCALE_ALIASES[normalized.toLowerCase()];
  if (alias) return alias;

  const short = normalized.split('-')[0]?.toLowerCase();
  if (short && LOCALE_ALIASES[short]) {
    return LOCALE_ALIASES[short];
  }

  return 'en';
}

export function getFallbackChain(locale: SupportedLocale): SupportedLocale[] {
  if (locale === 'en') return ['en'];
  return [locale, 'en'];
}

export function isSupportedLocale(value: string | null | undefined): value is SupportedLocale {
  return !!value && SUPPORTED_LOCALES.includes(value as SupportedLocale);
}
