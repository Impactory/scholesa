import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const SUPPORTED_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'] as const;
const DEFAULT_LOCALE = 'en';
const LOCALE_ALIASES: Record<string, (typeof SUPPORTED_LOCALES)[number]> = {
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
  // Legacy locale alias preserved for compatibility redirects.
  es: 'en',
  'es-es': 'en',
  'es-mx': 'en',
  'es-ar': 'en',
};

const PROTECTED_ROOT_SEGMENTS = new Set([
  'dashboard',
  'learner',
  'educator',
  'parent',
  'site',
  'partner',
  'hq',
  'messages',
  'notifications',
  'profile',
  'settings',
]);
const AUTH_ROOT_SEGMENTS = new Set(['login', 'register']);
const LEGACY_ROLE_ROOT_SEGMENTS = new Set(['learner', 'educator', 'parent', 'site', 'partner', 'hq']);
const ROLE_DEFAULT_ROUTE: Record<string, string> = {
  learner: 'learner/today',
  educator: 'educator/today',
  parent: 'parent/summary',
  site: 'site/dashboard',
  partner: 'partner/listings',
  hq: 'hq/sites',
};

function isSupportedLocale(locale: string | undefined): locale is (typeof SUPPORTED_LOCALES)[number] {
  return !!locale && SUPPORTED_LOCALES.includes(locale as (typeof SUPPORTED_LOCALES)[number]);
}

function normalizeIncomingLocale(rawLocale: string | undefined): (typeof SUPPORTED_LOCALES)[number] | null {
  if (!rawLocale) return null;
  if (isSupportedLocale(rawLocale)) return rawLocale;

  const lowered = rawLocale.toLowerCase();
  const fromAlias = LOCALE_ALIASES[lowered];
  if (fromAlias) return fromAlias;

  const short = lowered.split('-')[0];
  if (!short) return null;
  return LOCALE_ALIASES[short] || null;
}

function joinPath(locale: string, segments: string[]): string {
  if (segments.length === 0) return `/${locale}`;
  return `/${locale}/${segments.join('/')}`;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const segments = pathname.split('/').filter(Boolean);
  const localeFromPath = segments[0];
  const canonicalLocaleFromPath = normalizeIncomingLocale(localeFromPath);

  if (!canonicalLocaleFromPath) {
    const localeFromCookie = request.cookies.get('scholesa_locale')?.value;
    const locale = normalizeIncomingLocale(localeFromCookie) || DEFAULT_LOCALE;
    const localeUrl = request.nextUrl.clone();
    localeUrl.pathname = joinPath(locale, segments);
    return NextResponse.redirect(localeUrl);
  }

  if (localeFromPath !== canonicalLocaleFromPath) {
    const aliasUrl = request.nextUrl.clone();
    aliasUrl.pathname = joinPath(canonicalLocaleFromPath, segments.slice(1));
    return NextResponse.redirect(aliasUrl);
  }

  const rootSegment = segments[1] || '';
  const hasSessionCookie = Boolean(request.cookies.get('__session')?.value);

  // Legacy top-level role pages are no longer canonical workflow routes.
  if (LEGACY_ROLE_ROOT_SEGMENTS.has(rootSegment) && segments.length === 2) {
    const fallback = ROLE_DEFAULT_ROUTE[rootSegment];
    if (fallback) {
      const roleUrl = request.nextUrl.clone();
      roleUrl.pathname = `/${canonicalLocaleFromPath}/${fallback}`;
      return NextResponse.redirect(roleUrl);
    }
  }

  if (PROTECTED_ROOT_SEGMENTS.has(rootSegment) && !hasSessionCookie) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = `/${canonicalLocaleFromPath}/login`;
    loginUrl.searchParams.set('from', pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (AUTH_ROOT_SEGMENTS.has(rootSegment) && hasSessionCookie) {
    const dashboardUrl = request.nextUrl.clone();
    dashboardUrl.pathname = `/${canonicalLocaleFromPath}/dashboard`;
    return NextResponse.redirect(dashboardUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    // Skip all internal paths (_next, assets, api)
    '/((?!api|_next/static|_next/image|favicon.ico|manifest.webmanifest|icons|logo).*)',
  ],
};
