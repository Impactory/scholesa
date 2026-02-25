'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '@/src/firebase/client-init';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { syncSessionCookie } from '@/src/firebase/auth/sessionClient';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

export default function LoginPage() {
  const router = useRouter();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const credential = await signInWithEmailAndPassword(auth, email, password);
      await syncSessionCookie(credential.user, locale);
      // Redirect to Dashboard (Redirector will handle role routing)
      router.replace(`/${locale}/dashboard`);
      router.refresh();
    } catch (err: any) {
      console.error('Login error:', err);
      setError(t('auth.login.invalidCredentials'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-app-canvas p-4">
      <div className="fixed right-4 top-4 z-10">
        <ThemeModeToggle compact />
      </div>
      <div className="w-full max-w-md space-y-8 rounded-lg bg-app-surface p-8 shadow-md border border-app">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight text-app-foreground">{t('auth.login.title')}</h2>
          <p className="mt-2 text-sm text-app-muted">{t('auth.login.subtitle')}</p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleLogin}>
          {error && (
            <div className="rounded-md bg-red-50 p-4 text-sm text-red-700">
              {error}
            </div>
          )}

          <div className="space-y-4 rounded-md shadow-sm">
            <div>
              <label htmlFor="email-address" className="sr-only">{t('auth.login.emailLabel')}</label>
              <input
                id="email-address"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="relative block w-full rounded-md border-0 py-1.5 text-app-foreground ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3 bg-app-surface"
                placeholder={t('auth.login.emailPlaceholder')}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="password" className="sr-only">{t('auth.login.passwordLabel')}</label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                className="relative block w-full rounded-md border-0 py-1.5 text-app-foreground ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3 bg-app-surface"
                placeholder={t('auth.login.passwordPlaceholder')}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              onClick={() => trackInteraction('help_accessed', { cta: 'auth_login_submit' })}
              className="group relative flex w-full justify-center rounded-md bg-primary px-3 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[hsl(var(--ring))] disabled:opacity-50"
            >
              {loading ? t('auth.login.submitting') : t('auth.login.submit')}
            </button>
          </div>

          <div className="text-center text-sm">
            <a
              href={`/${locale}/register`}
              className="font-medium text-primary hover:text-primary/80"
              onClick={() => trackInteraction('feature_discovered', { cta: 'auth_login_to_register' })}
            >
              {t('auth.login.switchToRegister')}
            </a>
          </div>
        </form>
      </div>
    </div>
  );
}
