import { redirect } from 'next/navigation';

export default async function EducatorLegacyAnalyticsRedirect({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect(`/${locale}/educator/today`);
}
