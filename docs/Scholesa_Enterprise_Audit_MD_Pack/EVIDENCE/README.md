# Evidence Folder

Generated evidence artifacts for enterprise/full-scope regression (core + non-core).

## Deployment / Runtime
- `cloudrun-services.json`
  Contains live Cloud Functions + Cloud Run runtime inventory (Node 24) and health probe result.

## Regression Master Outputs
- `run.json`
  Consolidated run manifest across RC2, full VIBE, live voice VIBE, and live telemetry coverage audit.
- `junit.xml`
  JUnit-style summary for CI/audit ingestion.
- `coverage-summary.json`
  Coverage artifact pointer/summary for this run.
- `e2e-artifacts.json`
  E2E/golden/integration artifact manifest.

## Security Scans
- `vulnerability-scan.json` (root)
- `vulnerability-scan-functions.json` (functions)
- `security-scans.json` (combined summary)

## Privacy / Isolation / AI Safety
- `tenant-isolation-test.json`
- `ai-guardrails-report.json`
- `telemetry-live-audit.txt`

## Notes
- Files are generated from executed commands and report outputs in this repository.
- Use these files directly in procurement/audit evidence packets.
