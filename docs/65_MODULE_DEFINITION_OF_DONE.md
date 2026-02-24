# 65_MODULE_DEFINITION_OF_DONE.md
Module Definition of Done (DoD) + Route Flip Gate

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Rule
**A module route cannot be enabled** until every item here is PASS.

---

## 1) Product completeness
- [ ] User story implemented end-to-end (no “coming soon” on enabled routes)
- [ ] Empty state implemented (friendly, actionable)
- [ ] Loading state implemented
- [ ] Error state implemented with retry
- [ ] Accessibility basics (tap targets, labels, focus order for web)

## 2) Data + domain correctness
- [ ] Firestore schema mapping exists and matches `02A_SCHEMA_V3.ts`
- [ ] API DTOs and mappers exist (no `dynamic` leaks beyond boundary)
- [ ] All timestamps are server-authoritative where needed
- [ ] No versioning regressions: snapshots/immutability enforced where required

## 3) Security and authorization (fail closed)
- [ ] Firestore rules allow only the minimum required access
- [ ] API verifies Firebase JWT on every endpoint
- [ ] API enforces role + site scope server-side
- [ ] Parent-safe boundary verified (no educator-only leaks)
- [ ] Entitlement gates applied for paid features

## 4) Auditability
- [ ] Privileged writes generate AuditLog entries
- [ ] Audit details include: actorId, action, entityType, entityId, siteId (if applicable)

## 5) Offline readiness (if module requires offline)
- [ ] Offline op types listed in `68_OFFLINE_OPS_CATALOG.md`
- [ ] Queue persists locally; optimistic UI works
- [ ] Sync endpoint handles idempotency keys
- [ ] Conflict resolution is deterministic and documented
- [ ] Offline QA script executed (airplane mode)

## 6) Performance and cost
- [ ] All list queries paginated
- [ ] Composite indexes created for query patterns
- [ ] No unbounded listeners in large collections
- [ ] Telemetry event emission is bounded and privacy-safe

## 7) Testing
- [ ] Unit tests for repositories/controllers
- [ ] Widget tests for critical UI paths
- [ ] Rules emulator tests cover the module’s collections
- [ ] API tests cover wrong-role and wrong-site denial
- [ ] Manual QA steps written/updated (if needed)

## 8) Observability
- [ ] Errors captured client-side (Crashlytics/Sentry)
- [ ] Server logs structured and include requestId
- [ ] Alerts exist if module impacts safety/revenue (incidents, billing, integrations)

## 9) Release bookkeeping
- [ ] `49_ROUTE_FLIP_TRACKER.md` updated
- [ ] `51_IMPLEMENTATION_AUDIT_GO_LIVE.md` updated with evidence links

---

## Route Flip Checklist (per module)
When DoD passes:
1) Enable route in `kKnownRoutes` (client) and/or server feature flags (if used)
2) Add provider wiring to the route factory
3) Run smoke test: open dashboard card and complete one core action
4) Capture evidence (screenshot/video) and link in audit

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `65_MODULE_DEFINITION_OF_DONE.md`
<!-- TELEMETRY_WIRING:END -->
