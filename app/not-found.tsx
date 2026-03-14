'use client';

import Link from 'next/link';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';
import { ThemeModeToggle } from '@/src/lib/theme/ThemeModeToggle';

export default function NotFound() {
  const trackInteraction = useInteractionTracking();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-app-canvas">
      <div className="fixed right-4 top-4 z-10">
        <ThemeModeToggle compact />
      </div>
      <h1 className="text-4xl font-bold text-app-foreground">404 - Page Not Found</h1>
      <p className="mt-4 text-lg text-app-muted">The page you are looking for does not exist.</p>
      <Link
        href="/"
        className="mt-8 min-touch-target rounded-md bg-app-primary px-4 py-3 text-app-primary-foreground hover:bg-app-primary-emphasis"
        onClick={() => trackInteraction('help_accessed', { cta: 'not_found_home' })}
      >
        Go back to the homepage
      </Link>
    </div>
  );
}
