# Data Retention Schedule (Default + Override)

Date: 2026-02-23

## Default Retention Windows
- Active learner records: retained while enrolled and needed for educational delivery.
- Inactive learner accounts: eligible for deletion after 24 months inactivity.
- AI interaction logs: retained 12 months by default.
- Backup retention: 30-90 day rolling retention per infrastructure policy.
- Deletion/trace evidence: retained for audit/compliance.

## Tenant Override Model
- Site-specific retention override collection: `coppaRetentionOverrides/{siteId}`.
- Managed by hq callable: `upsertCoppaRetentionOverride`.
- Override fields:
  - `inactiveMonths`
  - `aiLogMonths`

## Execution Surfaces
- Scheduled daily sweep: `scheduledCoppaRetentionSweep`.
- On-demand/manual sweep: `runCoppaRetentionSweep` (`dryRun` supported).
- Run outputs logged in `coppaRetentionRuns`.

## Deletion Verification
- Firestore record deletion summaries are captured in request/report records.
- Storage prefix cleanup is attempted and error-counted in report payloads.
- Trace-linked evidence is stored in `coppaTraceLogs`.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_COPPA_Operational_Pack/07_DATA_RETENTION_SCHEDULE.md`
<!-- TELEMETRY_WIRING:END -->
