import fs from 'fs';
import path from 'path';
import { ALL_WORKFLOW_PATHS, ROLE_DEFAULT_WORKFLOW_ROUTE } from '@/src/lib/routing/workflowRoutes';

function parseEnabledFlutterRoutes(routerSource: string): string[] {
  const matcher = /'([^']+)':\s*true/g;
  const results = new Set<string>();
  let match: RegExpExecArray | null = matcher.exec(routerSource);
  while (match) {
    results.add(match[1]);
    match = matcher.exec(routerSource);
  }
  return Array.from(results.values());
}

// Routes that only exist on one platform by design.
const webOnlyRoutes = new Set([
  '/educator/evidence',
  '/educator/verification',
  '/hq/capabilities',
  '/parent/passport',
  '/site/clever',
]);
const flutterOnlyRoutes = new Set([
  '/hq/exports',
  '/learner/credentials',
  '/learner/onboarding',
  '/learner/settings',
  '/parent/child/:learnerId',
  '/parent/consent',
  '/parent/messages',
  '/parent/settings',
  '/site/audit',
  '/site/consent',
  '/site/pickup-auth',
]);

describe('Web workflow route parity with Flutter registry', () => {
  it('matches enabled Flutter workflow paths exactly (excluding known platform-specific routes)', () => {
    const flutterRouterPath = path.join(
      process.cwd(),
      'apps/empire_flutter/app/lib/router/app_router.dart',
    );
    const flutterRouterSource = fs.readFileSync(flutterRouterPath, 'utf8');
    const enabledFlutterRoutes = parseEnabledFlutterRoutes(flutterRouterSource).filter((route) => {
      return !['/', '/welcome', '/login', '/register'].includes(route);
    });

    const flutterSet = new Set(enabledFlutterRoutes.filter((r) => !flutterOnlyRoutes.has(r)));
    const webSet = new Set(ALL_WORKFLOW_PATHS.filter((r) => !webOnlyRoutes.has(r)));

    expect(webSet).toEqual(flutterSet);
  });

  it('has concrete Next page files for all canonical workflow routes', () => {
    for (const routePath of ALL_WORKFLOW_PATHS) {
      const filePath = path.join(
        process.cwd(),
        `app/[locale]/(protected)${routePath}/page.tsx`,
      );
      expect(fs.existsSync(filePath)).toBe(true);
    }
  });

  it('keeps role defaults aligned to canonical workflow landing routes', () => {
    expect(ROLE_DEFAULT_WORKFLOW_ROUTE).toEqual({
      learner: 'learner/today',
      educator: 'educator/today',
      parent: 'parent/summary',
      site: 'site/dashboard',
      partner: 'partner/listings',
      hq: 'hq/sites',
    });
  });
});
