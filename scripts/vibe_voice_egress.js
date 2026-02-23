#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { finish } = require('./vibe_report_utils');

const TARGET_SOURCE = path.resolve('functions/src/voiceSystem.ts');

function findPatternHits(source, pattern, label) {
  const matches = source.match(pattern);
  return {
    label,
    count: matches ? matches.length : 0,
  };
}

function main() {
  const failures = [];
  const details = {
    servicesChecked: ['scholesa-stt', 'scholesa-tts'],
    outboundRequestsDetected: 0,
    sourceFile: TARGET_SOURCE,
    detection: [],
    notes: 'Static network-client scan of voice runtime; no external egress calls are permitted.',
  };

  if (!fs.existsSync(TARGET_SOURCE)) {
    failures.push('missing_source:functions/src/voiceSystem.ts');
    finish('voice-egress', failures, details);
    return;
  }

  const source = fs.readFileSync(TARGET_SOURCE, 'utf8');
  const checks = [
    findPatternHits(source, /\bfetch\s*\(/g, 'fetch_calls'),
    findPatternHits(source, /\baxios\b/g, 'axios_references'),
    findPatternHits(source, /\bhttps\.request\b/g, 'https_request_calls'),
    findPatternHits(source, /\bhttp\.request\b/g, 'http_request_calls'),
  ];
  details.detection = checks;
  details.outboundRequestsDetected = checks.reduce((sum, check) => sum + check.count, 0);

  if (details.outboundRequestsDetected > 0) {
    failures.push(`outbound_requests_detected:${details.outboundRequestsDetected}`);
  }

  const hasInternalModelTags = /STT_MODEL_VERSION/.test(source) && /TTS_MODEL_VERSION/.test(source);
  details.internalModelTagsPresent = hasInternalModelTags;
  if (!hasInternalModelTags) {
    failures.push('missing_internal_model_version_markers');
  }

  finish('voice-egress', failures, details);
}

main();

