import React from 'react';
import type { Metadata } from 'next';
import Script from 'next/script';
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
      { url: '/scholesa.svg', type: 'image/svg+xml' },
    ],
    shortcut: ['/scholesa.svg'],
    apple: [{ url: '/scholesa.svg', type: 'image/svg+xml' }],
  },
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
