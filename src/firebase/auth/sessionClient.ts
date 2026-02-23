'use client';

import type { User } from 'firebase/auth';
import { buildLocaleHeaders } from '@/src/lib/i18n/localeHeaders';
import { normalizeLocale } from '@/src/lib/i18n/config';

const SESSION_LOGIN_PATH = '/api/auth/session-login';
const SESSION_LOGOUT_PATH = '/api/auth/session-logout';

function resolveClientLocale(explicitLocale?: string): string {
  if (explicitLocale) {
    return normalizeLocale(explicitLocale);
  }

  if (typeof document !== 'undefined' && document.documentElement.lang) {
    return normalizeLocale(document.documentElement.lang);
  }

  if (typeof navigator !== 'undefined' && navigator.language) {
    return normalizeLocale(navigator.language);
  }

  return 'en';
}

async function postSession(path: string, locale?: string, body?: Record<string, unknown>): Promise<void> {
  const resolvedLocale = resolveClientLocale(locale);
  const response = await fetch(path, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildLocaleHeaders(normalizeLocale(resolvedLocale)),
    },
    credentials: 'include',
    cache: 'no-store',
    body: JSON.stringify(body ?? {}),
  });

  if (!response.ok) {
    throw new Error(`Session endpoint failed (${response.status}) for ${path}`);
  }
}

export async function syncSessionCookie(user: User, locale?: string): Promise<void> {
  const idToken = await user.getIdToken(true);
  await postSession(SESSION_LOGIN_PATH, locale, { idToken });
}

export async function clearSessionCookie(locale?: string): Promise<void> {
  await postSession(SESSION_LOGOUT_PATH, locale);
}
