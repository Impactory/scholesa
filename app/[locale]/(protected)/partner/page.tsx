import { redirect } from 'next/navigation';

export default async function PartnerRootRedirect({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect(`/${locale}/partner/listings`);
}
