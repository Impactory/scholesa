# AI System Specification

## Components
- Policy engine (allow/deny)
- Prompt templates (versioned)
- Tool registry (scoped)
- Safety classifier/moderation layer
- Evaluations suite (regression)

## Required metadata on every response
- modelVersion
- policyVersion
- promptTemplateId
- safetyOutcome
- toolCallIds
- traceId
- siteId, learnerId (internal logs)
- missionAttemptId (learning context)

## Logging
Append-only or tamper-evident approach recommended for investigations.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/05-ai/AI_SYSTEM_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
