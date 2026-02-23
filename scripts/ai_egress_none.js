#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');
const { walkProjectFiles, lineHits } = require('./ai_policy_common');

const BANNED_HOST_PATTERNS = [
  /generativelanguage\.googleapis\.com/i,
  /ai\.google\.dev/i,
  /vertexai\.googleapis\.com/i,
  /aiplatform\.googleapis\.com/i,
];

const POLICY_FILE_ALLOWLIST = new Set([
  'scripts/ai_dependency_ban.js',
  'scripts/ai_import_ban.js',
  'scripts/ai_domain_ban.js',
  'scripts/ai_egress_none.js',
  'scripts/ai_policy_common.js',
  'src/lib/ai/egressGuard.ts',
  'functions/src/security/egressGuard.ts',
]);

function readFile(relativePath) {
  const filePath = path.resolve(process.cwd(), relativePath);
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, 'utf8');
}

function main() {
  const failures = [];
  const details = {
    checks: {},
    bannedDomainHits: [],
    runtimeFilesScanned: 0,
  };

  const srcGuard = readFile('src/lib/ai/egressGuard.ts');
  details.checks.srcEgressGuardPresent = Boolean(srcGuard);
  if (!srcGuard) {
    failures.push('missing_src_egress_guard');
  } else {
    details.checks.srcGuardEmitsSecurityEvent = srcGuard.includes('SECURITY_EGRESS_BLOCKED');
    if (!details.checks.srcGuardEmitsSecurityEvent) {
      failures.push('src_egress_guard_missing_security_event');
    }
  }

  const functionsGuard = readFile('functions/src/security/egressGuard.ts');
  details.checks.functionsEgressGuardPresent = Boolean(functionsGuard);
  if (!functionsGuard) {
    failures.push('missing_functions_egress_guard');
  } else {
    details.checks.functionsGuardEmitsSecurityEvent = functionsGuard.includes('SECURITY_EGRESS_BLOCKED');
    if (!details.checks.functionsGuardEmitsSecurityEvent) {
      failures.push('functions_egress_guard_missing_security_event');
    }
  }

  const voiceService = readFile('src/lib/voice/voiceService.ts');
  details.checks.voiceServiceUsesAiSafeFetch = Boolean(voiceService && /aiSafeFetch\(/.test(voiceService));
  if (!details.checks.voiceServiceUsesAiSafeFetch) {
    failures.push('voice_service_not_using_ai_safe_fetch');
  }

  const functionsIndex = readFile('functions/src/index.ts');
  details.checks.functionsIndexUsesGuardedFetch = Boolean(functionsIndex && /guardedFetch\(/.test(functionsIndex));
  if (!details.checks.functionsIndexUsesGuardedFetch) {
    failures.push('functions_index_not_using_guarded_fetch');
  }

  const runtimeFiles = walkProjectFiles(process.cwd(), {
    includePredicate: (_fullPath, relativePath) => {
      if (POLICY_FILE_ALLOWLIST.has(relativePath)) return false;
      if (relativePath.startsWith('docs/')) return false;
      if (relativePath.startsWith('node_modules/')) return false;
      const ext = path.extname(relativePath);
      return ['.ts', '.tsx', '.js', '.jsx', '.json', '.yaml', '.yml', '.sh', '.env'].includes(ext) || path.basename(relativePath).startsWith('.env');
    },
  });

  details.runtimeFilesScanned = runtimeFiles.length;

  for (const filePath of runtimeFiles) {
    const relativePath = path.relative(process.cwd(), filePath);
    const content = fs.readFileSync(filePath, 'utf8');
    for (const pattern of BANNED_HOST_PATTERNS) {
      const hits = lineHits(content, pattern);
      for (const hit of hits) {
        failures.push(`banned_egress_domain_reference:${relativePath}:${hit.line}`);
        details.bannedDomainHits.push({
          file: relativePath,
          line: hit.line,
          snippet: hit.text,
        });
      }
    }
  }

  const envExample = readFile('.env.example') || '';
  const envProdExample = readFile('.env.production.example') || '';
  const mergedEnv = `${envExample}\n${envProdExample}`;

  details.checks.envDeclaresInternalProviders = [
    /SCHOLESA_AI_PROVIDER=INTERNAL_AI/.test(mergedEnv),
    /SCHOLESA_TTS_PROVIDER=INTERNAL_TTS/.test(mergedEnv),
    /SCHOLESA_STT_PROVIDER=INTERNAL_STT/.test(mergedEnv),
  ].every(Boolean);
  if (!details.checks.envDeclaresInternalProviders) {
    failures.push('missing_internal_provider_defaults_in_env_examples');
  }

  details.checks.envHasNoGeminiKeys = !/GEMINI_API_KEY/i.test(mergedEnv);
  if (!details.checks.envHasNoGeminiKeys) {
    failures.push('gemini_key_reference_detected_in_env_examples');
  }

  finish('ai-egress-none', failures, details);
}

main();
