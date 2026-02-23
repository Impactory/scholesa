import { normalizeLocale, type SupportedLocale } from './config';

function firstLanguageFromAcceptLanguage(acceptLanguage: string | null | undefined): string | undefined {
  if (!acceptLanguage) return undefined;
  const candidate = acceptLanguage
    .split(',')
    .map((entry) => entry.trim().split(';')[0]?.trim())
    .find(Boolean);
  return candidate || undefined;
}

export function resolveRequestLocale(headers: Headers, preferredLocale?: string): SupportedLocale {
  const explicitLocale = headers.get('x-scholesa-locale');
  const acceptLanguage = firstLanguageFromAcceptLanguage(headers.get('accept-language'));

  return normalizeLocale(preferredLocale || explicitLocale || acceptLanguage || 'en');
}

export function buildLocaleHeaders(locale: SupportedLocale): Record<string, string> {
  return {
    'Accept-Language': locale,
    'X-Scholesa-Locale': locale,
  };
}
