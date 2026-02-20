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
