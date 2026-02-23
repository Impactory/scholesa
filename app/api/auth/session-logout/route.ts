import { NextResponse } from 'next/server';
import { resolveRequestLocale } from '@/src/lib/i18n/localeHeaders';

export async function POST(request: Request) {
  const resolvedLocale = resolveRequestLocale(request.headers);
  const options = {
    name: '__session',
    value: '',
    maxAge: -1, // Expire the cookie immediately
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    path: '/',
  };

  const response = NextResponse.json({ status: 'success' }, { status: 200 });
  response.cookies.set(options);
  response.cookies.set({
    name: 'scholesa_locale',
    value: resolvedLocale,
    maxAge: 60 * 60 * 24 * 365,
    httpOnly: false,
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    sameSite: 'lax',
  });

  return response;
}
