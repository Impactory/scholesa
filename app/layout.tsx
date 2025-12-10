import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { PageTransition } from '@/src/components/layout/PageTransition';
import { AuthProvider } from '@/src/lib/auth/useUser';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Scholesa – Future Skills Academy',
  description: 'An Education 2.0 operating system for K–9 learning studios and schools.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <AuthProvider>
          <PageTransition>{children}</PageTransition>
        </AuthProvider>
      </body>
    </html>
  );
}
