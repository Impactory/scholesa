# Scholesa Flutter — RC3 Release Gate (AI/BOS/TTS/STT Floating Assistant)

**Version Target:** `1.0.0-rc.3`
**Date:** 2026-03-02
**Scope:** End-to-end wiring and release readiness for lower-right floating AI assistant

For platform-wide March 8 live deployment criteria, also use:
- `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md`
- `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`
- `RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md`

---

## Gate Summary

| Gate | Result | Evidence |
|---|---|---|
| Runtime analyzer (targeted) | PASS | `flutter analyze lib/runtime/ai_coach_widget.dart lib/runtime/global_ai_assistant_overlay.dart lib/runtime/voice_runtime_service.dart` |
| App-wide analyzer | PASS | `flutter analyze` |
| Test suite | PASS | `flutter test` |
| Golden baselines | UPDATED + PASS | `flutter test test/ui_golden_test.dart --update-goldens` |
| Smoke test runbook | PASS (documented) | `docs/VOICE_RUNTIME_SMOKE_TEST.md` |

---

## End-to-End Wiring Status

### Floating Assistant Surface
- Lower-right FAB is mounted globally in app shell and opens the AI assistant sheet.
- Runtime is initialized with site/user role context and best-effort `sessionOccurrenceId` resolution.

### BOS Integration
- Runtime provider starts BOS listeners after session context resolution.
- BOS events (`ai_help_opened`, `ai_help_used`, `ai_coach_response`) are emitted from assistant interactions.
- Learner-only BOS confidence guard prevents role mismatch failures for non-learner roles and blocks low-confidence autonomous learner help.

### STT Integration
- Primary STT path: audio recording upload to `/voice/transcribe` (multipart).
- Fallback STT path: on-device speech recognition (`speech_to_text`).
- Mic permission handling and denial UX included.

### AI Integration
- Primary AI path: `/copilot/message` via voice API with auth token.
- Context includes role, mode, learner/site/session references, conversation turns, and learning-goals memory.
- Conversational prompt shaping enforces coaching style and no-final-answer behavior.
- Learner-facing responses require certified confidence `>= 0.97`; otherwise the UI must receive a safe escalation response.

### TTS Integration
- Primary TTS path: play `tts.audioUrl` from voice API via `audioplayers`.
- Fallback TTS path: local `flutter_tts` synthesis.
- Interrupt UX is implemented (tap to interrupt + haptic/click + snackbar).

---

## Conversational Intelligence Additions (RC3)

- Multi-turn context window included in AI prompt construction.
- Mode-aware coaching directives (`hint`, `verify`, `explain`, `debug`).
- BOS state snapshot + mission/checkpoint/session context injected.
- Lightweight in-session learning goals memory (max 3 goals, deduped).
- Read-only “Current goals” chips shown in UI.
- Educator/HQ-only “Clear goals” with confirmation dialog + telemetry.

---

## Gap Fixes Applied for RC3

1. Replaced obsolete broken BOS voice integration test with valid runtime widget test.
2. Fixed non-learner failure path and removed low-confidence learner fallback behavior.
3. Added session occurrence scoping resolver for BOS runtime context.
4. Added platform microphone/speech permissions for Android/iOS/macOS.
5. Added voice session lock/interrupt handling to prevent input race conditions.
6. Updated dependency baseline doc for new voice-stack packages.

---

## Release Note Addendum — HQ Curriculum Manager (2026-03-02)

### What shipped
- End-to-end persisted status flow for curriculum lifecycle: `draft -> review -> published`.
- Explicit transition CTAs added in curriculum details:
	- `Submit for Review` from Draft
	- `Publish Curriculum` from In Review
- Firestore mission writes now include transition metadata:
	- Review submission: `reviewSubmittedBy`, `reviewSubmittedAt`
	- Publish action: `published`, `publishedBy`, `publishedAt`
- UI now reflects transitions immediately and routes operator focus to the destination tab.

### Validation evidence
- `flutter test test/hq_curriculum_workflow_test.dart` (PASS)
	- Covers Draft -> In Review -> Published status progression.
	- Verifies persisted `missions.status == published` and publish/review actor metadata.
- `flutter test test/cta_reflection_test.dart` (PASS)
- `flutter test test/dashboard_cta_regression_test.dart` (PASS)
- Repository gate: `npm run rc3:preflight` (PASS)

---

## Remaining Risk Notes (Non-blocking)

- Golden files were intentionally updated due UI evolution; future UI changes should update goldens in same PR.
- Telemetry warnings in tests about Firebase app init are expected in local test context and do not block runtime behavior.

---

## RC3 Recommendation

**GO** for RC3 candidate ship for the floating AI voice runtime path.

Required operational step before release promotion:
- Execute on-device smoke checklist in `docs/VOICE_RUNTIME_SMOKE_TEST.md` across Android + iOS (and macOS if desktop release is included).
- Execute the platform big-bang cutover checklist in `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`.

Sign-off artifact:
- Complete `docs/vibe/RC3_SIGNOFF_CHECKLIST.md` with Engineering, QA, Product, and Release approvals.
