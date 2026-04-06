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
