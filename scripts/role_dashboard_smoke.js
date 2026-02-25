#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {
  buildCanonicalReport,
  resolveEnv,
  writeCanonicalReport,
} = require('./vibe_audit_report_schema');

const ROLE_PAGE_RULES = [
  {
    role: 'learner',
    filePath: 'app/[locale]/(protected)/learner/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['learner']}",
      "usePageViewTracking('learner_dashboard'",
      'fetchRoleDashboardSnapshot',
    ],
  },
  {
    role: 'educator',
    filePath: 'app/[locale]/(protected)/educator/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['educator']}",
      "usePageViewTracking('educator_dashboard'",
      'fetchRoleDashboardSnapshot',
      'fetchRoleLinkedRoster',
    ],
  },
  {
    role: 'parent',
    filePath: 'app/[locale]/(protected)/parent/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['parent']}",
      "usePageViewTracking('parent_dashboard'",
      'fetchParentDashboardBundle',
      'fetchRoleDashboardSnapshot',
    ],
  },
  {
    role: 'site',
    filePath: 'app/[locale]/(protected)/site/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['site']}",
      "usePageViewTracking('site_dashboard'",
      'fetchRoleDashboardSnapshot',
      'fetchRoleLinkedRoster',
    ],
  },
  {
    role: 'partner',
    filePath: 'app/[locale]/(protected)/partner/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['partner']}",
      "usePageViewTracking('partner_dashboard'",
      'fetchRoleDashboardSnapshot',
    ],
  },
  {
    role: 'hq',
    filePath: 'app/[locale]/(protected)/hq/page.tsx',
    requiredSnippets: [
      "RoleRouteGuard allowedRoles={['hq']}",
      "usePageViewTracking('hq_dashboard'",
      'fetchRoleDashboardSnapshot',
    ],
  },
];

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

  for (const rule of ROLE_PAGE_RULES) {
    const absolutePath = path.resolve(process.cwd(), rule.filePath);
    if (!fs.existsSync(absolutePath)) {
      checks.push({
        id: `role_page_${rule.role}_exists`,
        pass: false,
        details: {
          filePath: rule.filePath,
          reason: 'missing_file',
        },
      });
      continue;
    }

    const source = fs.readFileSync(absolutePath, 'utf8');
    checks.push({
      id: `role_page_${rule.role}_exists`,
      pass: true,
      details: { filePath: rule.filePath },
    });

    for (const snippet of rule.requiredSnippets) {
      checks.push({
        id: `role_page_${rule.role}_includes_${snippet
          .replace(/[^a-zA-Z0-9]+/g, '_')
          .replace(/^_+|_+$/g, '')
          .toLowerCase()}`,
        pass: source.includes(snippet),
        details: {
          filePath: rule.filePath,
          snippet,
        },
      });
    }

    checks.push({
      id: `role_page_${rule.role}_has_cta_telemetry`,
      pass: source.includes("trackInteraction('feature_discovered'"),
      details: {
        filePath: rule.filePath,
      },
    });
  }

  const pass = checks.every((check) => check.pass === true);
  const report = buildCanonicalReport({
    reportName: 'role-dashboard-smoke',
    env: args.env,
    pass,
    checks,
    metadata: {
      rolesChecked: ROLE_PAGE_RULES.map((rule) => rule.role),
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
