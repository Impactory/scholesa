# UI Regression Report

Date: 2026-02-20
Scope: Key screens/flows, visual checks, navigation, forms (Flutter app)

## Executive Summary

- Overall status: **PASS (coverage-limited for pixel-level visual diffing)**
- Automated regression tests: **145 passed, 0 failed**
- Targeted UI/auth/navigation tests: **22 passed, 0 failed**
- High-severity UI blockers: **0**

---

## 1) Key Screens / Flows — PASS

### Verified flow surfaces
- Public landing screen (`/welcome`) with Sign In CTAs routing to `/login`.
- Login screen (`/login`) with email/password and social sign-in handlers routing to `/` on success.
- Register route disabled via redirect (`/register` -> `/login`).
- Auth redirect flow (public/protected transitions) validated in tests.

### Evidence
- Route/redirect implementation: `lib/router/app_router.dart`
- Landing CTAs: `lib/ui/landing/landing_page.dart`
- Login success handlers: `lib/ui/auth/login_page.dart`
- Redirect logic tests passing: `test/router_redirect_test.dart`

---

## 2) Visual Checks — PASS (static/code-level)

### Checked
- Login page uses `ScholesaColors` tokens and shared themed styles.
- Landing and dashboard render complete scaffolded UI sections and role card structures.
- No render-time test failures in widget smoke test.

### Evidence
- Login theme usage and layout: `lib/ui/auth/login_page.dart`
- Landing layout sections and CTA placement: `lib/ui/landing/landing_page.dart`
- Dashboard card rendering structure: `lib/dashboards/role_dashboard.dart`
- Widget smoke test passing: `test/widget_test.dart`

### Coverage note
- No golden/snapshot visual tests are present for pixel-level regression detection.
- This pass confirms structural and behavior-level UI stability, not screenshot-level deltas.

---

## 3) Navigation Regression — PASS

### Checked
- Router has full route map with role-gated protected routes.
- Public route behavior is correct for loading/authenticated/unauthenticated states.
- Legacy signup path remains blocked (`/register` redirects to `/login`).
- Landing, login, profile, HQ switcher, and dashboard sign-out navigation handlers are present.

### Evidence
- Router and redirects: `lib/router/app_router.dart`
- Redirect tests passing: `test/router_redirect_test.dart`
- Navigation handler references found in:
  - `lib/ui/landing/landing_page.dart`
  - `lib/ui/auth/login_page.dart`
  - `lib/modules/profile/profile_page.dart`
  - `lib/modules/hq_admin/hq_role_switcher_page.dart`
  - `lib/dashboards/role_dashboard.dart`

---

## 4) Forms Regression — PASS

### Checked
- Login form validates required email and password with minimum password length.
- Forgot-password dialog validates email format and handles send state.
- Provisioning and HQ admin modules include multiple `Form` + `TextFormField` surfaces (static presence check).
- No form-related test failures in full regression run.

### Evidence
- Login validation messages and submit wiring: `lib/ui/auth/login_page.dart`
- Form surfaces discovered in:
  - `lib/modules/provisioning/provisioning_page.dart`
  - `lib/modules/hq_admin/user_admin_page.dart`
  - `lib/ui/auth/login_page.dart`

---

## Test Execution Evidence

- Full app tests:
  - Files: all 9 tests under `apps/empire_flutter/app/test/`
  - Result: **145 passed, 0 failed**
- Targeted UI/navigation/auth tests:
  - `test/widget_test.dart`
  - `test/router_redirect_test.dart`
  - `test/auth_service_test.dart`
  - Result: **22 passed, 0 failed**

---

## Residual Risk / Follow-up

1. **Pixel-level visual drift risk (low-medium)**
   - Add Flutter golden tests for:
     - `LandingPage` (mobile + desktop breakpoints)
     - `LoginPage` (idle, error, loading states)
     - `RoleDashboard` per role card set

2. **Flow-level UI automation gap (medium)**
   - Add widget/integration tests for:
     - Landing -> Login -> Auth redirect -> Dashboard
     - Forgot password dialog validation and success snackbar
     - Disabled register route assertion from UI navigation

## Final Status

- UI regression requested scope is complete.
- Current release UI posture: **GO** (with documented visual-automation coverage gap).