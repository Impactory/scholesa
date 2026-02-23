#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const notices = {
  en: path.resolve('docs/compliance/notices/parent_notice_en.md'),
  'zh-CN': path.resolve('docs/compliance/notices/parent_notice_zh-CN.md'),
  'zh-TW': path.resolve('docs/compliance/notices/parent_notice_zh-TW.md'),
  th: path.resolve('docs/compliance/notices/parent_notice_th.md'),
};

function extractHeadings(source) {
  return source
    .split(/\r?\n/)
    .filter((line) => /^##\s+/.test(line))
    .map((line) => line.replace(/^##\s+/, '').trim());
}

function contentLengthBySection(source) {
  const sections = {};
  const lines = source.split(/\r?\n/);
  let current = null;
  for (const line of lines) {
    const heading = line.match(/^##\s+(.+)/);
    if (heading) {
      current = heading[1].trim();
      sections[current] = '';
      continue;
    }
    if (current) {
      sections[current] += `${line.trim()} `;
    }
  }
  return Object.fromEntries(
    Object.entries(sections).map(([k, v]) => [k, v.trim().length])
  );
}

const failures = [];
const details = {
  files: {},
  headingParity: {},
  sectionLengths: {},
};

for (const [locale, filePath] of Object.entries(notices)) {
  if (!fs.existsSync(filePath)) {
    failures.push(`missing_notice:${locale}`);
    continue;
  }
  const source = fs.readFileSync(filePath, 'utf8');
  const headings = extractHeadings(source);
  details.files[locale] = {
    path: path.relative(process.cwd(), filePath),
    headings,
  };
  details.sectionLengths[locale] = contentLengthBySection(source);
}

if (!failures.length) {
  const baselineHeadings = details.files.en.headings;
  for (const locale of Object.keys(notices)) {
    const current = details.files[locale].headings;
    const sameLength = current.length === baselineHeadings.length;
    const sameOrder = sameLength && current.every((heading, idx) => heading === baselineHeadings[idx]);
    details.headingParity[locale] = { sameLength, sameOrder };
    if (!sameLength || !sameOrder) {
      failures.push(`heading_parity_mismatch:${locale}`);
    }

    for (const [section, length] of Object.entries(details.sectionLengths[locale])) {
      if (length < 20) {
        failures.push(`section_too_short:${locale}:${section}`);
      }
    }
  }
}

finish('vibe-compliance-notice-i18n-report', failures, details);

