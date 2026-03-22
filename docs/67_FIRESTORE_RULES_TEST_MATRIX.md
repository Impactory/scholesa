# 67_FIRESTORE_RULES_TEST_MATRIX.md
Firestore Collections → Access Rules → Emulator Test Matrix

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
This matrix prevents spec drift and ensures every collection has:
- explicit least-privilege rules
- an emulator test proving the rule
- clarity on who can read/write and under what conditions

## Global rule
- Default deny
- Reads/writes scoped by site membership where applicable
- Parents can only access parent-safe projections and their linked learners (GuardianLink)
- Admin-only provisioning enforced in rules and server
- Integration collections locked down; never public

---

## Matrix (canonical)
If your actual collection names differ:
- add COLLECTION_MAP.md
- update this matrix + rules + tests

| Collection | Read allowed | Write allowed | Required emulator tests |
|---|---|---|---|
| users | self; HQ; site admin (same site) | server/admin; HQ role changes | self_read; cross_user_deny; hq_read; site_scoped |
| sites | members; HQ | HQ/server; site admin limited | member_read; cross_site_deny; hq_write |
| guardianLinks | parent (own); site admin; HQ | site admin only | parent_read_own; parent_write_deny; admin_write |
| learnerProfiles | learner limited; parent linked limited; educator limited; site admin; HQ | site admin only | parent_safe; educator_scoped; admin_only_write |
| parentProfiles | parent self; site admin; HQ | site admin only | parent_self_read; parent_write_deny |
| sessions | site members; HQ | site admin | member_read_scoped; non_member_deny |
| sessionOccurrences | site members; HQ | site admin/server | occurrence_read_scoped; cross_site_deny |
| enrollments | educator/site; parent safe; HQ | site admin | enrollment_scoped; parent_safe_read |
| attendanceRecords | educator/site; HQ | educator/site; server sync | attendance_write_scoped; parent_deny; cross_site_deny |
| missions | allowed by scope; HQ | HQ/partner/site by entitlement | publish_gate; non_entitled_deny |
| missionPlans | educator/site; HQ | educator/site | plan_write_scoped; cross_site_deny |
| missionAttempts | learner own; educator scoped; parent safe projection; HQ | learner draft/submit; educator review | attempt_own; parent_projection_only; educator_review |
| missionSnapshots | scoped readers | server only | snapshot_immutable; client_write_deny |
| portfolios | learner own; parent safe; educator scoped; HQ | per consent policy | consent_gate_read; consent_gate_write |
| portfolioItems | learner; parent safe; educator scoped; HQ | educator/learner per rules | parent_safe_read; educator_write |
| credentials | learner own; educator scoped; HQ | educator/admin | credential_issue; parent_write_deny; hq_read |
| accountability* | scope members; HQ | allowed roles | wrong_role_deny; cross_site_deny |
| auditLogs | HQ/site admin (scoped) | server only | audit_client_write_deny; audit_scoped_read |
| billing* | owner + HQ | server/webhooks/HQ | client_write_deny; owner_read |
| cmsPages | public published; HQ | HQ | cms_public_published_only; hq_write_only |
| leads | HQ read only | public create | lead_create_public; lead_read_public_deny |
| marketplace* | per listing/order scoping | server/HQ lifecycle | lifecycle_enforced; approval_hq_only |
| partnerContracts* | partner + HQ | partner submit; HQ approve | contract_flow_enforced |
| messages/threads | participants only | participants | participant_only |
| notifications | recipient only | server only | client_write_deny; recipient_read |
| telemetryEvents | admin analytic readers | server only | telemetry_client_write_deny |
| integrations_* | HQ/site admin only | server only | integrations_client_deny |

---

## Required rule test suite structure
Create:
- `infra/firebase/rules_test/` grouped by collection.
Core tests must include:
- cross_site_deny
- wrong_role_deny
- parent_boundary_deny
- admin_only_write
- client_cannot_write_server_collections

---

## Go-live gate
No go-live unless:
- every production-used collection has at least one emulator test
- all tests pass in CI

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `67_FIRESTORE_RULES_TEST_MATRIX.md`
<!-- TELEMETRY_WIRING:END -->
