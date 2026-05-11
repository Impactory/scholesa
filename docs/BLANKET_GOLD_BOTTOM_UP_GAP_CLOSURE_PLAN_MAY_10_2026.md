# Blanket Gold Bottom-Up Gap Closure Plan - 2026-05-10

Status: planning complete. Not gold-ready. This document is a process plan, not a certification or signoff.

Use this plan for the next implementation pass after the current MiloOS typed/spoken request-modality work is reconciled. Stop after this planning pass and notify the release owner before addressing the next gaps.

## Truth Boundary

Scholesa cannot be called blanket gold-ready until every primary role has a real, persisted, evidence-backed workflow with current security proof, native-channel proof, live canary proof, and report/Passport provenance. Validated slices such as MiloOS support, theme cleanup, raw-error hardening, and focused Flutter tests remain useful evidence, but they are not blanket Gold.

Every next change must answer these questions before code changes begin:

- Which primary role is blocked?
- Which evidence function is touched: capture, verify, interpret, or communicate?
- Which evidence-chain step is being strengthened?
- What persistence, rule, telemetry, and downstream report path proves it?
- What is the mobile/native classroom behavior?
- What exact command or canary will fail if the gap returns?

## Bottom-Up Execution Order

Work from the lowest trust boundary upward. Do not start with dashboards or cosmetic role surfaces unless they are blocking evidence trust.

| Order | Layer | Goal | Required proof before moving up |
| --- | --- | --- | --- |
| 1 | Current worktree gate | Stabilize the current MiloOS modality diff, docs, and focused tests. | Focused analyzer/tests, backend voice tests, `git diff --check`, and updated run ledger. |
| 2 | Schema, rules, and storage | Remove permissive access, missing-site fallbacks, and broad learner-media reads. | Firestore and Storage emulator denial tests for wrong role, wrong site, missing consent, and parent boundary cases. Learner-media, report-share media consent, mission/checkpoint evidence site-scope, skill/reflection/calibration site-scope, and habits site-scope slices have passed; broader collection/auth parity remains. |
| 3 | Callable/service boundaries | Keep growth, mastery, proof verification/revision, report export, and AI policy server-owned. | Mastery/growth client-write denial, AI audit site-scope, proof self-verification denial, native proof site-scope/callable verification and revision alignment, report delivery audit spoofing denial, active report-share provenance consistency, explicit-consent revocation cascade, and report-share media consent access slices passed with rules tests, 23/23 evidence-chain callable tests, 29/29 focused report Functions tests, 25/25 web report/share helper tests, 74/74 focused Flutter proof tests, source-contract Jest, and focused analyzer/build proof. Remaining report/share proof must prove live/operator behavior end to end. |
| 4 | MiloOS typed/spoken intelligence | Preserve source and modality from UI input through backend policy, telemetry, explain-back, and proof records. | Flutter request-boundary tests, backend `voiceSystem` tests, browser/mobile canary, and AI internal-only gate. |
| 5 | Evidence-chain role workflows | Close the HQ -> educator -> learner -> proof -> rubric -> growth -> portfolio -> Passport/report chain. | Canonical synthetic data plus web/Flutter/Functions/rules proof for the same evidence IDs. |
| 6 | UI/theme and recovery consistency | Ensure every role surface handles loading, empty, stale, error, unauthorized, and mobile states consistently. | Role matrix rows include THEME, EMPTY, MOBILE, A11Y-I18N, and TELEMETRY proof. |
| 7 | Native channel proof | Prove the same workflows on iOS, Android, and macOS distribution channels. | TestFlight, Google Play internal testing, macOS signing/notarization, device permission smoke. |
| 8 | Live deploy and operator cutover | Prove the exact deployed artifact with six-role canary and rollback control. | `./scripts/deploy.sh` logs, Cloud Run revision/traffic proof, live probes, role canary, rollback or traffic-pinning evidence. |
| 9 | Final signoff conversion | Convert NO-GO to GO only after every blocker above is proven. | Final signoff packet with command output, evidence IDs, native proof, security proof, and operator approval. |

## Gap Closure Loop

Apply this loop to every gap, one slice at a time.

1. Classify the gap by primary role, evidence-chain step, and bug class from `GOLD_WORKFLOW_BUG_COVERAGE_MATRIX_2026-05-10.md`.
2. Reproduce the gap with real or canonical synthetic data. Do not rely on mock-only proof.
3. Add or update the smallest failing test that represents the trust break.
4. Fix the root cause with a surgical change. Avoid broad refactors unless they remove a repeated evidence-chain failure.
5. Verify persistence, site scoping, rules, telemetry, UI state, mobile behavior, and downstream report visibility.
6. Update the active run ledger with exact commands, pass counts, and any deployed revision or emulator proof.
7. Stop if a gate fails, if the fix creates a fake workflow, or if the evidence chain cannot be explained.

## MiloOS Typed And Spoken Modeling Gates

MiloOS is support and verification provenance. It is not a mastery engine, and it must never write `capabilityMastery` or `capabilityGrowthEvents` directly.

Typed and spoken input must remain distinguishable all the way through the stack:

- Manual keyboard input maps to `inputModality: typed`.
- Speech-to-text, Web Speech, voice upload, and microphone transcripts map to `inputModality: voice`, even when the transcript is later submitted with the send button.
- Unknown source maps to a conservative fallback and must not bypass spoken-confidence guardrails.
- Backend typed learner support may provide actionable evidence/prototype scaffolding, but it cannot claim mastery.
- Backend voice or unknown student input must keep strict confidence guardrails and favor explain-back or proof-of-learning prompts.
- Telemetry and audit events must include redacted source, modality, site, learner, trace ID, and failure state where applicable.
- AI disclosure must capture prompt, suggestion, learner change, explain-back status, and proof linkage when AI materially affects learner work.
- TTS must fail gracefully when unavailable, preserve humanlike voice selection where the browser/platform allows it, and keep text interaction fully usable.

Minimum validation for any MiloOS modeling change:

```bash
cd apps/empire_flutter/app
flutter analyze --no-pub --no-fatal-infos lib/runtime/ai_coach_widget.dart lib/runtime/voice_runtime_service.dart test/ai_coach_widget_regression_test.dart test/voice_runtime_service_test.dart
flutter test test/voice_runtime_service_test.dart test/ai_coach_widget_regression_test.dart --reporter compact

cd ../../..
npm --prefix functions run test -- --runInBand src/voiceSystem.test.ts
npm run ai:internal-only:all
git diff --check
```

Broader validation before a MiloOS blanket role claim:

```bash
cd apps/empire_flutter/app
flutter test test/global_ai_assistant_overlay_regression_test.dart test/web_speech_test.dart test/ui_golden_test.dart --reporter compact

cd ../../..
npm run test:e2e:web
npm run qa:workflow:no-mock
```

## Security Hardening Gates

Security is gold-blocking until all role, site, consent, and storage boundaries are enforced by tests, not only by UI state.

Required closure order:

- Firestore rules: remove or replace permissive missing-`siteId` fallbacks with explicit collection rules and denial tests.
- Storage rules: restrict learner media reads to the owner, linked guardian, same-site educator/site/HQ, or server-mediated consent share.
- Auth parity: verify Firebase custom claims, Firestore rules, web route metadata, and Flutter role gates agree for each protected workflow.
- Parent boundary: expose parent-safe projections only; never expose raw educator support notes, internal flags, or cross-site data.
- Partner boundary: keep partner outputs consent-safe and evidence-backed; partner surfaces must not mutate school evidence directly.
- Callable validation: reject client-owned growth, mastery, report export, AI audit, and proof verification writes that bypass server policy.
- Secret hygiene: run secret scans before deploy and keep Firebase, OAuth, Stripe, GitHub, Google API, and private-key patterns covered.
- Compliance: keep compliance gate and audit posture in the release bundle when compliance surfaces are included.

2026-05-10 implementation note: the first security slice now fails closed for the shared Firestore site-scope helper, adds site scope to core portfolio/Passport/proof provenance reads and writes, and protects `portfolioMedia/{learnerId}/{fileName}` with owner, linked guardian claim, same-site staff `siteId` metadata, and HQ access. This is not the full security gate; continue with auth parity, callable boundaries, remaining site-scoped collections, report/share consent media paths, secret scan, and compliance gate.

2026-05-11 implementation note: mission/checkpoint evidence records now fail closed for missing-site and wrong-site access. `missionAttempts` and `checkpointHistory` require `siteId` for create/read/update, same-site learner/educator rules are covered in the emulator, and the native `submitMissionAttempt` helper now writes `siteId`. This reduces Passport/report provenance risk but does not complete the broader collection/auth parity sweep.

2026-05-11 follow-up implementation note: `skillEvidence`, `learnerReflections`, and `metacognitiveCalibrationRecords` now also fail closed for missing-site and wrong-site access. `habits` now also fails closed for missing-site and wrong-site access after native `HabitService` was given `activeSiteId`. The next auth-parity pass should first clean native model/write parity for showcase submissions, legacy learner goals/profiles, and skill mastery before tightening those rules.

2026-05-10 implementation note: the report audit boundary now blocks client-created `report.delivery_recorded`, `report.delivery_blocked`, and `learnerReport` audit rows in `auditLogs`, while keeping scoped site operational audit writes available. This proves report delivery audit state cannot be fabricated through client rules, but does not replace claim-by-claim Passport/report provenance, consent revocation, live canary, native-channel proof, or operator signoff.

2026-05-10 implementation note: active report-share lifecycle creation now requires evidence provenance to be required, expected, complete, and non-missing in both the web helper and `createReportShareRequest` callable path. This blocks contradictory metadata from turning weak Passport/report output into an active share, but does not replace live consent revocation, consent-media access proof, native-channel proof, or operator signoff.

2026-05-10 implementation note: explicit report-share consent revocation now cascades to linked active report-share lifecycle records and records the cascade count in the consent revocation audit. This closes the stale-share-after-revocation gap in callable logic, but still needs live/operator canary proof and consent-media access proof.

2026-05-11 implementation note: `reportShareMedia/{learnerId}/{shareRequestId}/{fileName}` is now client-write denied and readable only through an active, unexpired Firestore `reportShareRequests/{shareRequestId}` record linked to the learner and visible to the learner, linked guardian, share creator, same-site staff, or HQ. Focused Storage rules proof covers revoked, expired, missing, wrong-learner, wrong-site, unauthenticated, and client-upload denials. This closes the local consent-media rules slice, but live/operator canary proof is still required.

2026-05-10 implementation note: the Flutter native proof path now includes `siteId` on proof bundle model serialization, learner proof assembly creates, and offline proof replay. Educator proof verification and proof revision requests now route through the `verifyProofOfLearning` callable wrapper rather than direct client proof/portfolio writes. This improves native compatibility with hardened Firestore rules, but external native distribution proof and live role canaries remain required.

Minimum validation:

```bash
npm run qa:secret-scan
npm run ai:internal-only:all
npm run test:integration:rules
npm run qa:firebase-role-e2e
npm run compliance:gate
```

## Refactor And Consistency Rules

Refactor only when it strengthens evidence trust or removes repeated risk. Do not start broad cleanup while an evidence-chain or security blocker is open.

- Keep route pages thin and use the existing route metadata/workflow patterns.
- Prefer existing service, collection, theme, and telemetry helpers over new abstractions.
- Consolidate UI primitives only where repeated role surfaces share the same loading, empty, stale, error, fatal, or recovery behavior.
- Preserve role-specific meaning: Site/HQ health states, educator live-class states, learner proof states, and guardian report states should not be flattened into generic dashboard copy.
- Remove fake actions, mock-only data, misleading empty states, and raw backend errors as part of the touched workflow.
- Keep support, attendance, completion, engagement, XP, and averages separate from capability mastery.
- Do not edit generated files such as `src/dataconnect-generated/` manually.

Refactor validation:

```bash
npm run lint
npm run typecheck
npm test
cd apps/empire_flutter/app && flutter analyze --no-fatal-infos && flutter test --reporter compact
git diff --check
```

## Documentation Process

Update documentation as each gap is closed. Documentation must remain more conservative than the code until live proof exists.

- `GOLD_STABILITY_SECURITY_NEXT_STEPS_2026-05-10.md`: active status, blockers, current baseline, and exact validation ledger.
- `GOLD_WORKFLOW_BUG_COVERAGE_MATRIX_2026-05-10.md`: bug class coverage, high-risk gaps, and required next proof.
- `GOLD_EMULATED_TEST_PLAN_2026-05-10.md`: local/emulator run ledger and pass counts.
- `docs/PLATFORM_GOLD_READINESS_MASTER_PLAN_MAY_2026.md`: certification queue and current recommendation.
- `docs/PLATFORM_GOLD_READINESS_FINAL_SIGNOFF_MAY_2026.md`: final signoff evidence only after proof exists; keep historical/scoped language clear.
- Release notes or evidence logs: include route, role, evidence IDs, command output, emulator proof, native proof, deploy revision, and rollback status.

Do not update any document to say blanket Gold, production Gold, or complete unless the active exit criteria are proven in the current worktree and deployed artifact.

## Stop Conditions

Stop and notify before addressing more gaps if any of these occur:

- A security rule cannot be proven with emulator denial tests.
- A workflow only renders UI but does not persist or communicate evidence provenance.
- A report, Passport, guardian, partner, or admin claim lacks evidence IDs and missing-evidence fallback.
- A client path can write mastery, growth, proof verification, or report share state outside server policy.
- MiloOS typed/spoken modality is ambiguous or loses source provenance across UI, telemetry, backend, or proof flows.
- Native proof is local-build-only with no distribution channel evidence.
- Release docs drift into a Gold claim before live role canary, native proof, security proof, and final operator signoff exist.

## Ready-To-Address-Gaps Notification

This plan is complete when it is linked from the active stability and master readiness plans, and `git diff --check` passes. At that point, stop planning and notify the release owner that Scholesa is ready for the next implementation pass against the bottom-up gap queue.

Recommended first implementation target after notification: security hardening for Firestore missing-`siteId` and Storage learner-media access, because it sits below every role workflow and blocks any trustworthy blanket-gold claim.