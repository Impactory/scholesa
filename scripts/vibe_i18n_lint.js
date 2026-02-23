#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish, walkFiles } = require('./vibe_report_utils');

const scanTargets = [
  'app/[locale]',
  'src/components/analytics/AnalyticsDashboard.tsx',
  'src/components/analytics/AIInsightsPanel.tsx',
  'src/components/analytics/StudentAnalyticsDashboard.tsx',
  'src/components/motivation/StudentMotivationProfile.tsx',
  'src/components/goals/GoalSettingForm.tsx',
  'src/components/sdt/AICoachPopup.tsx',
  'src/components/SignOutButton.tsx',
  'src/features/auth/components/LoginForm.tsx',
  'src/features/navigation/components/Navigation.tsx',
];

const ALLOW_TEXT = new Set(['Scholesa', '🏆', '•']);
const CODE_EXT = /\.(ts|tsx|js|jsx)$/;

function isIgnoredFile(filePath) {
  return /-impactory\./.test(filePath) ||
    /\/__tests__\//.test(filePath) ||
    /\.test\./.test(filePath) ||
    /\/dataconnect-generated\//.test(filePath);
}

function collectFiles() {
  const files = [];
  for (const target of scanTargets) {
    const full = path.resolve(target);
    if (!fs.existsSync(full)) continue;
    const stat = fs.statSync(full);
    if (stat.isFile()) {
      if (CODE_EXT.test(full) && !isIgnoredFile(full)) files.push(full);
      continue;
    }
    walkFiles(full, (filePath) => CODE_EXT.test(filePath) && !isIgnoredFile(filePath), files);
  }
  return files;
}

function stripComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
}

function looksTranslatable(text) {
  const value = text.trim();
  if (!value) return false;
  if (ALLOW_TEXT.has(value)) return false;
  if (/^[0-9%.,:+\-_/()\[\]{}!?#$^&*\\|<>=~`'"]+$/.test(value)) return false;
  return /[A-Za-z\u4e00-\u9fff\u0E00-\u0E7F]/.test(value);
}

function findHardcoded(source, relativePath) {
  const findings = [];
  const textNodeRegex = /<[^>\n]+>\s*([^<{\\n]*[A-Za-z\u4e00-\u9fff\u0E00-\u0E7F][^<{\\n]*)\s*<\/[^>\n]+>/g;
  let match;
  while ((match = textNodeRegex.exec(source)) !== null) {
    const text = match[1].trim();
    if (!looksTranslatable(text)) continue;
    findings.push(`${relativePath}:jsx_text:${text}`);
  }

  const attrRegex = /\b(placeholder|aria-label|title|alt)\s*=\s*["']([^"']+)["']/g;
  while ((match = attrRegex.exec(source)) !== null) {
    const text = match[2].trim();
    if (!looksTranslatable(text)) continue;
    findings.push(`${relativePath}:attr_${match[1]}:${text}`);
  }

  const alertRegex = /\balert\(\s*['"`]([^'"`]+)['"`]\s*\)/g;
  while ((match = alertRegex.exec(source)) !== null) {
    const text = match[1].trim();
    if (!looksTranslatable(text)) continue;
    findings.push(`${relativePath}:alert:${text}`);
  }

  return findings;
}

const files = collectFiles();
const findings = [];

for (const filePath of files) {
  const source = stripComments(fs.readFileSync(filePath, 'utf8'));
  findings.push(...findHardcoded(source, path.relative(process.cwd(), filePath)));
}

const failures = [];
if (findings.length > 0) {
  failures.push(`hardcoded_user_facing_strings:${findings.length}`);
}

finish('vibe-i18n-lint-report', failures, {
  scannedFiles: files.length,
  findings: findings.slice(0, 250),
});
