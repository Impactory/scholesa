# 64_MASTER_IMPLEMENTATION_PLAN.md
Master Implementation Plan (No API minimums — ship the full platform)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Goal
Provide a **single executable plan** that an AI engineer can follow to implement **the entire Scholesa Empire platform** end-to-end:
UI + API + Firestore + rules + indexes + offline + integrations + billing + marketplace + contracting + messaging + analytics + exports + audits.

## Definitions
- **Module:** a shippable unit with UI routes + providers + repositories + API endpoints + rules/indexes + tests + audit logs + (offline ops if needed).
- **Route flip:** enabling a module route in the app only after Module DoD passes (see `65_MODULE_DEFINITION_OF_DONE.md`).
- **Canonical schema:** `02A_SCHEMA_V3.ts` (must match storage and DTOs).
- **Canonical dashboards/cards:** `47_ROLE_DASHBOARD_CARD_REGISTRY.md`.

## Global Build Rules (strict)
1. **No placeholders in production paths.** If UI exists on an enabled route, it must have real data loading, empty state, and error state.
2. **Server authoritative:** role, site scope, entitlements, identity mappings are resolved server-side.
3. **Security fails closed:** missing entitlement/permission = deny.
4. **No versioning issues:** curriculum uses snapshots; attempts never “break” after edits.
5. **Offline-first where specified:** attendance + check-in/out must work in airplane mode.
6. **Every privileged action writes an AuditLog** (schema: `AuditLog`).
7. **Every new collection requires:** schema mapping, rules, indexes (if queried), rules tests, repository updates.

---

# Phase 0 — Repo and environment foundation (P0)
**Deliverables**
- Repo structure per `52_RUNNABLE_REPO_BOOTSTRAP.md`
- Environment config per `53_ENVIRONMENT_CONFIG_SECRETS.md`
- Firebase infra files per `54_FIREBASE_SETUP_RULES_INDEXES.md`
- CI/CD base per `58_CI_CD_PIPELINE_GITHUB_ACTIONS.md`
- Observability basics per `61_OBSERVABILITY_ALERTING.md`

**Tasks**
1. Confirm repo layout; add `README.md` with local run + deploy commands.
2. Implement `app/lib/app_config.dart` and ENV switching.
3. Implement Firebase init and project options selection by ENV.
4. Implement Cloud Run API skeleton with full endpoint catalog (see `66_API_ENDPOINTS_FULL_CATALOG.md`).
5. Add Firestore rules (deny by default) + indexes + storage rules.
6. Add emulator + rules tests harness.
7. Add crash reporting integration (staging first, then prod).

**Acceptance**
- Local: `flutter run` works
- Staging: deploy succeeds
- Rules tests pass

Route flips: none

---

# Phase 1 — Identity, provisioning, and multi-role dashboards (P0)
**Deliverables**
- Auth works; `/v1/me` returns server-authoritative session profile.
- Role dashboards render correct card sets (per `47`).
- Admin-only provisioning flows exist (site admin + HQ).

**Tasks**
1. Implement API: Users/Sites/Provisioning endpoints (see `66`).
2. Implement Firestore collections: User, Site, GuardianLink, LearnerProfile, ParentProfile.
3. Implement admin-only onboarding requirements:
   - Parent↔Learner link (GuardianLink) created ONLY by school admin.
   - LearnerProfile includes admin-only “Kyle and parrot” questionnaire fields stored under `LearnerProfile.metadata.adminQuestions`.
4. Implement role dashboard routing framework and `kKnownRoutes`.
5. Implement baseline screens:
   - Login (and Register only if used)
   - RoleDashboard (cards)
   - HQ User Admin
   - Site Provisioning (create learners/parents, set roles, link guardians)

**Acceptance**
- Parent cannot self-link learners.
- Site admin can provision and link.
- AuditLog records all provisioning actions.
- Dashboards render without crash.

Route flips: enable HQ User Admin + Site Provisioning only after DoD.

---

# Phase 2 — Core school operations (P0)
## 2A Attendance + sessions + scheduling
**Tasks**
- Implement sessions, occurrences, enrollments, roster.
- Attendance create/update with educator/site admin permissions.
- Offline queue for attendance (see `68_OFFLINE_OPS_CATALOG.md`).

**Acceptance**
- Educator can take attendance offline; sync reconciles; audit exists.

## 2B Physical check-in/out + pickup authorization + incidents + consent
**Tasks**
- Implement pickup authorization list and verification.
- Implement check-in/out with offline capture.
- Implement incident workflow: educator submit → admin close → HQ visibility for major/critical.
- Implement consent gates across portfolio/media.

**Acceptance**
- Check-in/out works offline with deterministic sync.
- Parent-safe boundary holds: parents cannot see teacher-only insights.
- AuditLog for consent changes.

Route flips: enable educator attendance, site check-in/out, incidents, consent management after DoD.

---

# Phase 3 — Learning engine (P0/P1)
## 3A Missions, plans, attempts, rubrics, portfolios, credentials
**Tasks**
- Mission library with publisher types (HQ/Partner/Site).
- MissionPlan per occurrence.
- MissionAttempt draft/submitted/reviewed, artifacts, rubric scoring.
- Portfolio items built from attempts (consent-gated).
- Credentials issuance.

**No versioning issues requirement**
- Create MissionSnapshot when a mission is assigned/published.
- Attempts reference `snapshotId`; editing the mission template never changes past attempts.

**Acceptance**
- Educator review queue works.
- Learner sees attempts and reflections.
- Parent sees safe summary view.
- Snapshots immutable and tested.

---

# Phase 4 — Accountability cycle (P1)
**Tasks**
- Implement AccountabilityCycle, KPIs, Commitments, Reviews.
- Role-specific views:
  - learner habit commitments and progress
  - educator class commitments
  - parent commitments
  - site/HQ KPI rollups

**Acceptance**
- cycles can be created/closed
- KPI rollups work by site
- audit entries exist for cycle status changes

---

# Phase 5 — Messaging + notifications (P0)
**Tasks**
- Threads, messages, notification objects
- Role and site scoping rules
- Notification preferences (ParentProfile)

**Acceptance**
- in-app notifications reliable
- unread badge + read state works

---

# Phase 6 — Billing + entitlements (P0/P1)
**Tasks**
- Stripe integration (webhooks verified, idempotent)
- BillingPlan, Subscription, Invoice
- EntitlementGrant drives feature access (fail closed)
- Site billing admin and parent billing screens (as applicable)

**Acceptance**
- plan changes reflect entitlements
- invoices visible to correct payer
- webhook failure alerting exists

---

# Phase 7 — Marketing CMS + leads (P1)
**Tasks**
- CMS pages and lead capture
- Publishing workflow: draft → review → published
- Basic SEO metadata fields

**Acceptance**
- pages render correctly
- lead capture stored and exportable

---

# Phase 8 — Marketplace + Partner contracting + payouts (P1)
**Tasks**
- PartnerOrg, listing lifecycle, orders, fulfillment
- Contract lifecycle, deliverables, payout approvals

**Acceptance**
- listing approval by HQ works
- order creates fulfillment and grants entitlements/content access
- payouts tracked with audit

---

# Phase 9 — Integrations (Google Classroom + GitHub) (P1/P2)
**Tasks**
- Classroom add-on connect, OAuth, sync jobs, identity matching per docs 28–32, 39
- GitHub integration (A0/A1/A2), webhooks verified, identity matching per 40

**Acceptance**
- roster sync idempotent
- failure states surfaced to admin
- identity resolution center resolves unmatched users safely

---

# Phase 10 — Analytics + telemetry (P1)
**Tasks**
- TelemetryEvent writes for key flows
- dashboards for HQ and site
- privacy controls (no PII)

---

# Phase 11 — Exports, retention, backups (P0)
**Tasks**
- export jobs server-side, signed URLs
- retention policy and delete workflows
- restore rehearsal in staging

---

# Phase 12 — Go-live cutover (P0)
Follow:
- `51_IMPLEMENTATION_AUDIT_GO_LIVE.md`
- `Scholesa_Go_Live_Readiness_Checklist.docx`
- `72_RELEASE_CUTOVER_RUNBOOK.md`

---

## Route flip order (recommended)
1) Auth + /me + dashboards
2) HQ user admin + site provisioning
3) Educator attendance + offline queue
4) Check-in/out + pickup auth + incidents + consent
5) Missions + attempts + review queue + snapshots
6) Messaging + notifications
7) Billing + entitlements
8) Classroom + GitHub (optional before public launch)
9) Marketplace + contracting
10) Analytics + exports + retention

Each flip must satisfy Module DoD (`65`).

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `64_MASTER_IMPLEMENTATION_PLAN.md`
<!-- TELEMETRY_WIRING:END -->
