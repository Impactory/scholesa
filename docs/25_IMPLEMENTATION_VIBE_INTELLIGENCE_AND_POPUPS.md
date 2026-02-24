# 25_IMPLEMENTATION_VIBE_INTELLIGENCE_AND_POPUPS.md

This doc tells Codex exactly how to implement popups + intelligence safely.

## Sequence (mandatory)
A) Implement configs/supportStrategies (HQ editable)
B) Implement configs/popupRules + popup orchestrator
C) Implement popup catalog (learner/educator/parent/admin)
D) Implement learnerSignals computation (API, rules-based)
E) Implement sessionInsights + learnerInsights (API)
F) Implement intervention logging (offline capable)
G) Enforce parent privacy boundary in rules + UI
H) Add telemetry events and dashboards hooks

## Hard blockers
- schema (02A) includes the collections and types
- Firestore rules block parents from internal intelligence
- offline queue supports interventions + evidence
- build is reproducible (docs/08)

## Acceptance criteria
- popups create real state changes (not decorative)
- offline class scenario passes (attendance + attempt + intervention)
- parent cannot access intelligence collections (rules enforced)
- builds pass + QA pass + audit pass + traceability updated

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `25_IMPLEMENTATION_VIBE_INTELLIGENCE_AND_POPUPS.md`
<!-- TELEMETRY_WIRING:END -->
