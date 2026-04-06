'use client';

import React from 'react';
import { Button } from '@/src/components/ui/Button';
import { Input } from '@/src/components/ui/Input';
import { useAuthContext } from '@/src/firebase/auth/AuthProvider';
import { useRouter, useParams } from 'next/navigation';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export function LoginForm() {
  const { signInWithGoogle } = useAuthContext();
  const router = useRouter();
  const params = useParams();
  const { t } = useI18n();
  const locale = params ? ((params as any).locale as string) || 'en' : 'en';
  const trackInteraction = useInteractionTracking();
  const emailPasswordUnavailableMessage = t('auth.legacyLogin.emailPasswordNotReady');

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
    <div className='flex min-h-screen flex-col justify-center bg-app-canvas py-12 sm:px-6 lg:px-8'>
      <div className='sm:mx-auto sm:w-full sm:max-w-md'>
        <h2 className='mt-6 text-center text-3xl font-extrabold text-app-foreground'>{t('auth.legacyLogin.title')}</h2>
      </div>

      <div className='mt-8 sm:mx-auto sm:w-full sm:max-w-md'>
        <div className='bg-app-surface py-8 px-4 shadow sm:rounded-lg sm:px-10 border border-app'>
          <div className='space-y-6'>
            <Input
              id='email'
              label={t('auth.login.emailLabel')}
              type='email'
              value=''
              onChange={() => {}}
              disabled
            />
            <Input
              id='password'
              label={t('auth.login.passwordLabel')}
              type='password'
              value=''
              onChange={() => {}}
              disabled
            />

            <div className='rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800'>
              {emailPasswordUnavailableMessage}
            </div>

            <div>
              <Button
                type='button'
                className='w-full'
                disabled
                onClick={() => {
                  trackInteraction('help_accessed', {
                    cta: 'legacy_login_email_disabled',
                  });
                }}
              >
                {t('auth.legacyLogin.submit')}
              </Button>
            </div>
          </div>

          <div className='mt-6'>
            <div className='relative'>
              <div className='absolute inset-0 flex items-center'>
                <div className='w-full border-t border-gray-300' />
              </div>
              <div className='relative flex justify-center text-sm'>
                <span className='bg-app-surface px-2 text-app-muted'>{t('auth.legacyLogin.orContinueWith')}</span>
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
