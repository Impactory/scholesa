#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const files = {
  aiService: path.resolve('src/lib/ai/aiService.ts'),
  modelAdapter: path.resolve('src/lib/ai/modelAdapter.ts'),
  guardrails: path.resolve('src/lib/ai/multilingualGuardrails.ts'),
  aiCoachPopup: path.resolve('src/components/sdt/AICoachPopup.tsx'),
};

function languageLooksCompatible(text, locale) {
  if (!text) return false;
  if (locale === 'en') return /[A-Za-z]/.test(text);
  if (locale === 'zh-CN') return /[\u4e00-\u9fff]/.test(text) && /我们|学习|请|你/.test(text);
  if (locale === 'zh-TW') return /[\u4e00-\u9fff]/.test(text) && /我們|學習|請|你/.test(text);
  if (locale === 'th') return /[\u0E00-\u0E7F]/.test(text);
  return false;
}

const failures = [];
const details = {
  staticChecks: {},
  sampleLanguageChecks: {},
};

for (const [label, filePath] of Object.entries(files)) {
  if (!fs.existsSync(filePath)) {
    failures.push(`missing_file:${label}`);
  }
}

if (!failures.length) {
  const aiService = fs.readFileSync(files.aiService, 'utf8');
  const modelAdapter = fs.readFileSync(files.modelAdapter, 'utf8');
  const guardrails = fs.readFileSync(files.guardrails, 'utf8');
  const popup = fs.readFileSync(files.aiCoachPopup, 'utf8');

  details.staticChecks = {
    requestHasTargetLocale: /targetLocale\??:/.test(aiService),
    requestHasRole: /role\??:/.test(aiService),
    modelRequestCarriesTargetLocale: /targetLocale:\s*req\.targetLocale|targetLocale,/.test(aiService),
    modelPromptHasLocaleInstruction: /Respond strictly in locale/.test(modelAdapter),
    guardrailHasLanguageCompatibility: /languageLooksCompatible/.test(guardrails),
    popupPassesLocaleToAI: /targetLocale:\s*locale/.test(popup),
  };

  for (const [check, passed] of Object.entries(details.staticChecks)) {
    if (!passed) failures.push(`failed_check:${check}`);
  }

  const samples = {
    en: 'Please try solving the first step and explain your reasoning.',
    'zh-CN': '请你先尝试第一步，然后告诉我们你的想法。',
    'zh-TW': '請你先嘗試第一步，然後告訴我們你的想法。',
    th: 'ช่วยลองทำขั้นตอนแรกก่อน แล้วอธิบายแนวคิดของคุณ',
  };

  const sampleChecks = {};
  for (const [locale, text] of Object.entries(samples)) {
    const ok = languageLooksCompatible(text, locale);
    sampleChecks[locale] = ok;
    if (!ok) failures.push(`sample_language_check_failed:${locale}`);
  }

  const mismatchChecks = {
    enWithThai: languageLooksCompatible(samples.th, 'en'),
    zhCnWithEn: languageLooksCompatible(samples.en, 'zh-CN'),
  };
  if (mismatchChecks.enWithThai) failures.push('mismatch_should_fail:enWithThai');
  if (mismatchChecks.zhCnWithEn) failures.push('mismatch_should_fail:zhCnWithEn');

  details.sampleLanguageChecks = { sampleChecks, mismatchChecks };
}

finish('vibe-ai-language-report', failures, details);

