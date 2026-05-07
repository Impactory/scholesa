import React from 'react';
import type { Metadata, Viewport } from 'next';
import Script from 'next/script';
import './globals.css';
import { PageTransition } from '@/src/components/layout/PageTransition';
import { AuthProvider } from '@/src/firebase/auth/AuthProvider';
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
        <Script
          id="theme-preload"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{
            __html: '(function(){try{var key=\'scholesa.theme.preference\';var stored=localStorage.getItem(key);var prefersDark=window.matchMedia(\'(prefers-color-scheme: dark)\').matches;var theme=(stored===\'light\'||stored===\'dark\')?stored:(prefersDark?\'dark\':\'light\');document.documentElement.dataset.theme=theme;document.documentElement.style.colorScheme=theme;}catch(e){document.documentElement.dataset.theme=\'light\';document.documentElement.style.colorScheme=\'light\';}})();',
          }}
        />
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
