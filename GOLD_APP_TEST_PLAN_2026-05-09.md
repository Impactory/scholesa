# Scholesa Gold App Test Plan - 2026-05-09

This is an internal verification plan. Scholesa is not gold-ready until every required workflow below is verified with real or canonical synthetic data across web, Cloud Run, Firebase, and native channels.

## Current Verified In This Pass

- Flutter analyzer: `flutter analyze --no-fatal-infos` passed.
- Full Flutter suite: `flutter test --reporter compact` passed with `+1092`.
- Focused blocker suite passed: auth sign-out, global session menu, app shell chrome, learner today evidence loop, and global AI assistant overlay.
- Non-deploying release gate passed after fixing the root logout contract test and restoring the functions evidence-chain emulator env flag in `./scripts/deploy.sh release-gate`.
- Screenshot gap fixed: the shared global session chrome no longer renders a separate wide-layout Sign Out pill over page controls; sign-out remains available inside the account menu.
- MiloOS floating support gap fixed at the root overlay: the global assistant entry is now a bounded icon-only FAB, no hover tooltip/bubble/pulse expands over page controls, and the global FAB is hidden on the dedicated learner MiloOS page.
- MiloOS spoken-copy gap fixed: startup and voice-only status copy now speaks as a supportive coach, and browser/Flutter TTS defaults are tuned toward slower, warmer speech.
- Logout reliability gap fixed: Google/provider sign-out cleanup is now bounded best effort, so Firebase sign-out, recent-session clear, and app-state clear still complete when provider cleanup hangs.
- MiloOS voice humanizing pass extended: web TTS now uses a slightly slower, lower-pitch profile and prefers natural/neural browser voices before generic fallbacks.
- Focused MiloOS validation passed after the hover/voice fix: `flutter test test/ai_coach_widget_regression_test.dart test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart test/ui_golden_test.dart` and focused Flutter analyzer both passed.
- Emulator stability pass completed after the MiloOS fix: Firestore rules passed 119/119, evidence-chain emulator passed 3/3, and analytics emulator passed 17/17 after correcting stale nullable telemetry metric expectations.
- Non-deploying release gate passed after the emulator fix and latest MiloOS changes; the embedded Flutter gate passed with `+1092: All tests passed!`, then diff hygiene passed.
- Flutter web release build passed: `flutter build web --release`.
- Local native compiles passed after the session chrome fix: macOS release with repo no-sign settings, iOS release with `--no-codesign`, and Android release AAB/APK.
- Cloud Run publish through `./scripts/deploy.sh flutter-web` succeeded for the latest MiloOS hover/voice pass on `studio-3328096157-e3f79` / `empire-web`. Cloud Build `d7d1dc42-dbdb-40f3-96df-3702ff72fe47` built image tag `20260510-121721`; revision `empire-web-00087-g7d` is latest ready and serves 100 percent traffic.
- Live post-deploy probes passed: `https://scholesa.com` returned 200, `https://scholesa.com/videos/proof-flow.mp4` returned 200 as `video/mp4`, and direct Cloud Run origin returned 200.
- Cloud Run publish through `./scripts/deploy.sh flutter-web` succeeded for the logout/voice hardening pass. Cloud Build `a0c6a065-058d-46c8-9904-5f6780e3095c` built image tag `20260510-123327`; revision `empire-web-00088-ln2` is latest ready and serves 100 percent traffic.
- Live post-deploy probes passed again for revision `empire-web-00088-ln2`: `https://scholesa.com` returned 200, `https://scholesa.com/videos/proof-flow.mp4` returned 200 as `video/mp4`, and direct Cloud Run origin returned 200.
- Gold stability/security next-step docs added: `GOLD_STABILITY_SECURITY_NEXT_STEPS_2026-05-10.md`, `GOLD_WORKFLOW_BUG_COVERAGE_MATRIX_2026-05-10.md`, and `GOLD_EMULATED_TEST_PLAN_2026-05-10.md`.
- Native-channel distribution remains blocked by missing signing, provisioning, App Store Connect, Google Play, and notarization prerequisites reported by `./scripts/native_distribution_readiness.sh`.
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
