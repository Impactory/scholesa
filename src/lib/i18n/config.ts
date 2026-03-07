export const SUPPORTED_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'] as const;

export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];

const DEFAULT_LOCALE: SupportedLocale = 'en';

const LOCALE_ALIASES: Record<string, SupportedLocale> = {
  en: 'en',
  'en-us': 'en',
  'en-gb': 'en',
  'en-ca': 'en',

  zh: 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-hans': 'zh-CN',
  'zh-sg': 'zh-CN',

  'zh-tw': 'zh-TW',
  'zh-hk': 'zh-TW',
  'zh-hant': 'zh-TW',
  'zh-mo': 'zh-TW',

  th: 'th',
  'th-th': 'th',

  // Legacy locale support (redirected to canonical paths in middleware).
  es: 'en',
  'es-es': 'en',
  'es-mx': 'en',
  'es-ar': 'en',
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
  if (locale === DEFAULT_LOCALE) return [DEFAULT_LOCALE];
  return [locale, DEFAULT_LOCALE];
}

export function isSupportedLocale(value: string | null | undefined): value is SupportedLocale {
  return !!value && SUPPORTED_LOCALES.includes(value as SupportedLocale);
}
