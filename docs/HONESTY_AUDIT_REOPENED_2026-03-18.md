# Reopened Honesty Audit

Last updated: 2026-03-22
Status: Beta ready, not gold ready
Scope: Flutter app plus release operations for web and native surfaces

This is the reopened honesty pass after blocker remediation, clean builds, live web rollout checks, shared-device logout verification, and native release-path hardening.

## Audit Decision

- Not gold ready.
- Beta ready for a controlled audience.
- The main remaining risk is release completeness for native distribution, not fake or dead-end user-facing product paths on the core app routes.

## Tightened Audit Criteria

This reopened pass now uses a stricter honesty standard.

What no longer counts as sufficient:

1. A page merely rendering without obvious placeholders.
2. A stale banner that keeps old data visible but does not prove the live system is healthy.
3. A direct route test that proves rendering but not mutation, reload, or scope correctness.
4. A completed dialog that only closes locally without proving persisted change.
5. A workflow that is technically honest but still makes educational claims without evidence provenance.

What must be true before a flow is treated as fully honest:

1. The user can tell whether the system is loading, empty, unavailable, stale, partially loaded, or saved.
2. The primary action either persists and reloads truthfully or fails explicitly.
3. The route exposes a real recovery path when backend refresh or mutation fails.
4. Role and site scope are enforced in the visible behavior, not just assumed in code.
5. Accessibility is preserved for warnings, blocked states, and recovery controls.
6. Evidence-bearing educational flows do not imply mastery, growth, or proof without a real underlying evidence chain.

Interpretation rule:

- `stale` means honest degraded mode, not full end-to-end success.
- `direct proof` means route behavior is tested, not that the whole workflow is fully certified.
- `fixed` means the specific fake or misleading behavior named in this document is closed; it does not automatically certify the surrounding workflow as gold-ready.

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

  Coverage interpretation under the tightened standard:

  - direct page coverage is necessary but not sufficient for gold
  - mutation plus authoritative reload proof carries more weight than rendering-only proof
  - operator and evidence-bearing surfaces remain partial until their critical write and provenance paths are directly exercised

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
36. Hardened HQ feature flags stale-refresh behavior so operators keep the last successful feature-flag and experiment data with refresh-failure detail visible, stale warnings assistive-tech announced, and app-bar recovery/history controls labeled.
37. Refreshed direct HQ feature flags proof for first-load failure detail, stale-refresh detail visibility, and labeled operator controls.
38. Added direct HQ feature flags rollout-control proof for owner-required validation and successful save with authoritative experiment reload.
39. Added direct HQ feature flags rollout-escalation proof for active-issue owner validation and successful save with authoritative experiment reload.
40. Added direct HQ feature flags rollout-alert triage proof for successful save with authoritative experiment reload and explicit backend-failure handling.
41. Added direct HQ feature flags failure-path proof for rollout-control and rollout-escalation backend mutations.
42. Added direct HQ feature flags alert-history proof so a saved rollout-triage note is visible through the route's own history surface.
43. Expanded HQ feature flags alert-history proof so saved rollout-control and rollout-escalation state is also visible through the route's own history surface.
44. Added direct HQ feature flags scope proof through HQ-only route gating and explicit HQ-bounded delivery context in the consequential governance dialogs.
45. Added explicit HQ feature flags boundary copy and proof that rollout status is not learner growth, mastery, Passport, portfolio, or AI-use disclosure truth.
46. Added direct HQ feature flags rollout-audit proof so saved triage, rollout-control, and rollout-escalation mutations are visible through the route's own audit feed.
47. Added direct `/site/sessions` create-path proof so the route now verifies persisted session creation, authoritative schedule reload from source-of-truth data, and explicit in-surface create failure without a fake appended session.
48. Added direct `/site/sessions` route-gate proof so only `site` and `hq` roles can access the route and the `/site/scheduling` alias redirects back to the canonical path.
49. Added direct `/site/provisioning` route proof so learner, parent, guardian-link, and cohort creation plus active-site guardian-link deletion are now verified in the focused page suite, and `/site/provisioning` now has direct site/HQ route-gate proof.
50. Fixed `/site/provisioning` learner and parent edit persistence in Firestore fallback mode and added direct route proof that the edit dialogs now persist updated learner and parent data instead of depending on unavailable API patch calls.
51. Added direct `/site/provisioning` mutation-failure proof for learner, parent, guardian-link, cohort, and guardian-link-delete flows, and fixed the route so guardian-link delete failures surface the real service error instead of a generic hidden-failure fallback.
52. Added direct `/site/provisioning` auditability proof for create, edit, and delete mutation telemetry so the focused route suite now verifies operator traces for learner creation, parent editing, and guardian-link deletion.
53. Fixed `/site/provisioning` success flows to re-load authoritative route data after create, edit, and delete mutations, and added direct proof that audited provisioning mutations settle on canonical source-of-truth state rather than local-only optimistic state.
54. Added direct educator attendance route proof for real enrolled-learner roster coupling plus attendance save success/failure, fixed attendance roster disposal so saving no longer triggers listener notifications while the widget tree is locked, proved saved attendance reloads from Firestore when the roster is reopened, and proved offline attendance saves queue truthfully without writing Firestore until sync resumes.
55. Added direct `/educator/attendance` route-gate proof that only educator, site, and HQ roles can access the route, so the remaining attendance risk is now broader workflow coupling rather than route-local access scope.
56. Added direct `/educator/attendance` telemetry proof that live saves emit `attendance.recorded` and offline saves emit `attendance.record_queued`, alongside the primary `attendance_save` CTA trace, so route-local auditability is now proven instead of inferred from implementation.
57. Fixed `/partner/listings` so the edit dialog persists real listing updates instead of showing a fake success snackbar, and added direct proof that published listing edits update Firestore and become visible on the site marketplace surface.
58. Added direct account-menu placement proof on learner missions, habits, and portfolio surfaces, and hardened additional Flutter-web headers on messages, site sessions, check-in, HQ user admin, and HQ sites so logout discoverability no longer depends only on the global overlay menu.
59. Fixed learner-missions MVL gate proof by restoring support for learner-level unresolved `mvlEpisodes` that are not tied to a specific `sessionOccurrenceId`, added runtime coverage for that contract, and hardened direct account-menu placement on profile, shared settings routes, HQ analytics, HQ billing, and HQ role switcher surfaces.
60. Fixed `/site/identity` approve and ignore actions so the route re-reads the authoritative queue before claiming success, and added direct proof that successful identity resolution disappears only after reload while reload failures keep stale matches visible with explicit verification-required copy instead of fake completion.
61. Fixed `/educator/learner-supports` support-plan saves so the route re-loads persisted support-plan state before claiming success, and added direct proof that verified saves only settle after persisted reload while reload failures fail closed with explicit verification-required copy instead of opening outcome logging on unverified state.
62. Fixed `/educator/integrations` sync honesty so queued syncs are no longer reported as failed just because the post-queue refresh fails, preserved stale integration cards on reload failure instead of blanking the route, and added direct proof that the route distinguishes queue failure from verification-required refresh failure.
63. Added direct `/educator/learner-supports` and `/educator/integrations` route-gate and telemetry proof so both routes now verify educator/site/HQ access boundaries in focused tests and emit auditable route-local traces for support-plan updates and integration sync menu actions instead of leaving scope and auditability inferred from implementation.
64. Added direct `/site/identity` route-gate and telemetry proof so the route now verifies site/HQ-only access in a focused test and emits auditable approve-match and ignore-match CTA traces with match context instead of leaving route-local scope and operator-decision auditability inferred from implementation.
65. Added direct `/site/integrations-health` route-gate and telemetry proof so the route now verifies site/HQ-only access in a focused test and emits auditable `connect_integration`, `force_sync_integration`, `disconnect_integration`, and `retry_failed_syncs` CTA traces from the integration card and option sheet instead of leaving route-local scope and key connection-action auditability inferred from implementation.
66. Added direct `/site/ops` workflow-composition proof so the route now verifies same-site check-ins and same-day sessions compose into the live present count and timetable, ignore cross-site data, and refresh back to source-of-truth state after new check-in and checkout events are written.
67. Added direct downstream site workflow proof from `/site/sessions` into `/site/ops` so a session created through the real sessions route now has focused widget evidence that it persists for the active site and immediately appears in the Site Ops timetable while cross-site sessions stay excluded.
68. Patched `/site/sessions` create persistence to write same-day `sessionOccurrences` alongside the canonical `sessions` record, and added direct proof that a class created through the real sessions route now appears in `/educator/attendance` as a live class for the active site instead of remaining invisible to the attendance workflow.
69. Added direct downstream educator workflow proof that importing a known learner through the real `/educator/sessions` roster-import dialog creates an active enrollment that appears in the `/educator/attendance` roster for the same class, and patched the educator session detail sheet so long values wrap instead of overflowing and obscuring lower actions in smaller viewports.
70. Patched `/site/provisioning` learner creation to reconcile matching `pending_provisioning` roster-import rows into active `enrollments`, mark those queue rows as provisioned, and added direct cross-route proof that an unknown learner imported through the real `/educator/sessions` roster dialog appears in `/educator/attendance` after the learner is created through the real `/site/provisioning` flow.
71. Added direct cross-route proof that when a learner already exists on another site, the real `/site/provisioning` learner-create flow links that existing user into the active site instead of duplicating them, reconciles the queued roster-import row, and makes the learner appear in `/educator/attendance` for the original class.
72. Added direct downstream educator workflow proof that a learner queued through the real `/educator/sessions` roster-import dialog appears in the real `/educator/learners` roster after the learner is created through the real `/site/provisioning` flow, closing the next educator-side consumer of provisioning and enrollment truth beyond attendance.
73. Added direct downstream educator workflow proof that an existing learner from another site appears in the real `/educator/learners` roster after the real `/site/provisioning` learner-create flow links that user into the active site instead of duplicating them, closing the cross-site branch for the learner-roster consumer as well.
74. Added direct downstream site workflow proof that a guardian link created through the real `/site/provisioning` flow appears on the real `/site/pickup-auth` route via guardian-fallback coverage, and patched pickup-authorization learner-name resolution so provisioning-created learner profiles use `displayName` when `preferredName` and `legalName` are absent instead of collapsing to learner IDs.
75. Added direct downstream site workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow feed the real `/site/checkin` quick-pickup path, so guardian-link fallback can resolve a live present learner by parent phone and complete the actual checkout flow without any hand-seeded pickup-authorization document.
76. Added direct downstream educator and site-operations workflow proof that a queued roster import marked reviewed through the real `/site/integrations-health` queue remains terminal: later creating a matching learner through the real `/site/provisioning` flow does not reconcile the row into an enrollment and does not make that learner appear in `/educator/attendance`.
77. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow appear on the real `/parent/summary` route via `ParentService` guardian-link resolution, and that the summary only shows activity for the linked learner rather than unrelated learner activity from the same site.
78. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow appear on the real `/parent/consent` route via live guardian-link resolution, and that the consent surface only shows records for the linked learner rather than unrelated consent records from the same site.
79. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow appear on the real `/parent/child/:learnerId` route via `ParentService` learner-summary loading, and that the child detail surface shows only the linked learner's activity, upcoming session, and passport context rather than unrelated site learner data.
80. Added direct downstream site consent workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow appear on the real `/site/consent` route, and patched `SiteConsentService` name resolution to honor provisioning-created learner and parent profile `displayName` values when `preferredName` and `legalName` are absent.

### Release and operations fixes

1. Patched Cloud Run deploy scripts to route traffic to latest revisions when not in no-traffic mode.
2. Added local iOS preflight via `verify_local_release` and stricter CI signing validation.
3. Added Android local release setup, Android release preflight, Android CI materialization scripts, and Google Play internal-track workflow.
4. Updated `flutter-android` to build both the Android App Bundle and APK.

## C. Evidence Of Verification

### Focused app verification

- Focused regressions passed after the first remediation wave: 17 passed, 0 failed.
- Focused educator follow-up regressions passed: 10 passed, 0 failed.
- Focused attendance honesty regressions passed: 9 passed, 0 failed.
- Focused operator accessibility follow-up suites passed: 29 passed, 0 failed.
- Focused site ops recovery suites passed: 8 passed, 0 failed.
- Focused site identity honesty regressions passed: 2 passed, 0 failed.
- Focused site incidents honesty regressions passed: 4 passed, 0 failed.
- Focused site integrations health regressions passed: 4 passed, 0 failed.
- Focused HQ feature flags regressions passed: 22 passed, 0 failed.
- Focused site provisioning regressions passed: 11 passed, 0 failed.
- Focused site sessions regressions passed: 9 passed, 0 failed.
- Priority blocker page batch passed: 16 passed, 0 failed.
- Settings logout and auth coverage passed: 26 passed, 0 failed.
- Global session menu regressions passed: 2 passed, 0 failed.
- Flutter shell logout mount regression passed: 1 passed, 0 failed.
- Protected web logout shell regression passed: 3 passed, 0 failed.
- Educator learner supports and partner deliverables honesty regressions passed: 12 passed, 0 failed.
- Partner integrations honesty regressions passed: 4 passed, 0 failed.
- Partner listings, integrations, and deliverables honesty regressions passed: 13 passed, 0 failed.
- HQ user-admin audit-log honesty regressions passed: 12 passed, 0 failed.
- Partner contracting workflow honesty regressions passed: 6 passed, 0 failed.
- Focused educator route-gate and telemetry regressions passed: 18 passed, 0 failed.
- Focused site identity route-gate and telemetry regressions passed: 8 passed, 0 failed.
- Focused site integrations health route-gate and telemetry regressions passed: 10 passed, 0 failed.
- Focused site ops, sessions, and provisioning workflow regressions passed: 13 passed, 0 failed.
- Focused site sessions and attendance downstream workflow regressions passed: 19 passed, 0 failed.
- Focused educator sessions and attendance downstream workflow regressions passed: 17 passed, 0 failed.
- Focused provisioning, educator sessions, and attendance downstream workflow regressions passed: 40 passed, 0 failed.
- Focused provisioning, educator sessions, and attendance downstream workflow regressions passed after the cross-site learner-linking proof and workflow-bridge cleanup: 41 passed, 0 failed.
- Focused provisioning, educator sessions, educator learners, and attendance downstream workflow regressions passed: 50 passed, 0 failed.
- Focused provisioning, educator sessions, educator learners, and attendance downstream workflow regressions passed after adding the cross-site learner-roster proof: 51 passed, 0 failed.
- Focused attendance downstream workflow regressions passed after proving reviewed roster imports stay terminal: 17 passed, 0 failed.
- Focused provisioning, educator sessions, educator learners, and attendance downstream workflow regressions passed after proving reviewed roster imports stay terminal: 52 passed, 0 failed.
- Focused site pickup authorization regressions passed after the provisioning-to-pickup fallback proof and learner-name fix: 4 passed, 0 failed.
- Focused site check-in regressions passed after the provisioning-to-checkin guardian-fallback proof: 7 passed, 0 failed.
- Focused provisioning, site ops workflow, pickup authorization, and check-in regressions passed after the provisioning-to-checkin guardian-fallback proof: 46 passed, 0 failed.
- Focused parent surface workflow regressions passed after the provisioning-to-parent-child guardian-link proof: 13 passed, 0 failed.
- Focused parent consent regressions passed after the provisioning-to-parent-consent guardian-link proof: 5 passed, 0 failed.
- Focused site consent regressions passed after the provisioning-to-site-consent guardian-link proof and profile-name fallback fix: 4 passed, 0 failed.
- Focused provisioning, site consent, pickup authorization, and check-in regressions passed after the provisioning-to-site-consent guardian-link proof: 28 passed, 0 failed.

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
