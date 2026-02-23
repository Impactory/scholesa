#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { finish, flattenKeys, readJson, walkFiles } = require('./vibe_report_utils');

const LOCALES = ['en', 'zh-CN', 'zh-TW', 'th'];
const LOCALE_FILES = Object.fromEntries(
  LOCALES.map((locale) => [locale, path.resolve(`packages/i18n/locales/${locale}.json`)])
);

const CODE_ROOTS = [path.resolve('app'), path.resolve('src')];
const CODE_EXT = /\.(ts|tsx|js|jsx)$/;

function collectCodeFiles() {
  const files = [];
  for (const root of CODE_ROOTS) {
    walkFiles(
      root,
      (filePath) => CODE_EXT.test(filePath) &&
        !/\.test\./.test(filePath) &&
        !/\/dataconnect-generated\//.test(filePath),
      files
    );
  }
  return files;
}

function extractUsedKeys(source) {
  const keys = new Set();
  const patterns = [
    /\bt\(\s*['"`]([^'"`]+)['"`]/g,
    /\btranslate\(\s*[^,]+,\s*['"`]([^'"`]+)['"`]/g,
  ];
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(source)) !== null) {
      if (!match[1]) continue;
      if (match[1].includes('${')) continue;
      keys.add(match[1]);
    }
  }
  return keys;
}

const failures = [];
const details = {
  localeFiles: {},
  missingByLocale: {},
  usedKeyStats: {},
};

for (const [locale, filePath] of Object.entries(LOCALE_FILES)) {
  if (!fs.existsSync(filePath)) {
    failures.push(`missing_locale_file:${locale}`);
    continue;
  }
  const json = readJson(filePath);
  details.localeFiles[locale] = {
    filePath: path.relative(process.cwd(), filePath),
    keyCount: flattenKeys(json).length,
  };
}

if (!failures.length) {
  const catalogs = Object.fromEntries(
    LOCALES.map((locale) => [locale, readJson(LOCALE_FILES[locale])])
  );

  const keysByLocale = Object.fromEntries(
    LOCALES.map((locale) => [locale, new Set(flattenKeys(catalogs[locale]))])
  );

  const enKeys = keysByLocale.en;
  for (const locale of LOCALES.filter((l) => l !== 'en')) {
    const missing = [...enKeys].filter((key) => !keysByLocale[locale].has(key));
    if (missing.length > 0) {
      failures.push(`locale_key_parity_missing:${locale}:${missing.length}`);
    }
    details.missingByLocale[locale] = missing.slice(0, 100);
  }

  const codeFiles = collectCodeFiles();
  const usedKeys = new Set();
  for (const filePath of codeFiles) {
    const source = fs.readFileSync(filePath, 'utf8');
    for (const key of extractUsedKeys(source)) {
      usedKeys.add(key);
    }
  }

  const missingInEn = [...usedKeys].filter((key) => !enKeys.has(key));
  if (missingInEn.length > 0) {
    failures.push(`used_keys_missing_in_en:${missingInEn.length}`);
  }

  const missingByLocaleFromUsage = {};
  for (const locale of LOCALES.filter((l) => l !== 'en')) {
    const missing = [...usedKeys].filter((key) => !keysByLocale[locale].has(key));
    if (missing.length > 0) {
      failures.push(`used_keys_missing_in_${locale}:${missing.length}`);
    }
    missingByLocaleFromUsage[locale] = missing.slice(0, 100);
  }

  details.usedKeyStats = {
    scannedFiles: codeFiles.length,
    totalUsedKeys: usedKeys.size,
    missingInEn: missingInEn.slice(0, 100),
    missingInLocales: missingByLocaleFromUsage,
  };
}

finish('vibe-i18n-keys-report', failures, details);
