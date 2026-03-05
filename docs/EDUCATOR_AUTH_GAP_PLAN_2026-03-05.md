# Educator + Auth Critical Gap Plan (2026-03-05)

## Scope
- Educator operational reliability (schedule, learners, attendance, session creation)
- Login/auth correctness for Flutter native and Next.js web
- Firebase as single source of auth truth

## Critical Deficiencies Found

### 1) Educator data not site-scoped end-to-end (High)
- Educator schedule/session/enrollment reads could return records outside the active site context.
- Provider reuse logic rebuilt educator services only on `educatorId`, not site changes.

### 2) Educator write-paths missing explicit site context (High)
- Session creation and attendance writes did not always include `siteId`.

### 3) Web auth profile subscription fragility (Medium)
- `AuthProvider` did not handle Firestore `onSnapshot` errors, which could keep UI auth state unresolved.

### 4) Web Firebase session-cookie drift risk (Medium)
- Session cookie sync relied mainly on explicit login/register flows; lacked auth-state-change synchronization hardening.

## Remediation Plan
1. Enforce site scoping in educator service read paths.
2. Rebuild educator provider on active-site changes.
3. Add `siteId` on educator write paths where applicable.
4. Add auth context resilience for profile listener errors.
5. Harden session cookie sync/clear behavior around Firebase auth state changes.
6. Add regression tests for educator site scoping.

## Implemented Fixes
- ✅ Added site-aware filtering in `EducatorService` for:
  - schedule occurrence loading
  - session loading
  - enrollment-based learner resolution
  - learner profile inclusion
- ✅ Added `siteId` write-through in educator writes:
  - attendance records
  - session creation
- ✅ Updated provider wiring in `main.dart` to recreate `EducatorService` when active site changes.
- ✅ Hardened web `AuthProvider`:
  - handles profile snapshot errors with safe state fallback
  - syncs session cookie on auth state acquire
  - clears session cookie on auth state clear
- ✅ Added regression tests for educator site scoping in:
  - `test/educator_service_site_scope_test.dart`

## Firebase Auth Wiring Status

### Native (Flutter)
- Uses Firebase Auth SDK via `AuthService` (`signInWithEmailAndPassword`, Google, Microsoft).
- Session/profile bootstrap continues to source from Firebase Auth + Firestore.

### Web (Next.js)
- Login/register use Firebase Auth client methods (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword`).
- Session cookie issuance is Firebase Admin-backed in `/api/auth/session-login`.
- No fake/non-Firebase session bypass path retained.

## Remaining Watchlist (non-blocking)
- Firestore rules warnings in deploy output (compiled successfully but should be cleaned).
- Firebase function deploys can hit temporary Cloud Functions mutation quotas; retry strategy should remain in runbook.
