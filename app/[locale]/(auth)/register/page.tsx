'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '@/src/firebase/client-init';
import { createUserDocument } from '@/src/lib/auth/createUser';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import type { Role } from '@/schema';
import { useI18n } from '@/src/lib/i18n/useI18n';

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

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // 1. Create Auth User
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      // 2. Update Profile
      if (displayName) {
        await updateProfile(user, { displayName });
      }

      // 3. Create Firestore Document
      await createUserDocument({
        uid: user.uid,
        email: user.email!,
        role,
        displayName,
        photoURL: user.photoURL || undefined,
      });

      // 4. Redirect to Dashboard (Redirector will handle role routing)
      router.push(`/${locale}/dashboard`);
    } catch (err: any) {
      console.error('Registration error:', err);
      setError(err.message || t('auth.register.fallbackError'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 p-4">
      <div className="w-full max-w-md space-y-8 rounded-lg bg-white p-8 shadow-md">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight text-gray-900">{t('auth.register.title')}</h2>
          <p className="mt-2 text-sm text-gray-600">{t('auth.register.subtitle')}</p>
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
                className="relative block w-full rounded-md border-0 py-1.5 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3"
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
                className="relative block w-full rounded-md border-0 py-1.5 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3"
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
                className="relative block w-full rounded-md border-0 py-1.5 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:z-10 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6 px-3"
                placeholder={t('auth.register.passwordPlaceholder')}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="role" className="block text-sm font-medium leading-6 text-gray-900">{t('auth.register.roleLabel')}</label>
              <select
                id="role"
                name="role"
                className="mt-2 block w-full rounded-md border-0 py-1.5 pl-3 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-indigo-600 sm:text-sm sm:leading-6"
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

          <div>
            <button
              type="submit"
              disabled={loading}
              onClick={() => trackInteraction('help_accessed', { cta: 'auth_register_submit', role })}
              className="group relative flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50"
            >
              {loading ? t('auth.register.submitting') : t('auth.register.submit')}
            </button>
          </div>
          
          <div className="text-center text-sm">
            <a
              href={`/${locale}/login`}
              className="font-medium text-indigo-600 hover:text-indigo-500"
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
