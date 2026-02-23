#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish, readJson } = require('./vibe_report_utils');

const requiredScreens = [
  'app/[locale]/(auth)/login/page.tsx',
  'app/[locale]/(auth)/register/page.tsx',
  'app/[locale]/(protected)/dashboard/page.tsx',
  'app/[locale]/(protected)/educator/page.tsx',
  'app/[locale]/(protected)/parent/page.tsx',
  'app/[locale]/(protected)/site/page.tsx',
  'app/[locale]/(protected)/partner/page.tsx',
  'app/[locale]/(protected)/hq/page.tsx',
  'app/[locale]/(protected)/learner/page.tsx',
  'app/[locale]/(protected)/educator/analytics/page.tsx',
  'app/[locale]/(protected)/learner/profile/page.tsx',
];

const locales = ['en', 'zh-CN', 'zh-TW', 'th'];
const criticalPrefixes = ['auth.', 'role.', 'analytics.', 'motivation.', 'aiCoach.'];

function flattenValues(obj, prefix = '', out = {}) {
  for (const [key, value] of Object.entries(obj || {})) {
    const next = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenValues(value, next, out);
      continue;
    }
    out[next] = typeof value === 'string' ? value : String(value);
  }
  return out;
}

const failures = [];
const details = {
  screens: {},
  localeCoverage: {},
  layoutChecks: {},
};

for (const screen of requiredScreens) {
  const exists = fs.existsSync(path.resolve(screen));
  details.screens[screen] = { exists };
  if (!exists) failures.push(`missing_screen:${screen}`);
}

const globalsCssPath = path.resolve('app/globals.css');
const globalsCss = fs.existsSync(globalsCssPath) ? fs.readFileSync(globalsCssPath, 'utf8') : '';
const localeLayoutPath = path.resolve('app/[locale]/layout.tsx');
const localeLayout = fs.existsSync(localeLayoutPath) ? fs.readFileSync(localeLayoutPath, 'utf8') : '';

details.layoutChecks.fontStackHasNoto = /Noto Sans/.test(globalsCss);
details.layoutChecks.localeDocumentSyncPresent = /LocaleDocumentSync/.test(localeLayout);
if (!details.layoutChecks.fontStackHasNoto) failures.push('missing_multilingual_font_stack');
if (!details.layoutChecks.localeDocumentSyncPresent) failures.push('missing_locale_document_sync');

const catalogs = {};
for (const locale of locales) {
  const filePath = path.resolve(`packages/i18n/locales/${locale}.json`);
  if (!fs.existsSync(filePath)) {
    failures.push(`missing_locale_file:${locale}`);
    continue;
  }
  catalogs[locale] = flattenValues(readJson(filePath));
}

if (catalogs.en) {
  for (const locale of locales) {
    const dict = catalogs[locale];
    if (!dict) continue;
    const missingCritical = [];
    for (const prefix of criticalPrefixes) {
      const enKeys = Object.keys(catalogs.en).filter((key) => key.startsWith(prefix));
      const missing = enKeys.filter((key) => !(key in dict));
      if (missing.length > 0) {
        missingCritical.push({ prefix, count: missing.length, sample: missing.slice(0, 5) });
      }
    }

    let expansionMax = 0;
    const expansionSamples = [];
    if (locale !== 'en') {
      for (const [key, enText] of Object.entries(catalogs.en)) {
        if (!criticalPrefixes.some((prefix) => key.startsWith(prefix))) continue;
        const localized = dict[key];
        if (!localized || !enText) continue;
        const ratio = localized.length / Math.max(1, enText.length);
        if (ratio > expansionMax) {
          expansionMax = ratio;
        }
        if (ratio > 2.8 || ratio < 0.1) {
          expansionSamples.push({ key, ratio: Number(ratio.toFixed(2)) });
        }
      }
    }

    if (missingCritical.length > 0) {
      failures.push(`missing_critical_keys:${locale}`);
    }
    if (expansionSamples.length > 0) {
      failures.push(`layout_expansion_outliers:${locale}:${expansionSamples.length}`);
    }

    details.localeCoverage[locale] = {
      keyCount: Object.keys(dict).length,
      missingCritical,
      expansionMaxRatio: Number(expansionMax.toFixed(2)),
      expansionOutliers: expansionSamples.slice(0, 20),
    };
  }
}

finish('vibe-ui-screens-i18n-report', failures, details);
