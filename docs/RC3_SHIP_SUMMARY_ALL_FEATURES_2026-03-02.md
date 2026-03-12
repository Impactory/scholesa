# Scholesa RC3 Ship Summary (All Features)

Date: 2026-03-02  
Release Target: 1.0.0-rc.3  
Status: GO (all listed gates passing)

> Historical feature shipment snapshot only. Current release-control truth lives in `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md`, `RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md`, and the March 12 big-bang operator/checklist artifacts.

---

## 1) What shipped (all features)

### A. Voice + AI Runtime (Floating Assistant)
- Global lower-right assistant surface is wired in app shell.
- BOS runtime listeners are initialized with resolved session context.
- STT supports API transcription path plus local speech fallback.
- AI chat path is wired through authenticated copilot endpoint with role/session context.
- Learner-facing autonomous AI now requires certified confidence `>= 0.97`; low-confidence or unavailable inference escalates safely instead of fabricating help.
- TTS supports remote audio URL playback with local synthesis fallback.
- Interrupt controls and runtime lock handling are implemented to prevent race conditions.
- Multi-turn coaching context, mode-aware guidance, BOS snapshot context, and in-session goal chips are included.

### B. HQ Curriculum Manager Lifecycle (End-to-End)
- Full persisted lifecycle transitions are implemented:
  - Draft -> In Review
  - In Review -> Published
- Explicit lifecycle CTAs are available in curriculum details:
  - Submit for Review
  - Publish Curriculum
- Firestore mission transition metadata now persists:
  - reviewSubmittedBy, reviewSubmittedAt
  - published, publishedBy, publishedAt
- UI reflects status changes immediately and moves focus to the destination tab.

### C. Curriculum Workflow Features (Rubrics + Snapshots + Sharing)
- Create/edit curriculum persists to Firestore and reflects immediately in UI.
- Rubric workflow creates rubric entities and links missions.
- Snapshot workflow creates mission snapshot entities and bumps mission versions.
- Parent summary share action persists share markers and actor metadata.

### D. Runtime and UX Reliability Fixes
- Startup bootstrap loading lifecycle hardened to prevent splash hang.
- Compliance runtime root endpoint behavior hardened (browser/API-safe root handling).
- Mobile readability improvements applied to HQ curriculum dialogs:
  - improved contrast
  - safer form field styles
  - improved dialog scrollability/inset behavior

### E. Build/CI and Dependency Hardening
- RC2/RC3 regression pipeline hardening completed.
- Flutter web wasm policy enforced in release/build paths.
- CI install/noise hardening applied.
- Dependency baseline updated and in-major upgrades aligned.

---

## 2) Validation evidence (executed)

### Targeted workflow regressions
- flutter test apps/empire_flutter/app/test/hq_curriculum_workflow_test.dart -> PASS
- flutter test apps/empire_flutter/app/test/cta_reflection_test.dart -> PASS
- flutter test apps/empire_flutter/app/test/dashboard_cta_regression_test.dart -> PASS

### Release gate
- npm run rc3:preflight -> PASS
  - role cross-link verification: PASS
  - role dashboard smoke checks: PASS
  - web production build: PASS
  - flutter wasm release build: PASS
  - compliance runtime endpoint smoke: PASS
  - i18n checks: PASS
  - VIBE telemetry audits/blockers: PASS

---

## 3) Deployment readiness conclusion
- End-to-end wiring is complete for both:
  - Floating AI runtime path
  - HQ curriculum lifecycle and workflows
- Persistence, UI reflection, and regression coverage are in place.
- Current RC3 recommendation remains GO for candidate ship under the big-bang production cutover policy.

---

## 4) Traceability links
- RC3 release gate detail: apps/empire_flutter/app/docs/vibe/RC3_RELEASE_GATE.md
- Cutover runbook addendum: docs/72_RELEASE_CUTOVER_RUNBOOK.md
- Audit addendum: AUDIT_REPORT.md
