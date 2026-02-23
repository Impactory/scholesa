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
