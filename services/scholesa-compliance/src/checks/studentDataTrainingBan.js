const fs = require('fs');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  walkFiles,
  relativeRepoPath,
  lineMatches,
  readTextSafe,
} = require('../utils');

const BANNED_MARKERS = [
  { label: 'exportForTraining symbol', regex: /\bexportForTraining\b/i },
  { label: 'training dataset phrase', regex: /\btraining dataset\b/i },
  { label: 'for training pipeline phrase', regex: /\bfor (model )?training\b/i },
  { label: 'fine-tune phrase', regex: /\bfine[- ]?tune\b/i },
];

const TEXT_EXTENSIONS = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']);

function shouldInclude(fullPath, relPath) {
  if (relPath.startsWith('node_modules/')) return false;
  if (relPath.startsWith('.git/')) return false;
  if (relPath.startsWith('docs/')) return false;
  if (relPath.startsWith('audit-pack/')) return false;
  if (relPath.startsWith('functions/lib/')) return false;
  if (relPath.includes('/.dart_tool/')) return false;
  if (relPath.includes('/ios/Pods/')) return false;
  if (relPath.includes('/macos/Pods/')) return false;
  if (relPath === 'services/scholesa-compliance/src/checks/studentDataTrainingBan.js') return false;
  const ext = path.extname(fullPath).toLowerCase();
  return TEXT_EXTENSIONS.has(ext);
}

function runStudentDataTrainingBan() {
  const files = walkFiles(REPO_ROOT, {
    include: shouldInclude,
  });

  const findings = [];
  const hits = [];

  for (const filePath of files) {
    const rel = relativeRepoPath(filePath);
    const content = fs.readFileSync(filePath, 'utf8');

    for (const marker of BANNED_MARKERS) {
      const matches = lineMatches(content, marker.regex);
      for (const match of matches) {
        hits.push({
          file: rel,
          line: match.line,
          pattern: marker.label,
          snippet: match.text,
        });
        findings.push(`${marker.label} in ${rel}:${match.line}`);
      }
    }
  }

  const interactionLoggerPath = path.join(REPO_ROOT, 'src/lib/ai/interactionLogger.ts');
  const interactionLogger = readTextSafe(interactionLoggerPath);
  if (!interactionLogger || !interactionLogger.includes('analytics_only_no_training')) {
    findings.push('interaction logger missing analytics_only_no_training policy marker');
  }

  const passed = findings.length === 0;
  const report = {
    report: 'student-data-training-ban',
    generatedAt: nowIso(),
    passed,
    findings,
    scannedFiles: files.length,
    bannedMarkers: BANNED_MARKERS.map((marker) => marker.label),
    hits,
    checks: {
      interactionLoggerPath,
      hasAnalyticsOnlyPolicyMarker: Boolean(
        interactionLogger && interactionLogger.includes('analytics_only_no_training')
      ),
    },
  };

  const outputPath = reportPath('student-data-training-ban');
  writeJson(outputPath, report);

  return {
    checkId: 'student_data_training_ban',
    passed,
    findings,
    evidencePath: outputPath,
    details: {
      scannedFiles: files.length,
      hitCount: hits.length,
      hasAnalyticsOnlyPolicyMarker: report.checks.hasAnalyticsOnlyPolicyMarker,
    },
  };
}

module.exports = {
  runStudentDataTrainingBan,
};
