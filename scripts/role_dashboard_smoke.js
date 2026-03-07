#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {
  buildCanonicalReport,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const ROLE_WORKFLOW_ROOTS = [
  {
    role: 'learner',
    defaultPath: '/learner/today',
    rootPagePath: 'app/[locale]/(protected)/learner/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/learner/today/page.tsx',
  },
  {
    role: 'educator',
    defaultPath: '/educator/today',
    rootPagePath: 'app/[locale]/(protected)/educator/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/educator/today/page.tsx',
  },
  {
    role: 'parent',
    defaultPath: '/parent/summary',
    rootPagePath: 'app/[locale]/(protected)/parent/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/parent/summary/page.tsx',
  },
  {
    role: 'site',
    defaultPath: '/site/dashboard',
    rootPagePath: 'app/[locale]/(protected)/site/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/site/dashboard/page.tsx',
  },
  {
    role: 'partner',
    defaultPath: '/partner/listings',
    rootPagePath: 'app/[locale]/(protected)/partner/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/partner/listings/page.tsx',
  },
  {
    role: 'hq',
    defaultPath: '/hq/sites',
    rootPagePath: 'app/[locale]/(protected)/hq/page.tsx',
    workflowPagePath: 'app/[locale]/(protected)/hq/sites/page.tsx',
  },
];

const SHARED_WORKFLOW_PAGE_PATH = 'src/features/workflows/WorkflowRoutePage.tsx';
const DASHBOARD_REDIRECT_PAGE_PATH = 'app/[locale]/(protected)/dashboard/page.tsx';
const WORKFLOW_ROUTES_CONFIG_PATH = 'src/lib/routing/workflowRoutes.ts';

function toCheckId(value) {
  return value.replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
}

function getFileSource(filePath) {
  const absolutePath = path.resolve(process.cwd(), filePath);
  if (!fs.existsSync(absolutePath)) {
    return { exists: false, absolutePath, source: '' };
  }
  return { exists: true, absolutePath, source: fs.readFileSync(absolutePath, 'utf8') };
}

function addExistsCheck(checks, checkId, filePath, exists) {
  checks.push({
    id: checkId,
    pass: exists,
    details: {
      filePath,
      ...(exists ? {} : { reason: 'missing_file' }),
    },
  });
}

function addSnippetCheck(checks, checkId, filePath, source, snippet) {
  checks.push({
    id: checkId,
    pass: source.includes(snippet),
    details: {
      filePath,
      snippet,
    },
  });
}

function parseArgs(argv) {
  const args = {
    env: resolveEnv(process.env.VIBE_ENV || process.env.NODE_ENV || 'dev'),
    strict: false,
  };

  for (const arg of argv) {
    if (arg === '--strict') {
      args.strict = true;
      continue;
    }
    if (!arg.startsWith('--')) continue;
    const [rawKey, rawValue] = arg.slice(2).split('=');
    if (rawValue === undefined) continue;
    if (rawKey === 'env') args.env = resolveEnv(rawValue);
  }

  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const checks = [];

  for (const roleRoot of ROLE_WORKFLOW_ROOTS) {
    const rootFile = getFileSource(roleRoot.rootPagePath);
    addExistsCheck(checks, `role_root_${roleRoot.role}_page_exists`, roleRoot.rootPagePath, rootFile.exists);
    if (rootFile.exists) {
      addSnippetCheck(
        checks,
        `role_root_${roleRoot.role}_redirects_to_default_workflow`,
        roleRoot.rootPagePath,
        rootFile.source,
        `redirect(\`/\${locale}${roleRoot.defaultPath}\`)`,
      );
    }

    const workflowFile = getFileSource(roleRoot.workflowPagePath);
    addExistsCheck(
      checks,
      `role_default_workflow_${roleRoot.role}_page_exists`,
      roleRoot.workflowPagePath,
      workflowFile.exists,
    );
    if (workflowFile.exists) {
      addSnippetCheck(
        checks,
        `role_default_workflow_${roleRoot.role}_uses_workflow_route_page`,
        roleRoot.workflowPagePath,
        workflowFile.source,
        'WorkflowRoutePage',
      );
      addSnippetCheck(
        checks,
        `role_default_workflow_${roleRoot.role}_wires_canonical_path`,
        roleRoot.workflowPagePath,
        workflowFile.source,
        `routePath='${roleRoot.defaultPath}'`,
      );
    }
  }

  const sharedWorkflowPage = getFileSource(SHARED_WORKFLOW_PAGE_PATH);
  addExistsCheck(
    checks,
    'shared_workflow_route_page_exists',
    SHARED_WORKFLOW_PAGE_PATH,
    sharedWorkflowPage.exists,
  );
  if (sharedWorkflowPage.exists) {
    const sharedRequiredSnippets = [
      'RoleRouteGuard allowedRoles={route.allowedRoles}',
      "usePageViewTracking(`workflow${routePath.replace(/\\//g, '_')}`",
      "trackInteraction('feature_discovered'",
      'loadWorkflowRecords',
      'createWorkflowRecord',
      'updateWorkflowRecord',
      'deleteWorkflowRecord',
    ];

    for (const snippet of sharedRequiredSnippets) {
      addSnippetCheck(
        checks,
        `shared_workflow_route_page_includes_${toCheckId(snippet)}`,
        SHARED_WORKFLOW_PAGE_PATH,
        sharedWorkflowPage.source,
        snippet,
      );
    }
  }

  const dashboardRedirectPage = getFileSource(DASHBOARD_REDIRECT_PAGE_PATH);
  addExistsCheck(
    checks,
    'dashboard_redirect_page_exists',
    DASHBOARD_REDIRECT_PAGE_PATH,
    dashboardRedirectPage.exists,
  );
  if (dashboardRedirectPage.exists) {
    addSnippetCheck(
      checks,
      'dashboard_redirect_uses_getroledefaultroute',
      DASHBOARD_REDIRECT_PAGE_PATH,
      dashboardRedirectPage.source,
      'getRoleDefaultRoute(normalizedRole)',
    );
  }

  const workflowRoutesConfig = getFileSource(WORKFLOW_ROUTES_CONFIG_PATH);
  addExistsCheck(
    checks,
    'workflow_routes_config_exists',
    WORKFLOW_ROUTES_CONFIG_PATH,
    workflowRoutesConfig.exists,
  );
  if (workflowRoutesConfig.exists) {
    for (const roleRoot of ROLE_WORKFLOW_ROOTS) {
      const mappingLine = `${roleRoot.role}: '${roleRoot.defaultPath.slice(1)}'`;
      addSnippetCheck(
        checks,
        `workflow_routes_config_maps_${roleRoot.role}_default`,
        WORKFLOW_ROUTES_CONFIG_PATH,
        workflowRoutesConfig.source,
        mappingLine,
      );
    }
  }

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: 'role-dashboard-smoke',
    env: args.env,
    pass,
    checks,
    metadata: {
      rolesChecked: ROLE_WORKFLOW_ROOTS.map((rule) => rule.role),
    },
  });
  const outputPath = writeCanonicalReport('role-dashboard-smoke', report);

  const output = {
    status: pass ? 'PASS' : 'FAIL',
    env: args.env,
    report: path.relative(process.cwd(), outputPath),
    failedChecks: checks.filter((check) => check.pass !== true).map((check) => check.id),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!pass && args.strict) {
    process.exitCode = 1;
  } else if (!pass) {
    process.exitCode = 1;
  }
}

main();
