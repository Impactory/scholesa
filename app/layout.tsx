import React from 'react';
import type { Metadata, Viewport } from 'next';
import './globals.css';
import { PageTransition } from '@/src/components/layout/PageTransition';
import { OfflineIndicator } from '@/src/components/ui/OfflineIndicator';
import { ServiceWorkerRegister } from '@/src/components/pwa/ServiceWorkerRegister';
import { ThemeProvider } from '@/src/lib/theme/ThemeProvider';

export const metadata: Metadata = {
  title: 'Scholesa – Skills-First Learning OS',
  description: 'A K–12 skills-first operating system for schools and learning studios.',
  manifest: '/manifest.webmanifest',
  icons: {
    icon: [
      { url: '/logo/scholesa-logo-192.png', type: 'image/png', sizes: '192x192' },
    ],
    shortcut: ['/logo/scholesa-logo-192.png'],
    apple: [{ url: '/logo/scholesa-logo-192.png', type: 'image/png', sizes: '192x192' }],
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" data-theme="light" suppressHydrationWarning>
      <body className="font-scholesa">
        <ServiceWorkerRegister />
        <ThemeProvider>
          <OfflineIndicator />
          <PageTransition>{children}</PageTransition>
        </ThemeProvider>
      </body>
    </html>
  );
}
