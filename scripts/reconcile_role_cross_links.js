#!/usr/bin/env node
'use strict';

const path = require('path');
const {
  analyzeCrossLinks,
  applyProposedFixes,
  buildRoleCrossLinksReport,
  initializeAdmin,
  loadCrossLinkState,
  parseArgs,
  writeRoleCrossLinksReport,
} = require('./role_cross_links_common');
const { buildCanonicalReport } = require('./vibe_audit_report_schema');

async function run() {
  const args = parseArgs(process.argv.slice(2), { allowApply: true });
  let report;
  let appliedWrites = 0;

  try {
    const { db, credentialPath, projectId } = initializeAdmin(args);
    const initialState = await loadCrossLinkState(db, args.siteId);
    const initialAnalysis = analyzeCrossLinks(initialState);

    let finalAnalysis = initialAnalysis;
    if (args.apply && initialAnalysis.proposedFixes.length > 0) {
      const result = await applyProposedFixes(db, initialAnalysis.proposedFixes);
      appliedWrites = result.writes;
      const reloadedState = await loadCrossLinkState(db, args.siteId);
      finalAnalysis = analyzeCrossLinks(reloadedState);
    }

    report = buildRoleCrossLinksReport(args, finalAnalysis, {
      mode: 'reconcile',
      applied: args.apply,
      appliedWrites,
      credentialPath: credentialPath ? path.relative(process.cwd(), credentialPath) : null,
      projectId: projectId || null,
    });
  } catch (error) {
    report = buildCanonicalReport({
      reportName: 'role-cross-links',
      env: args.env,
      pass: false,
      checks: [
        {
          id: 'role_cross_links_reconciler_execution',
          pass: false,
          details: {
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
      metadata: {
        mode: 'reconcile',
        siteId: args.siteId,
        applied: args.apply,
        appliedWrites,
      },
    });
  }

  const outputPath = writeRoleCrossLinksReport(report);
  const output = {
    status: report.pass ? 'PASS' : 'FAIL',
    env: args.env,
    siteId: args.siteId,
    apply: args.apply,
    appliedWrites,
    report: path.relative(process.cwd(), outputPath),
    pass: report.pass,
    failedChecks: (report.checks || []).filter((check) => check.pass !== true).map((check) => check.id),
  };

  process.stdout.write(JSON.stringify(output, null, 2) + '\n');

  if (!report.pass) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  process.stderr.write(
    JSON.stringify(
      {
        status: 'FAIL',
        error: error instanceof Error ? error.message : String(error),
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(1);
});
