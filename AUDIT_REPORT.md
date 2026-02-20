# Auth & Self-Create Smoke Audit

Date: 2026-02-20
Project: `studio-3328096157-e3f79`

## Scope
- Remove all self-signup CTAs and registration paths.
- Ensure login does not bounce authenticated users back to landing.
- Enforce Firestore user-profile creation by admin/HQ only.

## Automated Checks

1) **Signup path removal (code scan)**
- Searched Flutter app code for registration entry points:
	- `RegisterPage`
	- `registerWithEmailAndPassword`
	- `createUserWithEmailAndPassword`
	- direct `/register` navigations
- Result: **PASS** (no remaining matches in app lib sources).

2) **Build/static integrity**
- Command run: `flutter analyze` in `apps/empire_flutter/app`
- Result: **PASS** (no issues found).

3) **Firestore rules hardening (root rules)**
- Verified in `firestore.rules`:
	- `/users/{userId}` create is restricted to HQ: `allow create: if isHQ();`
	- helper function `isAdminOrHQ()` exists and compiles cleanly.
- Result: **PASS**.

4) **Firestore rules hardening (app-local rules)**
- Verified in `apps/empire_flutter/app/firestore.rules`:
	- `/users/{userId}` create is restricted to staff: `allow create: if isSignedIn() && isStaff();`
- Result: **PASS**.

5) **Production deployment**
- Command run: `firebase deploy --only firestore:rules --project studio-3328096157-e3f79`
- Result: **PASS** (`released rules firestore.rules to cloud.firestore`).

## Interactive UI Smoke (manual)
- Login UX and route flow after successful auth should be validated in a running app session:
	- open `/welcome` → `/login`
	- authenticate with provisioned user
	- confirm navigation remains in authenticated routes and does not bounce to landing
	- confirm `/register` redirects to `/login`
- Status: **Pending manual run**.

## Additional Automated Smoke (2026-02-20)

6) **Auth + redirect regression tests**
- Command run:
	- `flutter test test/router_redirect_test.dart test/auth_service_test.dart`
- Result: **PASS** (`All tests passed!`, 21 tests).

7) **Register flow hard-disable evidence**
- Verified no remaining Flutter app source references for:
	- `RegisterPage`
	- `registerWithEmailAndPassword`
	- `createUserWithEmailAndPassword`
	- direct `/register` navigations from UI flows
- Result: **PASS**.

## Conclusion
- Self-account creation is blocked in both app logic and deployed Firestore rules.
- Signup CTAs and registration paths are removed/disabled.
- Router reset issue previously causing landing bounce has been addressed in app routing lifecycle.
