# Scholesa Gold App Test Plan - 2026-05-09

This is an internal verification plan. Scholesa is not gold-ready until every required workflow below is verified with real or canonical synthetic data across web, Cloud Run, Firebase, and native channels.

## Current Verified In This Pass

- Flutter analyzer: `flutter analyze --no-fatal-infos` passed.
- Full Flutter suite: `flutter test --reporter compact` passed with `+1090`.
- Focused blocker suite passed: auth sign-out, global session menu, app shell chrome, learner today evidence loop, and global AI assistant overlay.
- Live proof-flow video deployment was previously verified on `scholesa.com` with byte-for-byte MP4 match.

## Release-Blocking Test Tracks

1. Public entry and Cloud Run
   - Verify `scholesa.com`, `www.scholesa.com`, and direct Cloud Run origin resolve to the intended `empire-web` service and latest revision.
   - Verify landing CTAs, proof-flow video, original SVG logo, locale routing, cache-busted Flutter runtime assets, and no internal release wording on public surfaces.
   - Verify unauthenticated routes do not expose protected data or privileged navigation.

2. Auth, session, and sign-out
   - Verify email, Google, and Microsoft login paths against the configured Firebase project.
   - Verify missing-profile bootstrap fails closed and returns to the public entry route.
   - Verify sign-out from page header menus, settings, profile, and global/account menus clears Firebase Auth state, app state, recent-login state, and protected navigation.
   - Verify telemetry and logout audit failures or hangs never block sign-out.

3. Role gates and route access
   - For learner, educator, parent, site, partner, and HQ roles, verify every enabled route in `kKnownRoutes` accepts allowed roles and rejects disallowed roles.
   - Verify Firebase custom claims, Firestore rules, web route metadata, and native role gates agree.
   - Verify site-scoped users cannot read or write another site's data.

4. Admin-HQ capability setup
   - Verify capability frameworks, progression descriptors, rubric templates, checkpoints, and unit/mission mappings are persisted and connected.
   - Verify every rubric outcome can map to a capability update or clearly remains pending.
   - Verify imports/edits/deletes are audited and permission-safe.

5. Admin-School and site operations
   - Verify provisioning, roster reconciliation, sessions, occurrences, check-in/check-out, consent, pickup auth, incidents, billing, integrations health, and audit views with site-scoped data.
   - Verify operational dashboards show evidence health and readiness, not only totals.
   - Verify failed network reads preserve stale trusted data where intended and show explicit failure states.

6. Educator live workflow
   - Verify an educator can start a session, see roster/context, log an observation, apply a capability-linked rubric, review proof, and update learner support in under 10 seconds for live-class actions.
   - Verify observation logs include site, learner, session occurrence, capability, provenance, and timestamp.
   - Verify mobile classroom width remains usable without overlapping FABs, menus, or modal controls.

7. Learner evidence workflow
   - Verify learners can see what they are building, what capability they are growing, what evidence they have, what they must explain/verify next, and what belongs in portfolio.
   - Verify artifact submission, reflection, checkpoint, proof assembly, peer feedback, credentials, and portfolio pages persist real data.
   - Verify AI disclosure captures prompts, AI suggestions, learner changes, and independent explanation/proof where relevant.

8. Proof-of-learning verification
   - Verify explain-it-back, oral check, mini-rebuild, and checkpoint proof records can be captured, reviewed, failed, revised, and accepted.
   - Verify proof status is visible to learner, educator, portfolio, and reporting outputs.
   - Verify no mastery claim appears without proof/evidence provenance.

9. Growth, portfolio, and Passport outputs
   - Verify capability growth updates over time from reviewed evidence, not assignment completion, XP, averages, or attendance.
   - Verify reviewed evidence links into learner portfolio with artifacts, reflection, rubric result, proof status, and provenance.
   - Verify Passport/report outputs are generated only from actual evidence and explain missing-evidence fallbacks clearly.

10. Guardian and partner interpretation
    - Verify parent/guardian views answer what the learner can do, what evidence proves it, how they are growing, and what to work on next.
    - Verify partner outputs are permission-safe, evidence-backed, and understandable without internal context.
    - Verify no partner-facing claim is shown without evidence provenance.

11. Native channel
    - Verify Flutter web, iOS, Android, macOS, and any required desktop/native targets build from the current repo.
    - Verify native login, sign-out, offline queue, sync recovery, evidence capture, media upload, deep links, accessibility, and localization on real devices or approved device farms.
    - Verify TestFlight, Google Play internal testing, and macOS signing/notarization with real external signing/store assets before calling native gold-ready.

12. Security, privacy, and AI policy
    - Run Firestore rules tests and verify cross-site denial cases.
    - Run internal-AI guard: `npm run ai:internal-only:all`.
    - Verify audit trails for auth, evidence review, rubric application, AI assistance, exports, and admin changes.

## Required Automated Gates

- Root web: `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`.
- Firebase rules/functions: rules tests, functions lint/build/test, emulator-backed integration paths for auth, Firestore, Storage, and callable Functions.
- Flutter app: `flutter analyze --no-fatal-infos`, `flutter test --reporter compact`, golden tests, web build, and native builds for target platforms.
- E2E: browser smoke on Cloud Run plus emulator-backed role workflow tests for public, auth, learner, educator, site, HQ, parent, and partner paths.
- Deployment: verify Cloud Run revision/image/traffic, `/videos/proof-flow.mp4`, runtime asset cache headers, health endpoints, logs, and rollback path.

## Gold-Ready Exit Criteria

- Every primary role completes its critical workflow end-to-end using real persistence.
- Evidence can be captured, verified, interpreted, communicated, and traced through portfolio and report outputs.
- Sign-out, login, route guards, and menus function across desktop, mobile web, and native.
- No visible section falls into the app resilience error card during the tested role journeys.
- Native store/channel proof exists, not just local builds.
- Any remaining failure is documented as non-release-blocking with owner, severity, and fallback.
