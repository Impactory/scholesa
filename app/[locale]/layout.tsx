import type { Metadata } from 'next';
import { LocaleDocumentSync } from '@/src/lib/i18n/LocaleDocumentSync';

export const metadata: Metadata = {
  title: 'Scholesa',
  description: 'Future Skills Academy',
};

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  return (
    <>
      <LocaleDocumentSync locale={locale} />
      {children}
    </>
  );
}
