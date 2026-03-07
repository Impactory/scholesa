import { redirect } from 'next/navigation';

export default async function HqRootRedirect({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect(`/${locale}/hq/sites`);
}
