'use client';

import Link from 'next/link';
import { useInteractionTracking } from '@/src/hooks/useTelemetry';

export default function NotFound() {
  const trackInteraction = useInteractionTracking();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-app-canvas">
      <h1 className="text-4xl font-bold text-app-foreground">404 - Page Not Found</h1>
      <p className="mt-4 text-lg text-app-muted">The page you are looking for does not exist.</p>
      <Link
        href="/"
        className="mt-8 px-4 py-2 text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
        onClick={() => trackInteraction('help_accessed', { cta: 'not_found_home' })}
      >
        Go back to the homepage
      </Link>
    </div>
  );
}
