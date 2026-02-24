#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const files = {
  localeHeaders: path.resolve('src/lib/i18n/localeHeaders.ts'),
  localeConfig: path.resolve('src/lib/i18n/config.ts'),
  loginRoute: path.resolve('app/api/auth/session-login/route.ts'),
  logoutRoute: path.resolve('app/api/auth/session-logout/route.ts'),
  voiceService: path.resolve('src/lib/voice/voiceService.ts'),
};

const failures = [];
const details = {};

for (const [label, filePath] of Object.entries(files)) {
  if (!fs.existsSync(filePath)) {
    failures.push(`missing_file:${label}`);
    continue;
  }
  details[label] = { path: path.relative(process.cwd(), filePath) };
}

if (!failures.length) {
  const localeHeadersSource = fs.readFileSync(files.localeHeaders, 'utf8');
  const localeConfigSource = fs.readFileSync(files.localeConfig, 'utf8');
  const loginSource = fs.readFileSync(files.loginRoute, 'utf8');
  const logoutSource = fs.readFileSync(files.logoutRoute, 'utf8');
  const voiceServiceSource = fs.readFileSync(files.voiceService, 'utf8');

  const checks = {
    resolveHeaderPriority: /x-scholesa-locale/.test(localeHeadersSource) && /accept-language/.test(localeHeadersSource),
    buildLocaleHeaders: /Accept-Language/.test(localeHeadersSource) && /X-Scholesa-Locale/.test(localeHeadersSource),
    fallbackToEnglish: /return 'en'/.test(localeConfigSource),
    loginRouteUsesResolver: /resolveRequestLocale/.test(loginSource),
    loginRoutePersistsPreferredLocale: /preferredLocale/.test(loginSource),
    loginRouteSetsLocaleCookie: /scholesa_locale/.test(loginSource),
    logoutRouteSetsLocaleCookie: /scholesa_locale/.test(logoutSource),
    voiceServiceSendsLocaleHeader: /x-scholesa-locale/.test(voiceServiceSource),
    voiceServiceSendsRequestId: /x-request-id/.test(voiceServiceSource),
    voiceServiceCallsSttAndCopilot: /\/voice\/transcribe/.test(voiceServiceSource) && /\/copilot\/message/.test(voiceServiceSource),
  };

  for (const [check, passed] of Object.entries(checks)) {
    if (!passed) failures.push(`failed_check:${check}`);
  }
  details.checks = checks;

  const sampleLocaleAssertions = {
    supportsZhCn: /zh-cn/.test(localeConfigSource.toLowerCase()),
    supportsZhTw: /zh-tw/.test(localeConfigSource.toLowerCase()),
    supportsThai: /th-th/.test(localeConfigSource.toLowerCase()),
  };
  for (const [check, passed] of Object.entries(sampleLocaleAssertions)) {
    if (!passed) failures.push(`failed_assertion:${check}`);
  }
  details.sampleLocaleAssertions = sampleLocaleAssertions;
}

finish('vibe-api-locale-report', failures, details);
