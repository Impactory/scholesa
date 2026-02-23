import type { Metadata } from 'next';
import { StudentMotivationProfile } from '@/src/components/motivation/StudentMotivationProfile';
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
    title: translate(normalized, 'meta.learnerProfile.title'),
    description: translate(normalized, 'meta.learnerProfile.description'),
  };
}

export default function LearnerProfilePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <StudentMotivationProfile />
    </div>
  );
}
