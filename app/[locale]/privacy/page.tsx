import type { Metadata } from 'next';
import Link from 'next/link';
import { getTranslations } from '@/lib/i18n';

export const metadata: Metadata = {
  title: 'Privacy Policy | Scholesa',
  description: 'Privacy commitments for Scholesa web and mobile learning experiences.',
};

export default async function PrivacyPolicyPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const { t } = await getTranslations(locale, 'privacy');
  const tx = (key: string): string => t(key) ?? key;

  return (
    <main className="min-h-screen bg-app-canvas px-4 py-10 text-app-foreground sm:px-6 lg:px-8">
      <article className="mx-auto max-w-4xl">
        <Link
          href={`/${locale}`}
          className="inline-flex min-touch-target items-center rounded-md border border-app bg-app-surface px-4 py-2 text-sm font-semibold text-app-foreground hover:bg-app-surface-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-app-ring"
        >
          {tx('homeLink')}
        </Link>

        <header className="mt-8 border-b border-app pb-6">
          <p className="text-sm font-bold uppercase text-cyan-700 dark:text-cyan-300">
            {tx('kicker')}
          </p>
          <h1 className="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
            {tx('title')}
          </h1>
          <p className="mt-4 text-sm leading-6 text-slate-600 dark:text-slate-300">
            {tx('lastUpdated')}
          </p>
        </header>

        <div className="prose prose-slate mt-8 max-w-none dark:prose-invert prose-a:text-cyan-700 dark:prose-a:text-cyan-300">
          <p>{tx('intro')}</p>

          <h2>{tx('informationHeading')}</h2>
          <p>{tx('informationBody')}</p>

          <h2>{tx('voiceHeading')}</h2>
          <p>{tx('voiceBody')}</p>

          <h2>{tx('useHeading')}</h2>
          <p>{tx('useBody')}</p>

          <h2>{tx('aiHeading')}</h2>
          <p>{tx('aiBody')}</p>

          <h2>{tx('sharingHeading')}</h2>
          <p>{tx('sharingBody')}</p>

          <h2>{tx('storageHeading')}</h2>
          <p>{tx('storageBody')}</p>

          <h2>{tx('contactHeading')}</h2>
          <p>{tx('contactBody')}</p>
        </div>
      </article>
    </main>
  );
}