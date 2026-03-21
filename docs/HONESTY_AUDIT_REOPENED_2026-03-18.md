# Reopened Honesty Audit

Last updated: 2026-03-21
Status: Beta ready, not gold ready
Scope: Flutter app plus release operations for web and native surfaces

This is the reopened honesty pass after blocker remediation, clean builds, live web rollout checks, shared-device logout verification, and native release-path hardening.

## Audit Decision

- Not gold ready.
- Beta ready for a controlled audience.
- The main remaining risk is release completeness for native distribution, not fake or dead-end user-facing product paths on the core app routes.

## A. Release Matrix Updated

### App and route status

- Site dashboard truthfulness: fixed.
  - The disconnected pillar card is removed from the main site dashboard path.
- Educator learner support completion: fixed.
  - The learner sheet now supports a persisted follow-up request instead of ending in a dead informational box.
- Parent billing honesty: fixed as honest view-only behavior.
  - The billing surface now behaves as a billing summary and support-handoff surface instead of pretending to offer self-service actions it does not complete.
- Route canonicalization: fixed for the audited aliases.
  - Alias routes now normalize via redirects instead of competing canonical destinations.
- Shared-device logout safety: verified.
  - Logout already existed in the app; regression coverage now proves Settings sign-out clears session state and returns to an unauthenticated route.
- Global authenticated logout availability: fixed.
  - Flutter now exposes a shared account/logout entrypoint from the routed app shell instead of relying on Settings, Profile, or specific dashboards.
  - Root web protected routes continue to mount shared navigation with sign-out available from the common shell.

### Coverage status

- Gold-path page coverage is materially improved.
- Direct page tests exist for the priority audited routes:
  - `site_dashboard_page`
  - `educator_learners_page`
  - `parent_billing_page`
  - `site_ops_page`
  - `missions_page`
  - `habits_page`
  - `site_billing_page`

### Release operations status

- Web deploy honesty: improved and verified.
  - `scholesa-web` was verified on the latest ready revision with 100% traffic.
  - `empire-web` was verified on the latest ready revision with 100% traffic after explicit traffic promotion.
- Native build honesty: improved.
  - iOS local and CI release paths now fail early on missing signing prerequisites.
  - Android local and CI release paths now support store-grade release flow around `.aab` output and internal-track upload automation.

## B. Fixes Completed

### Product and flow fixes

1. Removed the site dashboard pillar telemetry card from the primary path.
2. Replaced educator learner-support dead end with persisted follow-up requests.
3. Canonicalized audited route aliases into redirects.
4. Consolidated duplicated Firestore session-occurrence lookup logic in the AI overlay.
5. Added regression proof for shared-device logout from Settings.
6. Verified parent billing as honest view-only billing summary behavior.
7. Added a navigator-key-driven global Flutter session menu so every authenticated routed screen has Profile, Settings, and Sign Out available from the shell.
8. Added web regression proof that the protected layout still mounts the shared Navigation sign-out control.
9. Added shell-level proof that the real Flutter app still mounts the global session menu from `main.dart`.
10. Added protected-route inventory proof that every governed web workflow page stays under the shared sign-out layout.
11. Fixed `SiteOpsPage` day-open inference so the screen uses freshly loaded presence data instead of stale prior state during initial load.
12. Hardened the site-ops workflow fixture against midnight rollover by anchoring seeded “today” events to the current day instead of `now - N minutes`.
13. Hardened educator learner supports so first-load learner or saved-plan failures block honestly instead of collapsing into `No support plans yet`.
14. Added stale-data recovery messaging and refresh proof for educator learner supports when saved plans fail after prior success.
15. Hardened partner deliverables so refresh failures preserve the last successful contracts and deliverables instead of wiping the page into a blocking outage.
16. Added direct partner deliverables proof for first-load outage and stale-refresh behavior.
17. Hardened partner integrations so first-load outages block honestly and refresh failures preserve the last successful connection state.
18. Added direct partner integrations proof for first-load outage and stale-refresh behavior.
19. Hardened partner listings so listing outages no longer collapse into `No Listings Yet` and refresh failures keep the last successful marketplace inventory visible.
20. Added direct partner listings proof for first-load outage and stale-refresh behavior.
21. Hardened HQ user-admin audit logs so first-load failures expose a retryable error state and refresh failures keep the last successful audit history visible with a stale banner.
22. Added direct HQ user-admin audit-log proof for stale-refresh honesty.
23. Hardened partner contracts and launches so refresh failures preserve the last successful workflow data instead of clearing contracts or launch plans.
24. Added direct partner contracting proof for stale contract and stale launch refresh behavior.
25. Hardened educator attendance roster rendering so refresh failures preserve the last successful class roster instead of masking it behind a blocking error state.
26. Added direct educator attendance roster proof for stale-refresh honesty.
27. Hardened recent attendance, partner, and HQ audit surfaces for accessibility so stale-data warnings announce as live status updates and icon-only recovery or creation actions stay labeled for assistive technology.
28. Hardened site ops runtime rollout recovery so operators can refresh the page from the app bar and retry runtime rollout outages directly from the affected card.
29. Added direct site ops runtime rollout recovery proof for first-load outage recovery and stale partial-outage retry visibility.
30. Hardened site identity stale-refresh behavior so operators keep seeing the last successful identity queue with the refresh failure detail still visible and assistive-tech announced.
31. Refreshed direct site identity proof for stale-refresh detail visibility.
32. Hardened site incidents stale-refresh behavior so operators keep the last successful incident queue with the refresh failure detail still visible and assistive-tech announced.
33. Refreshed direct site incidents proof for stale-refresh detail visibility.
34. Hardened site integrations health stale-refresh behavior so operators keep the last successful integrations view with the refresh failure detail still visible, the refresh control labeled, and the warning assistive-tech announced.
35. Refreshed direct site integrations health proof for stale-refresh detail visibility.

### Release and operations fixes

1. Patched Cloud Run deploy scripts to route traffic to latest revisions when not in no-traffic mode.
2. Added local iOS preflight via `verify_local_release` and stricter CI signing validation.
3. Added Android local release setup, Android release preflight, Android CI materialization scripts, and Google Play internal-track workflow.
4. Updated `flutter-android` to build both the Android App Bundle and APK.

## C. Evidence Of Verification

### Focused app verification

- Focused regressions passed after the first remediation wave: 17 passed, 0 failed.
- Focused educator follow-up regressions passed: 10 passed, 0 failed.
- Focused attendance honesty regressions passed: 5 passed, 0 failed.
- Focused operator accessibility follow-up suites passed: 29 passed, 0 failed.
- Focused site ops recovery suites passed: 6 passed, 0 failed.
- Focused site identity honesty regressions passed: 2 passed, 0 failed.
- Focused site incidents honesty regressions passed: 4 passed, 0 failed.
- Focused site integrations health regressions passed: 4 passed, 0 failed.
- Priority blocker page batch passed: 16 passed, 0 failed.
- Settings logout and auth coverage passed: 26 passed, 0 failed.
- Global session menu regressions passed: 2 passed, 0 failed.
- Flutter shell logout mount regression passed: 1 passed, 0 failed.
- Protected web logout shell regression passed: 3 passed, 0 failed.
- Educator learner supports and partner deliverables honesty regressions passed: 12 passed, 0 failed.
- Partner integrations honesty regressions passed: 4 passed, 0 failed.
- Partner listings, integrations, and deliverables honesty regressions passed: 12 passed, 0 failed.
- HQ user-admin audit-log honesty regressions passed: 12 passed, 0 failed.
- Partner contracting workflow honesty regressions passed: 6 passed, 0 failed.

### Full Flutter gate verification

- `flutter analyze` passed.
- `flutter test` passed in the release validation run used by `flutter-android`.
- `flutter test` passed after the logout-shell and site-ops truthfulness follow-up: 497 passed, 0 failed.

### Build verification

- Root web production build succeeded.
- Flutter web production build succeeded.
- Flutter Android debug build succeeded.
- Flutter Android release App Bundle build succeeded.
- Flutter Android release APK build succeeded.
- Flutter iOS release build without codesigning succeeded.

### Live deploy verification

- `scholesa-web`: latest created revision matched latest ready revision; traffic 100% latest.
- `empire-web`: latest created revision matched latest ready revision; traffic 100% latest after traffic correction.

## D. Remaining Blockers

### Gold blocker 1: iOS distribution completeness

The iOS build path is clean, but distribution is not complete.

Remaining external prerequisites:

- Apple Distribution certificate with private key
- App Store provisioning profile
- `.env.app_store_connect.local` or CI-equivalent signing and App Store Connect secrets on the target machine or runner

Current honest state:

- App Store Connect auth can be verified.
- TestFlight upload cannot be completed from this machine yet.

### Gold blocker 2: Android distribution proof

The Android build path is now stronger, but actual store upload has not been proven in this environment.

Remaining external prerequisites:

- Google Play service account JSON
- Android keystore secret material for local or CI upload
- Valid GitHub secrets for `android-release.yml`

Current honest state:

- The repo can now build a store-grade `.aab` and has an internal-track automation path.
- Actual Play upload is still unverified until credentials are wired.

### Residual operational risk

- The repo has multiple deploy/release scripts with similar names across surfaces, which previously caused cwd-related confusion.
- That risk is lower than before, but still worth operational discipline.

## E. Recommendation

- Recommendation: beta ready.
- Not gold ready.

Reasoning:

- Core app surfaces are materially more honest and completable than at the start of the audit.
- Web rollout evidence is now real, not assumed.
- Native release automation is materially better, but native distribution itself is still not fully proven.

## What Would Change This To Gold Ready

1. Complete one successful iOS TestFlight upload through the supported release path.
2. Complete one successful Android internal or production Play upload through the supported release path.
3. Keep the audited gold-path regressions green after those release-path proofs.
