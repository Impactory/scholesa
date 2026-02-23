'use client';

import Link from 'next/link';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';

export default function LandingPage() {
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-white p-4">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
          {t('landing.title')}
        </h1>
        <p className="mt-6 text-lg leading-8 text-gray-600">
          {t('landing.tagline')}
        </p>
        <div className="mt-10 flex items-center justify-center gap-x-6">
          <Link
            href={`/${locale}/login`}
            className="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            onClick={() => trackInteraction('feature_discovered', { cta: 'landing_login' })}
          >
            {t('landing.loginCta')}
          </Link>
          <Link
            href={`/${locale}/register`}
            className="text-sm font-semibold leading-6 text-gray-900"
            onClick={() => trackInteraction('feature_discovered', { cta: 'landing_register' })}
          >
            {t('landing.registerArrow')}
          </Link>
        </div>
      </div>
    </div>
  );
}
