#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const REQUIRED_FILES = [
  'RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md',
  'RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md',
  'RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md',
  'RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md',
  'RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md',
  'docs/BOS_MIA_PROD_SIGNOFF_CHECKLIST.md',
  'apps/empire_flutter/app/docs/vibe/RC3_SIGNOFF_CHECKLIST.md',
];

const REQUIRED_REFERENCES = [
  {
    file: 'RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md',
    includes: [
      'RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md',
      'RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md',
    ],
  },
  {
    file: 'RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md',
    includes: ['RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md'],
  },
  {
    file: 'RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md',
    includes: [
      'RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md',
      'RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md',
    ],
  },
  {
    file: 'docs/BOS_MIA_PROD_SIGNOFF_CHECKLIST.md',
    includes: ['RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md'],
  },
  {
    file: 'apps/empire_flutter/app/docs/vibe/RC3_SIGNOFF_CHECKLIST.md',
    includes: ['RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md'],
  },
  {
    file: 'RC3_OPERATOR_CANARY_SCRIPT_MARCH_8_2026.md',
    includes: ['Historical, Superseded'],
  },
  {
    file: 'RC3_PRODUCTION_CANARY_CHECKLIST_MARCH_8_2026.md',
    includes: ['Historical, Superseded'],
  },
];

function readText(relativePath) {
  return fs.readFileSync(path.resolve(process.cwd(), relativePath), 'utf8');
}

function fileExists(relativePath) {
  const resolved = path.resolve(process.cwd(), relativePath);
  return fs.existsSync(resolved) && fs.statSync(resolved).size > 0;
}

function main() {
  const failures = [];
  const details = {
    requiredFiles: [],
    referenceChecks: [],
  };

  for (const relativePath of REQUIRED_FILES) {
    const exists = fileExists(relativePath);
    details.requiredFiles.push({ relativePath, exists });
    if (!exists) {
      failures.push(`missing_file:${relativePath}`);
    }
  }

  for (const check of REQUIRED_REFERENCES) {
    const resolved = path.resolve(process.cwd(), check.file);
    if (!fs.existsSync(resolved)) {
      failures.push(`missing_reference_file:${check.file}`);
      details.referenceChecks.push({ file: check.file, matched: false, missing: check.includes });
      continue;
    }
    const content = readText(check.file);
    const missing = check.includes.filter((needle) => !content.includes(needle));
    details.referenceChecks.push({
      file: check.file,
      matched: missing.length === 0,
      missing,
    });
    for (const needle of missing) {
      failures.push(`missing_reference:${check.file}:${needle}`);
    }
  }

  const output = finish('big-bang-release-artifacts', failures, details);
  if (!output.failed) {
    process.stdout.write('✅ Big-bang release artifacts verified.\n');
  }
}

main();