# Architecture Overview (Firebase + Cloud Run)

## Edge
- Firebase Hosting (web UI)
- Rewrites to Cloud Run services (/api, /ai, etc.)

## Core Services (Cloud Run)
- scholesa-api: REST/GraphQL API + authz middleware + domain logic
- scholesa-ai: AI orchestration + tools + policies + safety
- scholesa-integrations: LMS integrations (Google Classroom, etc.)
- scholesa-jobs: scheduled/async jobs (optional)

## Identity
- Firebase Auth + custom claims (siteId, role, gradeBand)

## Data
- Firestore as primary operational DB
- Cloud Storage for artifacts (portfolio uploads)
- BigQuery (optional) for analytics/events

## Observability
- Cloud Logging + Error Reporting
- Cloud Monitoring dashboards + SLOs
- Trace correlation (traceId)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/01-architecture/ARCHITECTURE_OVERVIEW.md`
<!-- TELEMETRY_WIRING:END -->
