import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { AuthProvider } from '@/src/firebase/auth/AuthProvider';
import { ServiceWorkerLoader } from '@/src/components/ServiceWorkerLoader';
import '../globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Scholesa',
  description: 'Future Skills Academy',
};

export default async function RootLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  return (
    <html lang={locale}>
      <body className={inter.className}>
        <AuthProvider>
          <ServiceWorkerLoader />
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}