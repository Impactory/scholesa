#!/usr/bin/env node
'use strict';

const VIBE_BLOCKER_REPORTS = Object.freeze([
  'vendor-dependency-ban',
  'vendor-domain-ban',
  'vendor-secret-ban',
  'vendor-egress-proof',
  'tenant-isolation',
  'safety-fixtures',
  'voice-retention-ttl',
  'logging-no-raw-content',
  'telemetry-schema-valid',
  'inference-authz',
  'inference-ingress-private',
  'infra-drift',
  'i18n-coverage',
]);

module.exports = {
  VIBE_BLOCKER_REPORTS,
};
