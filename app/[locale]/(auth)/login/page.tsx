'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword, signOut as signOutFromFirebase } from 'firebase/auth';
import { auth } from '@/src/firebase/client-init';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { syncSessionCookie } from '@/src/firebase/auth/sessionClient';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

type EnterpriseSsoProvider = {
  providerId: string;
  providerType: 'oidc' | 'saml';
  displayName: string;
  buttonLabel: string;
  allowedDomains: string[];
};

export default function LoginPage() {
  const router = useRouter();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();
  const { signInWithProvider } = useAuthContext();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [enterpriseProviders, setEnterpriseProviders] = useState<EnterpriseSsoProvider[]>([]);
  const [enterpriseLoading, setEnterpriseLoading] = useState(true);

  const resolveLoginError = (err: unknown): string => {
    if (typeof err === 'object' && err !== null && 'code' in err) {
      const code = String((err as { code?: unknown }).code ?? '');
      if (code.startsWith('auth/')) {
        return t('auth.login.invalidCredentials');
      }
    }

    return 'Login could not be completed. Please try again or contact your site or HQ admin.';
  };

  useEffect(() => {
    let isActive = true;

    const loadEnterpriseProviders = async () => {
      try {
        setEnterpriseLoading(true);
        const response = await fetch('/api/auth/sso/providers', {
          method: 'GET',
          headers: {
            'X-Scholesa-Locale': locale,
            'Accept-Language': locale,
          },
          cache: 'no-store',
        });
        if (!response.ok) {
          throw new Error(`Provider discovery failed (${response.status})`);
        }
        const body = await response.json() as { providers?: EnterpriseSsoProvider[] };
        if (isActive) {
          setEnterpriseProviders(Array.isArray(body.providers) ? body.providers : []);
        }
      } catch (providerError) {
        console.error('Failed to load enterprise SSO providers.', providerError);
        if (isActive) {
          setEnterpriseProviders([]);
        }
      } finally {
        if (isActive) {
          setEnterpriseLoading(false);
        }
      }
    };

    void loadEnterpriseProviders();
    return () => {
      isActive = false;
    };
  }, [locale]);

  const emailDomain = email.trim().split('@')[1]?.toLowerCase() || '';
  const visibleEnterpriseProviders = !emailDomain
    ? enterpriseProviders
    : enterpriseProviders.filter((provider) =>
      provider.allowedDomains.length === 0 || provider.allowedDomains.map((domain) => domain.toLowerCase()).includes(emailDomain),
    );

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const credential = await signInWithEmailAndPassword(auth, email, password);
      try {
        await syncSessionCookie(credential.user, locale);
      } catch (sessionError) {
        try {
          await signOutFromFirebase(auth);
        } catch (signOutError) {
          console.error('Failed to clear Firebase Auth session after login setup error.', signOutError);
        }
        throw sessionError;
      }
      // Redirect to Dashboard (Redirector will handle role routing)
      router.replace(`/${locale}/dashboard`);
      router.refresh();
    } catch (err: unknown) {
      console.error('Login error:', err);
      setError(resolveLoginError(err));
    } finally {
      setLoading(false);
    }
  };

  const handleEnterpriseLogin = async (provider: EnterpriseSsoProvider) => {
    setLoading(true);
    setError('');

    try {
      trackInteraction('feature_discovered', {
        cta: 'auth_enterprise_sign_in',
        providerId: provider.providerId,
        providerType: provider.providerType,
      });
      await signInWithProvider(provider.providerId, locale);
      router.replace(`/${locale}/dashboard`);
      router.refresh();
    } catch (enterpriseError) {
      console.error('Enterprise SSO sign-in failed.', enterpriseError);
      setError(t('auth.login.ssoFailed'));
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
              className="min-touch-target relative flex w-full justify-center rounded-md bg-app-primary px-4 py-3 text-sm font-semibold text-app-primary-foreground hover:bg-app-primary-emphasis focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring disabled:opacity-50"
            >
              {loading ? t('auth.login.submitting') : t('auth.login.submit')}
            </button>
          </div>

          <div className="space-y-3">
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-app" />
              </div>
              <div className="relative flex justify-center text-xs uppercase tracking-[0.24em]">
                <span className="bg-app-surface px-2 text-app-muted">{t('auth.login.enterpriseHeading')}</span>
              </div>
            </div>

            {enterpriseLoading ? (
              <p className="text-center text-sm text-app-muted">{t('auth.login.loadingEnterprise')}</p>
            ) : visibleEnterpriseProviders.length > 0 ? (
              <div className="space-y-2">
                {visibleEnterpriseProviders.map((provider) => (
                  <button
                    key={provider.providerId}
                    type="button"
                    disabled={loading}
                    onClick={() => void handleEnterpriseLogin(provider)}
                    className="min-touch-target relative flex w-full justify-center rounded-md border border-app bg-app-surface px-4 py-3 text-sm font-semibold text-app-foreground hover:bg-app-canvas focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring disabled:opacity-50"
                  >
                    {provider.buttonLabel}
                  </button>
                ))}
              </div>
            ) : (
              <p className="text-center text-sm text-app-muted">{t('auth.login.ssoUnavailable')}</p>
            )}
          </div>

          <div className="text-center text-sm">
            <a
              href={`/${locale}/register`}
              className="app-touch-link font-medium text-app-primary hover:text-app-primary-emphasis"
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
