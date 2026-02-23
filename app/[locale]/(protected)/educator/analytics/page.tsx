import type { Metadata } from 'next';
import { AnalyticsDashboard } from '@/src/components/analytics/AnalyticsDashboard';
import { normalizeLocale } from '@/src/lib/i18n/config';
import { translate } from '@/src/lib/i18n/messages';

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const normalized = normalizeLocale(locale);
  return {
    title: translate(normalized, 'meta.educatorAnalytics.title'),
    description: translate(normalized, 'meta.educatorAnalytics.description'),
  };
}

export default async function AnalyticsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const normalized = normalizeLocale(locale);
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900">{translate(normalized, 'analytics.educator.title')}</h1>
        <p className="mt-2 text-gray-600">{translate(normalized, 'analytics.educator.subtitle')}</p>
      </div>
      
      <AnalyticsDashboard />
    </div>
  );
}
