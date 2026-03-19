# 72_RELEASE_CUTOVER_RUNBOOK.md
Release Cutover Runbook (Pre-Production Rehearsal → Production Big-Bang)

Generated: 2026-01-09

> Current release-control policy: use `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md` and `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md` as the authoritative production cutover artifacts.
> This runbook remains useful for operational sequencing, but it is no longer the canonical release gate by itself.

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Define the exact steps to cutover safely to production.

---

## 1) Preconditions
- `51_IMPLEMENTATION_AUDIT_GO_LIVE.md`: all P0 PASS with evidence
- Scholesa_Go_Live_Readiness_Checklist.docx: completed
- Pre-production rehearsal completed with evidence
- Backups and restore rehearsal completed

---

## 2) Day-before checklist
- Freeze schema changes
- Confirm billing webhooks configured in prod
- Confirm OAuth redirect URIs (prod)
- Confirm domains/SSL if applicable
- Confirm alerting channels active

---

## 3) Cutover steps
1) Deploy API (Cloud Run):
   - new revision
   - verify /healthz
2) Deploy primary web container:
   - build with ENV=prod
   - deploy to Cloud Run web
   - verify login + routed pages
3) Deploy Flutter web container:
   - build with ENV=prod
   - deploy to Cloud Run web
   - verify login + dashboards
4) Turn on feature flags/routes:
   - enable only modules that passed DoD (65)
5) Create first production Site + admin accounts
6) First-hour smoke test:
   - login per role
   - verify primary web routes
   - take attendance online
   - send a message
   - view parent summary
   - validate learner AI returns high-confidence help or safe escalation, never fabricated low-confidence help
7) Monitor:
   - error rates
   - auth failures
   - job failures
   - webhook failures

---

## 4) Rollback plan
- shift Cloud Run traffic to previous revision
- disable recent routes via flags
- communicate status

---

## 5) Day-1 monitoring
- review incident queue
- verify billing events and entitlements
- verify Classroom/GitHub jobs (if enabled)
- run a test export and verify access controls

---

## 6) Release note addendum (HQ Curriculum Manager)
- Date: 2026-03-02
- Scope: Curriculum lifecycle flow is fully wired and persisted from Drafts to In Review to Published.

### Shipped behavior
- Explicit action in Drafts: Submit for Review.
- Explicit action in In Review: Publish Curriculum.
- Mission status transitions persist in Firestore: draft -> review -> published.
- Transition metadata is stored:
   - reviewSubmittedBy, reviewSubmittedAt
   - published, publishedBy, publishedAt
- UI reflects the new status immediately and shifts operator focus to the destination tab.

### Validation evidence
- flutter test apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart (PASS)
- flutter test apps/empire_flutter/app/test/cta_reflection_test.dart (PASS)
- flutter test apps/empire_flutter/app/test/dashboard_cta_regression_test.dart (PASS)
- npm run rc3:preflight (PASS)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `72_RELEASE_CUTOVER_RUNBOOK.md`
<!-- TELEMETRY_WIRING:END -->
