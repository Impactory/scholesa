import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const SUPPORTED_LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'] as const;
const DEFAULT_LOCALE = 'en';
const PROTECTED_ROOT_SEGMENTS = new Set([
  'dashboard',
  'learner',
  'educator',
  'parent',
  'site',
  'partner',
  'hq',
]);
const AUTH_ROOT_SEGMENTS = new Set(['login', 'register']);

function isSupportedLocale(locale: string | undefined): locale is (typeof SUPPORTED_LOCALES)[number] {
  return !!locale && SUPPORTED_LOCALES.includes(locale as (typeof SUPPORTED_LOCALES)[number]);
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const segments = pathname.split('/').filter(Boolean);
  const localeFromPath = segments[0];

  if (!isSupportedLocale(localeFromPath)) {
    const localeFromCookie = request.cookies.get('scholesa_locale')?.value;
    const locale = isSupportedLocale(localeFromCookie) ? localeFromCookie : DEFAULT_LOCALE;
    return NextResponse.redirect(new URL(`/${locale}${pathname}`, request.url));
  }

  const rootSegment = segments[1] || '';
  const hasSessionCookie = Boolean(request.cookies.get('__session')?.value);

  if (PROTECTED_ROOT_SEGMENTS.has(rootSegment) && !hasSessionCookie) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = `/${localeFromPath}/login`;
    loginUrl.searchParams.set('from', pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (AUTH_ROOT_SEGMENTS.has(rootSegment) && hasSessionCookie) {
    const dashboardUrl = request.nextUrl.clone();
    dashboardUrl.pathname = `/${localeFromPath}/dashboard`;
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
