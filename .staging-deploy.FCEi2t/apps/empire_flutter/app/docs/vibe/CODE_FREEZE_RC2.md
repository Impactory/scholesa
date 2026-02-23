# Scholesa Flutter — RC2 Code Freeze Report

**Version:** `1.0.0-rc.2+2`  
**Date:** 2025-02-19  
**Status:** CODE FREEZE — CONDITIONALLY APPROVED  

---

## Gate Checklist

| Gate | Status | Evidence |
|------|--------|----------|
| `flutter analyze` | **PASS** | 0 issues |
| `flutter test` | **PASS** | 110/110 passed, 0 failures |
| macOS release build | **PASS** | 112.0MB — `scholesa_app.app` |
| Android release build | **PASS** | 54MB APK (debug signing) |
| iOS release build | **PASS** | 59MB (unsigned) |
| Web release build | **PASS** | 48MB |
| Windows | **SKIPPED** | Requires Windows host |

---

## Blocker Fixes Applied This Cycle

### 1. Register Page Stub → Real AuthService (FIXED)
- **File:** `lib/ui/auth/register_page.dart`
- **Before:** `_handleRegister()` did `Future.delayed(1s)` — never created accounts
- **After:** Calls `context.read<AuthService>().registerWithEmailAndPassword(email:, password:, displayName:)`

### 2. Orphaned Research Models → Repositories Added (FIXED)
- **File:** `lib/domain/repositories.dart`
- Added 4 repositories with full CRUD:
  - `ResearchConsentRepository` — upsert, getById, getForLearner, listBySite, revoke
  - `StudentAssentRepository` — upsert, getById, getForLearner, listBySite, revoke
  - `AssessmentInstrumentRepository` — upsert, getById, listBySite, listByType, create
  - `ItemResponseRepository` — upsert, listByLearner, listByInstrument, submit
- **Total repositories:** 61 → 65

### 3. BosEventBus.track() Research Fields (FIXED)
- **File:** `lib/runtime/bos_event_bus.dart`
- `track()` now accepts: `actorRole` (default 'learner'), `contextMode`, `actorIdPseudo`, `assignmentId`, `lessonId`
- All fields passed through to `BosEvent` constructor

### 4. Minor Fixes
- `.gitignore` updated with `.env` / `.env.*` patterns
- `StudentAssentRepository.listBySite()` added

---

## Audit Results (8-Area Deep Sweep)

| Area | Verdict | Notes |
|------|---------|-------|
| Auth Flow Integrity | **PASS** | Register, login, SSO, signOut all wired correctly |
| BOS Event Envelope | **PASS** | eventId (UUID v4), schemaVersion 2.0.0, contextMode, ClientInfo all present |
| Model-Repository Parity | **PASS** | All 65 models have matching repositories |
| Security Posture | **WARNING** | Firestore rules locked; storage.rules blocks all access (P0 for GA) |
| Build Config | **WARNING** | Android release uses debug signing (P0 for Play Store) |
| Test Coverage | **WARNING** | 110 tests across 6 files; AuthService/repos/router untested |
| Offline & Sync | **WARNING** | Idempotency keys generated but not enforced server-side |
| Dead Code / Stubs | **WARNING** | 3 HQ pages use hardcoded data; 6 TODOs remain |

---

## Pre-GA Punch List (Must Fix Before Production)

| Priority | Item | Owner |
|----------|------|-------|
| **P0** | `storage.rules` — change from `if false` to authenticated read/write | DevOps |
| **P0** | Android release signing keystore | DevOps |
| **P1** | Server-side idempotency deduplication in sync handler | Backend |
| **P2** | Unit tests for AuthService, repositories, router redirect | QA |
| **P2** | Wire HQ Safety/FeatureFlags/Curriculum to Firestore | Feature |
| **P3** | Resolve 6 remaining TODO stubs in provisioning/parent pages | Feature |

---

## Build Artifacts

| Platform | Size | Signing | Path |
|----------|------|---------|------|
| macOS | 112.0MB | Release | `build/macos/Build/Products/Release/scholesa_app.app` |
| Android | 54MB | Debug keys | `build/app/outputs/flutter-apk/app-release.apk` |
| iOS | 59MB | Unsigned | `build/ios/iphoneos/Runner.app` |
| Web | 48MB | N/A | `build/web/` |

---

## Tech Stack Snapshot

- Flutter 3.38.9 / Dart 3.10.8
- Firebase: core 3.15.2, auth 5.7.0, firestore 5.6.12, storage 12.4.10, functions 5.6.2
- Android: AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, minSdk 24, compileSdk 36
- macOS deployment target: 11.0, iOS: 13.0

---

**Conclusion:** RC2 is code-frozen. All blocking regressions resolved. 0 analysis issues, 110 tests passing, all platform builds successful. Approved for internal testing with the P0 punch list items tracked for GA.
