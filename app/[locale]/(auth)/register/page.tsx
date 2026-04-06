'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  createUserWithEmailAndPassword,
  deleteUser,
  signOut,
  type User,
  updateProfile,
} from 'firebase/auth';
import { auth } from '@/src/firebase/client-init';
import { createUserDocument, deleteUserDocument } from '@/src/lib/auth/createUser';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { Role } from '@/schema';
import type { AgeBand } from '@/src/types/user';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { syncSessionCookie } from '@/src/firebase/auth/sessionClient';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

export default function RegisterPage() {
  const router = useRouter();
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [role, setRole] = useState<Role>('learner');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Privacy consent & age verification state
  const [consentAccepted, setConsentAccepted] = useState(false);
  const [tosAccepted, setTosAccepted] = useState(false);
  const [ageBand, setAgeBand] = useState<AgeBand | ''>('');
  const [parentConsentConfirmed, setParentConsentConfirmed] = useState(false);

  const isUnder13 = ageBand === 'under13';
  const consentValid =
    consentAccepted && tosAccepted && ageBand !== '' && (!isUnder13 || parentConsentConfirmed);

  const resolveRegisterError = (err: unknown): string => {
    if (typeof err === 'object' && err !== null && 'code' in err) {
      const code = String((err as { code?: unknown }).code ?? '');
      if (code.startsWith('auth/')) {
        return String((err as { message?: unknown }).message ?? t('auth.register.fallbackError'));
      }
    }

    return 'Registration could not be completed. Your account was not saved.';
  };

  const rollbackRegistration = async ({
    user,
    createdUserDocument,
  }: {
    user: User;
    createdUserDocument: boolean;
  }) => {
    if (createdUserDocument) {
      try {
        await deleteUserDocument(user.uid);
      } catch (rollbackError) {
        console.error('Failed to roll back user document after registration error.', rollbackError);
      }
    }

    try {
      await deleteUser(user);
    } catch (rollbackError) {
      console.error('Failed to delete Firebase Auth user after registration error.', rollbackError);
      try {
        await signOut(auth);
      } catch (signOutError) {
        console.error('Failed to clear Firebase Auth session after registration error.', signOutError);
      }
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!consentValid) return;
    setLoading(true);
    setError('');

    let createdUser: User | null = null;
    let createdUserDocument = false;

    try {
      // 1. Create Auth User
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;
      createdUser = user;

      // 2. Update Profile
      if (displayName) {
        await updateProfile(user, { displayName });
      }

      // 3. Create Firestore Document with consent metadata
      await createUserDocument({
        uid: user.uid,
        email: user.email!,
        role,
        displayName,
        photoURL: user.photoURL || undefined,
        registrationConsent: {
          consentAccepted: true,
          tosAccepted: true,
          ageBand: ageBand as AgeBand,
          parentConsentConfirmed: isUnder13 ? parentConsentConfirmed : false,
          pipedaCrossBorderAcknowledged: true,
        },
      });
      createdUserDocument = true;

      await syncSessionCookie(user, locale);

      // 4. Redirect to Dashboard (Redirector will handle role routing)
      router.replace(`/${locale}/dashboard`);
      router.refresh();
    } catch (err: unknown) {
      console.error('Registration error:', err);
      if (createdUser) {
        await rollbackRegistration({
          user: createdUser,
          createdUserDocument,
        });
      }
      setError(resolveRegisterError(err));
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
          <h2 className="text-3xl font-bold tracking-tight text-app-foreground">{t('auth.register.title')}</h2>
          <p className="mt-2 text-sm text-app-muted">{t('auth.register.subtitle')}</p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleRegister}>
          {error && (
            <div className="rounded-md bg-red-50 p-4 text-sm text-red-700">
              {error}
            </div>
          )}

          <div className="space-y-4 rounded-md shadow-sm">
            <div>
              <label htmlFor="name" className="sr-only">{t('auth.register.nameLabel')}</label>
              <input
                id="name"
                name="name"
                type="text"
                required
                className="relative block w-full rounded-md border-0 py-1.5 text-app-foreground ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3 bg-app-surface"
                placeholder={t('auth.register.namePlaceholder')}
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="email-address" className="sr-only">{t('auth.register.emailLabel')}</label>
              <input
                id="email-address"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="relative block w-full rounded-md border-0 py-1.5 text-app-foreground ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3 bg-app-surface"
                placeholder={t('auth.register.emailPlaceholder')}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="password" className="sr-only">{t('auth.register.passwordLabel')}</label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="new-password"
                required
                className="relative block w-full rounded-md border-0 py-1.5 text-app-foreground ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3 bg-app-surface"
                placeholder={t('auth.register.passwordPlaceholder')}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="role" className="block text-sm font-medium leading-6 text-app-foreground">{t('auth.register.roleLabel')}</label>
              <select
                id="role"
                name="role"
                className="mt-2 block w-full rounded-md border-0 py-1.5 pl-3 pr-10 text-app-foreground ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-indigo-600 sm:text-sm sm:leading-6 bg-app-surface"
                value={role}
                onChange={(e) => setRole(e.target.value as Role)}
              >
                <option value="learner">{t('auth.register.role.learner')}</option>
                <option value="educator">{t('auth.register.role.educator')}</option>
                <option value="parent">{t('auth.register.role.parent')}</option>
                <option value="site">{t('auth.register.role.site')}</option>
                <option value="partner">{t('auth.register.role.partner')}</option>
              </select>
            </div>
          </div>

          {/* --- Privacy Consent & Age Verification --- */}
          <div className="space-y-4 rounded-md border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-800/50">
            {/* Age band selection */}
            <div>
              <label htmlFor="age-band" className="block text-sm font-medium leading-6 text-app-foreground">
                Age of the primary user of this account
              </label>
              <select
                id="age-band"
                name="age-band"
                required
                className="mt-2 block w-full rounded-md border-0 py-1.5 pl-3 pr-10 text-app-foreground ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-indigo-600 sm:text-sm sm:leading-6 bg-app-surface"
                value={ageBand}
                onChange={(e) => {
                  setAgeBand(e.target.value as AgeBand | '');
                  if (e.target.value !== 'under13') {
                    setParentConsentConfirmed(false);
                  }
                }}
              >
                <option value="" disabled>
                  Select age range
                </option>
                <option value="under13">Under 13</option>
                <option value="13-17">13-17</option>
                <option value="18+">18+</option>
              </select>
            </div>

            {/* Under-13 COPPA banner */}
            {isUnder13 && (
              <div className="rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800 dark:border-amber-600 dark:bg-amber-900/30 dark:text-amber-200">
                Accounts for children under 13 require parental/guardian consent. A parent or guardian must complete this registration.
              </div>
            )}

            {/* Parent/guardian consent for under-13 */}
            {isUnder13 && (
              <div className="flex items-start gap-3">
                <input
                  id="parent-consent"
                  name="parent-consent"
                  type="checkbox"
                  checked={parentConsentConfirmed}
                  onChange={(e) => setParentConsentConfirmed(e.target.checked)}
                  className="mt-1 h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                />
                <label htmlFor="parent-consent" className="text-sm text-app-foreground">
                  I confirm I am the parent/guardian of this child and consent to their use of this platform.
                </label>
              </div>
            )}

            {/* Privacy policy consent */}
            <div className="flex items-start gap-3">
              <input
                id="privacy-consent"
                name="privacy-consent"
                type="checkbox"
                checked={consentAccepted}
                onChange={(e) => setConsentAccepted(e.target.checked)}
                className="mt-1 h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
              />
              <label htmlFor="privacy-consent" className="text-sm text-app-foreground">
                I agree to the{' '}
                <a href={`/${locale}/privacy`} target="_blank" rel="noopener noreferrer" className="font-medium text-app-primary hover:text-app-primary-emphasis underline">
                  Privacy Policy
                </a>{' '}
                and consent to the processing of personal information as described.
              </label>
            </div>

            {/* Terms of Service consent */}
            <div className="flex items-start gap-3">
              <input
                id="tos-consent"
                name="tos-consent"
                type="checkbox"
                checked={tosAccepted}
                onChange={(e) => setTosAccepted(e.target.checked)}
                className="mt-1 h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
              />
              <label htmlFor="tos-consent" className="text-sm text-app-foreground">
                I agree to the{' '}
                <a href={`/${locale}/terms`} target="_blank" rel="noopener noreferrer" className="font-medium text-app-primary hover:text-app-primary-emphasis underline">
                  Terms of Service
                </a>
                .
              </label>
            </div>

            {/* PIPEDA cross-border disclosure */}
            <p className="text-xs text-app-muted">
              Your data may be processed in Canada and the United States. By creating an account, you acknowledge this cross-border data transfer.
            </p>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading || !consentValid}
              onClick={() => trackInteraction('help_accessed', { cta: 'auth_register_submit', role })}
              className="min-touch-target relative flex w-full justify-center rounded-md bg-app-primary px-4 py-3 text-sm font-semibold text-app-primary-foreground hover:bg-app-primary-emphasis focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring disabled:opacity-50"
            >
              {loading ? t('auth.register.submitting') : t('auth.register.submit')}
            </button>
          </div>

          <div className="text-center text-sm">
            <a
              href={`/${locale}/login`}
              className="app-touch-link font-medium text-app-primary hover:text-app-primary-emphasis"
              onClick={() => trackInteraction('feature_discovered', { cta: 'auth_register_to_login' })}
            >
              {t('auth.register.switchToLogin')}
            </a>
          </div>
        </form>
      </div>
    </div>
  );
}
