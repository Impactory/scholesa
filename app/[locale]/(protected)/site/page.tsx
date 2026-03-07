import { redirect } from 'next/navigation';

export default async function SiteRootRedirect({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect(`/${locale}/site/dashboard`);
}
