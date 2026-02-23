'use client';

import React, { useState } from 'react';
import { Button } from '@/src/components/ui/Button';
import { Input } from '@/src/components/ui/Input';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useRouter, useParams } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { signInWithGoogle } = useAuthContext();
  const router = useRouter();
  const params = useParams();
  const { t } = useI18n();
  const locale = params ? ((params as any).locale as string) || 'en' : 'en';
  const trackInteraction = useInteractionTracking();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    trackInteraction('help_accessed', { cta: 'legacy_login_email_submit' });
    console.log(t('auth.legacyLogin.emailPasswordNotReady'));
  };

  const handleGoogleSignIn = async () => {
    try {
      trackInteraction('feature_discovered', { cta: 'legacy_login_google' });
      await signInWithGoogle();
      router.replace(`/${locale}/dashboard`);
      router.refresh();
    } catch (error) {
      console.error('Login failed', error);
    }
  };

  return (
    <div className='flex min-h-screen flex-col justify-center bg-gray-50 py-12 sm:px-6 lg:px-8'>
      <div className='sm:mx-auto sm:w-full sm:max-w-md'>
        <h2 className='mt-6 text-center text-3xl font-extrabold text-gray-900'>{t('auth.legacyLogin.title')}</h2>
      </div>

      <div className='mt-8 sm:mx-auto sm:w-full sm:max-w-md'>
        <div className='bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10'>
          <form className='space-y-6' onSubmit={handleSubmit}>
            <Input
              id='email'
              label={t('auth.login.emailLabel')}
              type='email'
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <Input
              id='password'
              label={t('auth.login.passwordLabel')}
              type='password'
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />

            <div>
              <Button type='submit' className='w-full'>
                {t('auth.legacyLogin.submit')}
              </Button>
            </div>
          </form>

          <div className='mt-6'>
            <div className='relative'>
              <div className='absolute inset-0 flex items-center'>
                <div className='w-full border-t border-gray-300' />
              </div>
              <div className='relative flex justify-center text-sm'>
                <span className='bg-white px-2 text-gray-500'>{t('auth.legacyLogin.orContinueWith')}</span>
              </div>
            </div>

            <div className='mt-6'>
               <Button onClick={handleGoogleSignIn} className='w-full' variant='outline'>
                {t('auth.legacyLogin.google')}
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
