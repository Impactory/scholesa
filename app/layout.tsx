import React from 'react';
import type { Metadata } from 'next';
import './globals.css';
import { PageTransition } from '@/src/components/layout/PageTransition';
import { AuthProvider } from '@/src/firebase/auth/AuthProvider';
import { OfflineIndicator } from '@/src/components/ui/OfflineIndicator';
import { ServiceWorkerRegister } from '@/src/components/pwa/ServiceWorkerRegister';
import { ThemeProvider } from '@/src/lib/theme/ThemeProvider';

export const metadata: Metadata = {
  title: 'Scholesa – Future Skills Academy',
  description: 'An Education 2.0 operating system for K–9 learning studios and schools.',
  manifest: '/manifest.webmanifest',
  icons: {
    icon: [
      { url: '/favicon.svg', type: 'image/svg+xml' },
    ],
    shortcut: ['/favicon.svg'],
    apple: [{ url: '/favicon.svg', type: 'image/svg+xml' }],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" data-theme="light">
      <body className="font-scholesa">
        <ServiceWorkerRegister />
        <ThemeProvider>
          <AuthProvider>
            <OfflineIndicator />
            <PageTransition>{children}</PageTransition>
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
