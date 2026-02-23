# COPPA Evidence Pack (Templates + JSON Schemas)
Generated: 2026-02-23T16:48:32Z

Scholesa should continuously generate audit artifacts that prove COPPA-safe defaults and controls.

This folder ships with:
- JSON schema templates (what each report should contain)
- Example report files with `pass=false` placeholders
- Guidance on how CI blocks releases when a blocker report fails

## Report location
`audit-pack/reports/`

## Blocker reports (must pass)
- vendor-dependency-ban.json
- vendor-domain-ban.json
- vendor-secret-ban.json
- vendor-egress-proof.json
- tenant-isolation.json
- voice-retention-ttl.json
- logging-no-raw-content.json
- inference-authz.json
- inference-ingress-private.json
- i18n-coverage.json
