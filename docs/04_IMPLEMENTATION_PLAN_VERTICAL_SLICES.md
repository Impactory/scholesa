# 04_IMPLEMENTATION_PLAN_VERTICAL_SLICES.md

You will only succeed if you ship in vertical slices.

## Slice definition
A slice is “done” only when it includes:
- UI + API (if needed) + rules + offline + telemetry + tests
- QA pass (`docs/09`)
- Audit pass (`docs/19`)
- Traceability updates (`docs/10`)

---

## Slice 0 — Bootstrap (builds + deploy skeleton)
- Flutter boots and authenticates
- API boots with /health
- baseline Firestore rules deny-by-default
- pinned versions established

---

## Slice 1 — Design + Landing + Role routing
- public landing page with sign-in
- role routing based on `users/{uid}.role`
- design system applied consistently (no redesign)

---

## Slice 2 — Site context + entitlement gating (read-only)
- siteIds + activeSiteId behavior
- features gated by EntitlementGrant reads (no client writes)

---

## Slice 3 — Admin provisioning (keystone)
Must support:
- create parent / learner / educator
- create GuardianLink (admin-only)
- create LearnerProfile / ParentProfile
- record admin-only “Kyle & Parrot” intake
- confirm parent sees learner, but cannot self-link

---

## Slice 4 — Sessions + occurrences + enrollments
- session templates and schedules
- session occurrences created or generated
- enrollments connect learners to sessions

---

## Slice 5 — Class ops: attendance + mission plans + attempts
- educator: open occurrence → plan → attendance → review queue
- learner: attempt → evidence → reflection → submit
- educator: review → notes

---

## Slice 6 — Offline-first for class-critical flows
- attendance offline queue
- mission attempt offline queue
- interventions offline queue
- deterministic IDs prevent duplicates

---

## Slice 7+ — Messaging, CMS, Marketplace, Contracting, Analytics
Implement each as a vertical slice with governance and security.

---

## Slice 12 — Pillar Coach + Intelligence (docs 21–27)
- popups reinforce accountability cycle
- learnerSignals computed (rules-based)
- teacher insights + interventions loop
- privacy boundaries enforced
- API endpoints contract adhered to

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `04_IMPLEMENTATION_PLAN_VERTICAL_SLICES.md`
<!-- TELEMETRY_WIRING:END -->
