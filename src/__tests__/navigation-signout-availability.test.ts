import fs from 'node:fs';
import path from 'node:path';

import { ALL_WORKFLOW_PATHS } from '@/src/lib/routing/workflowRoutes';

const repoRoot = path.resolve(__dirname, '../..');

describe('protected web logout availability', () => {
  it('mounts shared Navigation in the protected layout shell', () => {
    const layoutSource = fs.readFileSync(
      path.join(repoRoot, 'app/[locale]/(protected)/layout.tsx'),
      'utf8',
    );

    expect(layoutSource).toContain('<Navigation />');
  });

  it('keeps a global sign-out control in shared Navigation', () => {
    const navigationSource = fs.readFileSync(
      path.join(
        repoRoot,
        'src/features/navigation/components/Navigation.tsx',
      ),
      'utf8',
    );

    expect(navigationSource).toContain(
      'const { user, profile, signOut } = useAuthContext();',
    );
    expect(navigationSource).toContain('await signOut();');
    expect(navigationSource).toContain("t('navigation.signOut')");
    expect(navigationSource).toContain('<Button');
    expect(navigationSource).toContain("import Image from 'next/image';");
    expect(navigationSource).toContain('src="/logo/scholesa-logo-192.png"');
    expect(navigationSource).toContain('aria-label="Scholesa dashboard"');
    expect(navigationSource).toContain('<ThemeModeToggle');
  });

  it('renders theme controls as accessible icon buttons', () => {
    const themeToggleSource = fs.readFileSync(
      path.join(repoRoot, 'src/lib/theme/ThemeModeToggle.tsx'),
      'utf8',
    );

    expect(themeToggleSource).toContain('MonitorIcon');
    expect(themeToggleSource).toContain('SunIcon');
    expect(themeToggleSource).toContain('MoonIcon');
    expect(themeToggleSource).toContain('title={option.label}');
    expect(themeToggleSource).toContain('aria-label={`${t(\'navigation.themeLabel\')}: ${option.label}`}');
    expect(themeToggleSource).toContain('aria-hidden="true"');
    expect(themeToggleSource).not.toContain('{option.label}</button>');
    expect(themeToggleSource).not.toContain('className="sr-only"');
  });

  it('provides localized shared Navigation copy in every root locale', () => {
    for (const locale of ['en', 'es', 'th', 'zh-CN', 'zh-TW']) {
      const messages = JSON.parse(
        fs.readFileSync(path.join(repoRoot, 'locales', `${locale}.json`), 'utf8')
      );

      expect(messages.navigation.signedInAs).toContain('{{identity}}');
      expect(messages.navigation.signOut).toBeTruthy();
    }
  });

  it('uses the canonical Scholesa logo on public entry surfaces', () => {
    for (const filePath of [
      'app/[locale]/page.tsx',
      'app/[locale]/(auth)/login/page.tsx',
      'app/[locale]/(auth)/register/page.tsx',
    ]) {
      const source = fs.readFileSync(path.join(repoRoot, filePath), 'utf8');

      expect(source).toContain("import Image from 'next/image';");
      expect(source).toContain('src="/logo/scholesa-logo-192.png"');
      expect(source).toContain('aria-hidden="true"');
    }
  });

  it('keeps every governed workflow page under the protected layout shell', () => {
    for (const routePath of ALL_WORKFLOW_PATHS) {
      const pagePath = path.join(
        repoRoot,
        'app/[locale]/(protected)',
        routePath.slice(1),
        'page.tsx',
      );

      expect(fs.existsSync(pagePath)).toBe(true);
    }
  });
});
