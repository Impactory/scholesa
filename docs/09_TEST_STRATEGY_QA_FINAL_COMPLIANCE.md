# 09_TEST_STRATEGY_QA_FINAL_COMPLIANCE.md

This is the final QA script used before any release.

## Current UAT/QA status (2026-02-20)

Latest live-only regression run (no emulators) completed with:
- ✅ `npm run lint`
- ✅ `npm run build`
- ✅ `npm test`
- ✅ `flutter analyze`
- ✅ `flutter test` (157/157)
- ✅ `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run`
- ✅ `flutter build macos --release --no-tree-shake-icons`
- ✅ `flutter build ios --release --no-codesign --no-tree-shake-icons`

Security/test signal updates:
- ✅ `SECURITY_FINDING_001` remediated by removing root `.env.local`.
- ✅ Expected simulated sync-failure test logging was quieted; tests now run cleanly.
- ⚠️ iOS still shows expected `--no-codesign` warning when building unsigned artifacts.

## User profile acceptance state (2026-02-20)

| Profile Type | Current State | Flow Coverage |
|---|---|---|
| learner | ✅ Active | login → learner dashboard → missions/habits/today validated in live regression build/tests |
| educator | ✅ Active | login → educator dashboard → attendance/today validated in live regression build/tests |
| parent | ✅ Active | login → parent dashboard + summary flows validated in current deployed release |
| site | ✅ Active | login → provisioning/check-in route availability validated in release build |
| hq | ✅ Active | login → HQ user admin route availability validated in release build |
| partner | ✅ Active (route-level) | login → partner route availability validated; partner-specific deep UAT remains checklist-driven |

## Core flow status (live)

- ✅ Auth + role routing
- ✅ Dashboard rendering by user profile type
- ✅ Educator attendance + learner/parent summary continuity
- ✅ Offline sync engine regression clean (tests)
- ✅ Security boundary checks in deployed rules + role scoping
- ⚠️ Integrations (Classroom/Add-on/GitHub) remain manual UAT gates before full enablement

## Automated checks (must pass)
Flutter:
- flutter analyze
- flutter test
- flutter build web --release

API:
- dart analyze
- dart test
- docker build

---

## Manual checks (must pass)

### 1) Auth + role routing
- login routes to correct dashboard for all roles
- role cannot access other role routes

### 2) Admin provisioning (keystone)
- admin creates parent + learner + educator
- admin creates GuardianLink
- admin completes profiles + Kyle/Parrot intake
- parent sees linked learner
- parent cannot self-link or edit intake

### 3) Educator class ops
- open occurrence
- set mission plan
- take attendance
- review attempt queue

### 4) Learner workflow
- start attempt
- upload evidence
- reflect
- submit
- see review

### 5) Parent reinforcement
- see weekly summary
- acknowledge + pick 1 support action

### 6) Offline scenario
- go offline
- attendance + attempt + intervention logged
- go online
- sync completes with no duplicates

### 7) Security boundary
- parent denied access to intelligence collections
- client denied entitlement writes

Evidence required:
- screenshots + logs for each section

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `09_TEST_STRATEGY_QA_FINAL_COMPLIANCE.md`
<!-- TELEMETRY_WIRING:END -->
