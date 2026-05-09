import fs from 'fs';
import path from 'path';

function parseKnownEnabledRoutes(routerSource: string): string[] {
  const matches = [...routerSource.matchAll(/'([^']+)'\s*:\s*true/g)].map((match) => match[1]);
  return matches.filter((routePath) => !['/', '/welcome', '/login', '/register'].includes(routePath));
}

function parseGoRoutePaths(routerSource: string): string[] {
  const matches = [...routerSource.matchAll(/GoRoute\(\s*path:\s*'([^']+)'/g)].map((match) => match[1]);
  return matches.filter((routePath) => !['/', '/welcome', '/login', '/register'].includes(routePath));
}

function parseRouteAliases(routerSource: string): string[] {
  return [...routerSource.matchAll(/'([^']+)'\s*:\s*'[^']+'/g)].map((match) => match[1]);
}

describe('Flutter workflow route registry parity', () => {
  it('keeps kKnownRoutes enabled paths aligned with concrete GoRoute paths', () => {
    const flutterRouterPath = path.join(process.cwd(), 'apps/empire_flutter/app/lib/router/app_router.dart');
    const source = fs.readFileSync(flutterRouterPath, 'utf8');

    const knownEnabled = new Set(parseKnownEnabledRoutes(source));
    const aliasRoutes = new Set(parseRouteAliases(source));
    const declaredGoRoutes = new Set(parseGoRoutePaths(source).filter((routePath) => !aliasRoutes.has(routePath)));

    expect(declaredGoRoutes).toEqual(knownEnabled);
  });
});
