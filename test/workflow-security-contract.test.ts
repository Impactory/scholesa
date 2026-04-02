import fs from 'fs';
import path from 'path';
import {
  WORKFLOW_ROUTE_DEFINITIONS,
  type WorkflowRouteDefinition,
} from '@/src/lib/routing/workflowRoutes';

function getCaseBody(source: string, routePath: string): string {
  const escapedPath = routePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const matcher = new RegExp(
    `case\\s+'${escapedPath}'\\s*:\\s*([\\s\\S]*?)(?=\\n\\s*case\\s+'|\\n\\s*default:)`,
    'g',
  );
  const bodies: string[] = [];
  let match: RegExpExecArray | null;
  while ((match = matcher.exec(source)) !== null) {
    bodies.push(match[1]);
  }
  return bodies.join('\n');
}

function routeRequiresCallableBoundary(route: WorkflowRouteDefinition): boolean {
  return route.dataMode === 'callable';
}

describe('Workflow security and boundary contracts', () => {
  it('uses callable boundaries for callable routes', () => {
    const workflowDataPath = path.join(process.cwd(), 'src/features/workflows/workflowData.ts');
    const workflowDataSource = fs.readFileSync(workflowDataPath, 'utf8');

    const dedicatedCallableLoaders: Record<string, string[]> = {
      '/parent/summary': ['loadParentSummary('],
      '/parent/billing': ['loadParentBillingRecords('],
      '/site/billing': ['loadSiteBillingRecords('],
      '/hq/analytics': ['loadHqAnalyticsRecords('],
      '/hq/billing': ['loadHqBillingRecords('],
      '/hq/role-switcher': ['loadHqRoleSwitcherRecords('],
    };

    for (const route of WORKFLOW_ROUTE_DEFINITIONS) {
      if (!routeRequiresCallableBoundary(route)) continue;

      const caseBody = getCaseBody(workflowDataSource, route.path);
      expect(caseBody.length).toBeGreaterThan(0);

      const hasGenericCallableLoader =
        caseBody.includes('loadCallableRows(') || caseBody.includes('httpsCallable(');
      const hasDedicatedCallableLoader =
        (dedicatedCallableLoaders[route.path] || []).some((marker) => caseBody.includes(marker));

      expect(
        hasGenericCallableLoader || hasDedicatedCallableLoader,
      ).toBe(true);
    }
  });

  it('keeps workflow Firestore collection usage covered by explicit rules matches', () => {
    const workflowDataPath = path.join(process.cwd(), 'src/features/workflows/workflowData.ts');
    const rulesPath = path.join(process.cwd(), 'firestore.rules');

    const workflowDataSource = fs.readFileSync(workflowDataPath, 'utf8');
    const rulesSource = fs.readFileSync(rulesPath, 'utf8');

    const referencedCollections = new Set(
      [...workflowDataSource.matchAll(/collection\(firestore,\s*'([^']+)'\)/g)].map((match) => match[1]),
    );
    const rulesCollections = new Set(
      [...rulesSource.matchAll(/match\s+\/([^/]+)\//g)].map((match) => match[1]),
    );

    const missingRuleMatches = [...referencedCollections].filter((collectionName) => {
      return !rulesCollections.has(collectionName);
    });

    expect(missingRuleMatches).toEqual([]);
  });
});
