# Secure Context Assembly (scholesa-api)

## Rule
Context is minimal and permissioned. Never assemble broad context automatically.

## Allowed inputs (from client)
- screenId
- missionId/sessionId currently open
- missionAttemptId (current attempt only)
- selectedLearnerId (teacher only, if teacher has permission)

## Server validations
- siteId from auth token only
- role from auth token only
- verify selectedLearnerId belongs to teacher scope
- verify missionAttemptId belongs to requester and siteId

## Prohibited
- Passing entire student work history into AI
- Passing other students’ data into AI
- Including PII in logs

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/03-api/SECURE_CONTEXT_ASSEMBLY.md`
<!-- TELEMETRY_WIRING:END -->
