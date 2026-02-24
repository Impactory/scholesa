# Logging Hygiene (No Raw Content)

## Allowed in logs
- traceId
- siteId (tenant)
- role, gradeBand, locale
- endpoint name, status code
- latencyMs
- safetyOutcome codes (no content)

## Prohibited in logs
- raw transcript text
- raw prompt content
- audio bytes
- names/emails/addresses

## Implementation
- Use structured logger with redaction middleware
- Add tests that scan logs for prohibited patterns during integration runs

## Evidence
`audit-pack/reports/logging-no-raw-content.json`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/02-data/02-logging-hygiene.md`
<!-- TELEMETRY_WIRING:END -->
