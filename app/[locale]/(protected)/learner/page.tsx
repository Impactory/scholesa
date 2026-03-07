import { redirect } from 'next/navigation';

export default async function LearnerRootRedirect({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect(`/${locale}/learner/today`);
}
