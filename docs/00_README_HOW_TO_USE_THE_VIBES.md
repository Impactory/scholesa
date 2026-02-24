# 00_README_HOW_TO_USE_THE_VIBES.md

These docs define the **production contract** for Scholesa’s Empire platform.

Target stack:
- **Flutter web-first** app (responsive, PWA-capable)
- **Dart API** on **Cloud Run**
- **Firebase Auth + Firestore + Storage**
- **Offline-first** local store (**Isar**) + sync queue

This platform exists to run **physical schools** with a digital backbone that enforces:
**Plan → Do → Evidence → Reflect → Review → Improve**.

---

## “Production-ready” definition (strict)
A feature is production-ready only when:
1) Schema contract updated (`docs/02A_SCHEMA_V3.ts`)
2) Firestore rules enforce access (even if UI tries to bypass)
3) API enforces server authority where required (billing, privileged writes, computed intelligence)
4) Offline-first behavior works for class-critical flows
5) Telemetry events emitted without sensitive leaks
6) QA passes (`docs/09`)
7) Audit passes (`docs/19`) with evidence
8) Traceability updated (`docs/10`)

---

## Design language continuity (do not change)
The platform must **preserve the current design language** and **must not be re-skinned** during implementation.

Rules:
- Do **not** change global typography scale, spacing rhythm, navigation patterns, or token naming.
- Do **not** replace the existing design system approach.
- Use existing components first. Only add new components if required, and then:
  - add them inside `design_system/`
  - document usage + responsive behavior
  - include interaction states: hover/focus/pressed/disabled/loading
  - do not modify existing component visuals except for bug fixes

Codex must treat design as a **locked constraint**, not a creative variable.

---

## How Codex must work (non-negotiable)
For every task (feature, fix, refactor):

1) Scope it (roles, collections, endpoints, offline)
2) Read required docs (01, 02, 02A, 05, 06, 08, 09, 11, plus 26/27 where relevant)
3) Write a task plan (`docs/11_CODEX_TASK_TEMPLATE.md`)
4) Update traceability early (`docs/10_TRACEABILITY_MATRIX.md`)
5) Implement end-to-end (UI + API + rules + offline + telemetry + tests)
6) Prove it (build logs + QA evidence)
7) Audit (docs/19 + docs/20)

---

## Core invariants (must never regress)
- Admin-only provisioning (parents cannot self-link learners)
- Server-authoritative billing (client cannot grant entitlements)
- Parent privacy boundary (parents cannot read teacher intelligence)
- Offline-first for class operations
- Stable builds (pinned versions, reproducible builds)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `00_README_HOW_TO_USE_THE_VIBES.md`
<!-- TELEMETRY_WIRING:END -->
