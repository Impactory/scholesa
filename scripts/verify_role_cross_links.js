#!/usr/bin/env node
'use strict';

const path = require('path');
const {
  analyzeCrossLinks,
  buildRoleCrossLinksReport,
  initializeAdmin,
  loadCrossLinkState,
  parseArgs,
  writeRoleCrossLinksReport,
} = require('./role_cross_links_common');
const { buildCanonicalReport } = require('./vibe_audit_report_schema');
const {
  initializeFirestoreRestFallback,
  initializeFirestoreUserRestFallback,
  isCredentialAuthError,
} = require('./firebase_runtime_auth');

function normalizeCredentialLabel(value) {
  if (typeof value !== 'string' || value.trim().length === 0) return null;
  if (value === 'applicationDefault' || value === 'gcloud-auth-user') {
    return value;
  }
  if (!path.isAbsolute(value)) {
    return value;
  }
  return path.relative(process.cwd(), value);
}

async function run() {
  const args = parseArgs(process.argv.slice(2), { allowApply: false });
  let report;

  try {
    let { db, credentialPath, projectId } = initializeAdmin(args);
    let transport = 'firebaseAdmin';
    let state;
    try {
      state = await loadCrossLinkState(db, args.siteId);
    } catch (error) {
      if (!isCredentialAuthError(error)) {
        throw error;
      }
      let fallback;
      try {
        fallback = await initializeFirestoreUserRestFallback(projectId, {
          email: process.env.CROSS_LINK_FALLBACK_EMAIL,
          password: process.env.TEST_USER_PASSWORD,
        });
      } catch (userFallbackError) {
        if (!isCredentialAuthError(userFallbackError)) {
          throw userFallbackError;
        }
        fallback = initializeFirestoreRestFallback(projectId);
      }
      db = fallback.db;
      credentialPath = fallback.credentialPath;
      projectId = fallback.projectId;
      transport = fallback.transport;
      state = await loadCrossLinkState(db, args.siteId);
    }
    const analysis = analyzeCrossLinks(state);
    report = buildRoleCrossLinksReport(args, analysis, {
      mode: 'verify',
      credentialPath: normalizeCredentialLabel(credentialPath),
      projectId: projectId || null,
      transport,
    });
  } catch (error) {
    report = buildCanonicalReport({
      reportName: 'role-cross-links',
      env: args.env,
      pass: false,
      checks: [
        {
          id: 'role_cross_links_verifier_execution',
          pass: false,
          details: {
            error: error instanceof Error ? error.message : String(error),
          },
        },
      ],
      metadata: {
        mode: 'verify',
        siteId: args.siteId,
      },
    });
  }

  const outputPath = writeRoleCrossLinksReport(report);
  const output = {
    status: report.pass ? 'PASS' : 'FAIL',
    env: args.env,
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
