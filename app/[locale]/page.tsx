'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { useI18n } from '@/src/lib/i18n/useI18n';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

export default function LandingPage() {
  const { locale, t } = useI18n();
  const trackInteraction = useInteractionTracking();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-app-canvas p-4">
      <div className="fixed right-4 top-4 z-10">
        <ThemeModeToggle compact />
      </div>
      <div className="text-center">
        <Image
          src="/logo/scholesa-logo-192.png"
          alt=""
          aria-hidden="true"
          width={80}
          height={80}
          priority
          className="mx-auto mb-6 h-20 w-20"
        />
        <h1 className="text-4xl font-bold tracking-tight text-app-foreground sm:text-6xl">
          {t('landing.title')}
        </h1>
        <p className="mt-6 text-lg leading-8 text-app-muted">
          {t('landing.tagline')}
        </p>
        <div className="mt-10 flex items-center justify-center gap-x-6">
          <Link
            href={`/${locale}/login`}
            className="min-touch-target rounded-md bg-app-primary px-4 py-3 text-sm font-semibold text-app-primary-foreground shadow-sm hover:bg-app-primary-emphasis focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
            onClick={() => trackInteraction('feature_discovered', { cta: 'landing_login' })}
          >
            {t('landing.loginCta')}
          </Link>
          <Link
            href={`/${locale}/register`}
            className="text-sm font-semibold leading-6 text-app-foreground"
            onClick={() => trackInteraction('feature_discovered', { cta: 'landing_register' })}
          >
            {t('landing.registerArrow')}
          </Link>
        </div>
      </div>
    </div>
  );
}
