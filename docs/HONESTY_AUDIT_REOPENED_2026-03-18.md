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
81. Added direct downstream educator workflow proof that a learner queued through the real `/educator/sessions` roster-import flow appears on the real `/educator/learner-supports` route after the learner is created through the real `/site/provisioning` flow, confirming the supports route consumes the same reconciled educator roster contract instead of seeded learner-only fixtures.
82. Added direct downstream educator workflow proof that a learner queued through the real `/educator/sessions` roster-import flow can submit a persisted `learner_follow_up` support request from the real `/educator/learners` route after the learner is created through the real `/site/provisioning` flow, confirming support-request evidence uses the same reconciled roster handoff instead of only seeded learner fixtures.
83. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow can submit a persisted `session_reminder` support request from the real `/parent/schedule` route once a live upcoming session is derived from the learner's active enrollment and `sessionOccurrences`, confirming parent support-request evidence now uses the same provisioning-linked family graph instead of only seeded fixtures.
84. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow can submit a persisted `portfolio_share` support request from the real `/parent/portfolio` route once the linked learner's live `portfolioItems` resolve through `ParentService`, confirming the portfolio share path also uses the same provisioning-linked family graph instead of only seeded fixtures.
85. Added direct downstream family workflow proof that a learner, parent, and guardian link created through the real `/site/provisioning` flow can submit a persisted `parent_consent_review` support request from the real `/parent/consent` route once the linked learner's live consent records resolve, confirming the consent review request path also uses the same provisioning-linked family graph instead of only seeded fixtures.
86. Added direct learner evidence workflow proof that the real `/learner/missions` route persists proof-of-learning drafts, version checkpoints, canonical `missionAttempts`, and `missionAssignments.lastSubmissionId` updates when a learner submits a completed mission for educator review, confirming learner-originated review evidence now writes through the live route instead of relying on seeded review fixtures alone.
87. Added direct educator evidence-consumption workflow proof that a canonical mission attempt created through the real `/learner/missions` submission flow appears on the real `/educator/missions/review` route and can be approved there, confirming the live educator review queue consumes learner-created `missionAttempts` instead of depending on seeded review records alone.
88. Added direct educator growth-linkage workflow proof that a rubric-scored approval submitted through the real `/educator/missions/review` page writes `rubricApplications`, updates `capabilityMastery`, emits `capabilityGrowthEvents`, links matching `evidenceRecords`, and materializes a `portfolioItems` artifact from the reviewed learner evidence, confirming the live educator route drives capability growth and portfolio linkage instead of leaving those outcomes only to service-level regression coverage.
89. Added direct learner portfolio workflow proof that a reviewed artifact created through the live `/learner/missions` submission flow and approved through the live `/educator/missions/review` page appears on the real `/learner/portfolio` route with project-card evidence linkage and capability labeling, confirming portfolio surfaces consume educator-reviewed artifacts instead of only seeded portfolio fixtures or route-local loaders.
90. Added direct parent portfolio workflow proof that a reviewed artifact created through the live `/learner/missions` submission flow and approved through the live `/educator/missions/review` page appears on the real `/parent/portfolio` route for a provisioning-linked family, with family-visible evidence linkage, proof-of-learning and AI-disclosure chips, capability metadata, verification prompt context, and exported summary metadata, confirming the parent portfolio surface consumes reviewed learner artifacts instead of only seeded family fixtures.
91. Added direct HQ analytics workflow proof that learner work created through the real `/learner/missions` route and approved through the live `/educator/missions/review` page appears in the live `/hq/analytics` supplemental top-performer aggregation, and patched the route so unfinished mission attempts no longer count as completed work on the leaderboard.
92. Verified that the Flutter learner credentials surfaces are read-only consumers today: `CredentialRepository.upsert` exists, but no in-app route or service calls it to issue credentials. The live `/learner/credentials` and learner portfolio badge views therefore render stored credentials honestly, but they do not yet complete an evidence-to-credential issuance workflow inside Flutter.
93. Added emulator-backed Firestore rules proof for `credentials`: the owning learner, educators, and HQ can read issued credentials; educators can issue them; parents cannot read them directly. Flutter still has no parent or HQ credential consumer route and no in-app issuer workflow, so the product gap is workflow completeness and family-surface scope, not whether HQ is rule-authorized to inspect stored credentials.
94. Verified that credential delivery remains partially spec-only outside Flutter: `docs/66_API_ENDPOINTS_FULL_CATALOG.md` lists `GET /v1/learners/:learnerId/credentials`, `POST /v1/credentials`, and `DELETE /v1/credentials/:id`, but no implementation was found in `src/` or `functions/src/`; likewise, `docs/SCHEMA_PORT_REPORT.md` previously pointed to a web `src/repositories/credentialRepository.ts` file that does not exist. Those surfaces are now explicitly documented as planned or deferred rather than present.
95. Clarified the dashboard-card registry so learner portfolio sharing no longer implies a parent-safe credential read path. Current family-visible proof still flows through parent-visible `portfolioItems`; raw `credentials` remain learner-, educator-, and HQ-readable by rules, with parent reads denied.
96. Corrected the broader schema-port and traceability docs to stop referring to a non-existent web `src/repositories/` layer. `docs/SCHEMA_PORT_REPORT.md` now maps implemented repository coverage to the Flutter repository file, and `docs/TRACEABILITY_MATRIX.md` no longer cites `src/repositories/userRepository.ts` for the parent dashboard slice.
97. Corrected the compliance summary to stop describing web repositories as merely pending work. The current repo has validated web routing and dashboard entry coverage, but no implemented `src/repositories/` layer; the missing web data-access surfaces are now described as a formal deferment-or-implementation decision rather than an almost-complete repo scaffold.
98. Verified that the protected web route layer is a real generic workflow system in normal runtime, not only a demo shell: `WorkflowRoutePage.tsx` mounts live route metadata from `workflowRoutes.ts` and live data loaders or mutators from `workflowData.ts`, which call Firestore and callable backends outside test mode. At the same time, the Playwright browser suite explicitly starts Next.js with `NEXT_PUBLIC_E2E_TEST_MODE=1`, so its route proofs run against `src/testing/e2e/fakeWebBackend.ts`. Web docs now distinguish browser-harness route proof from live backend proof instead of describing the Playwright suite as end-to-end data validation.
99. Corrected REQ-120 honesty drift. The repo does contain real Clever/ClassLink provider-shape code, route metadata, Flutter provider surfaces, and provider-aware identity resolution, but the district-provider workflow callables in `functions/src/workflowOps.ts` still return `stub: true` for connect, discovery, roster-sync, identity-resolution, and disconnect flows. Because `workflowData.ts` explicitly fails closed on those stub payloads, REQ-120 cannot honestly be marked complete today; traceability and proof docs now describe it as a bounded scaffold while the governance and deferment docs continue to own the live-rollout gate.
100. Corrected REQ-113 governance drift. The active execution plan and source feature contract already treat internal telemetry capture plus warehouse-friendly export as the satisfied implementation contract, so REQ-113 itself is closed under the current posture. The stale deferment and governance docs were updated to reflect that only vendor analytics exceptions remain blocked, not the requirement row itself.
101. Corrected REQ-114 rationale drift. The requirement remains deferred, but older deferment and governance wording still claimed no federated-learning code existed. Those docs now reflect the actual repo state: a bounded prototype slice with real code and focused proof exists, while production architecture approval, privacy review, and pilot-grade sign-off remain the reasons the row stays non-green.
102. Corrected the March 12 execution-plan snapshot so it no longer lists Google Classroom, enterprise SSO, LTI 1.3, or grade passback as missing or unimplemented. Those items are now reflected as evidenced integrations or dedicated shipped workstreams, while the remaining future-state district-provider item stays narrowed to Clever/ClassLink rollout beyond the governed scaffold.
103. Corrected stale analytics completion docs that still read as blanket current truth. Historical analytics milestone files now explicitly say they are implementation snapshots, not current proof that learner-growth aggregation, leaderboard evidence chains, or Passport/report evidence consumption are fully complete.
104. Corrected telemetry wiring drift in the analytics completion and telemetry spec docs. Those surfaces previously said telemetry was wired end to end without qualification; they now state the narrower truth that core mission and operational telemetry paths are wired while broader capability-growth and reporting provenance remain partial.
105. Corrected Passport/report wording drift in the gold-ready verification artifact. The workflow already admitted that growth records were not consumed end to end, but the Passport section still risked reading as if the reporting chain was complete. It now states the blocking gaps directly: no end-to-end growth-record consumption and no polished family-safe publishable Passport workflow yet.
106. Corrected BOS/MIA voice-runtime wording drift so the rewire plan no longer reads as if voice autonomy is unbounded. The doc now states explicitly that both text and voice learner help remain confidence-gated and escalate safely below the certified threshold.
107. Corrected the RC3 readiness sign-off header so it records launch-blocking engineering closure and operational honesty, not blanket gold-ready or universally complete system certification.
108. Corrected remaining stale analytics summary and telemetry-footer wording inside the historical analytics milestone docs. Those files no longer say `100%` or `wired end to end` without qualification when the current honesty gate still treats learner-growth and Passport/report evidence consumption as partial.
109. Corrected the older analytics completion report so it now reads as a December 2025 prototype-era implementation snapshot rather than current proof of comprehensive analytics and end-to-end telemetry readiness.
110. Corrected the SDT telemetry deployment guide's internal contradiction. It previously claimed `Production-ready` and `wired end to end` while separately admitting that aggregate deployment was missing and prototype shortcuts were in use; it now states the narrower historical prototype truth.
111. Corrected the RC3 launch-readiness report so its headline status is scoped to launch-blocking engineering readiness, not a blanket capability-first gold-ready claim over the entire product.
112. Corrected the blocker-remediation final status so it no longer implies all remaining work is optional while the operator-only manual browser big-bang cutover step is still explicitly pending in the handoff packet.
113. Corrected the closing summary of the RC3 launch-readiness report so its conclusion and final status now match the scoped header language instead of reverting to a blanket `PRODUCTION READY` claim at the end of the document.
114. Corrected the historical RC3 post-launch summary so its conclusion no longer reads as a current blanket `production-ready and live` certification. The closing note now preserves the original launch-snapshot meaning while explicitly deferring broader capability-first gold readiness to the stricter later gate.
115. Corrected the historical RC3 deployment-complete note so its final sign-off no longer states `Platform ready for production use` without temporal or scope qualification. It now reads as the March 3 deployment snapshot rather than competing current truth.
116. Corrected the remaining unscoped `All systems operational` and `Complete documentation` wording in the historical RC3 post-launch summary so those checklist lines now stay bounded to launch-scope truth instead of sounding like broad capability-first closure.
117. Corrected Passport/report wording drift where the gold-ready verification artifact still said `verified portfolio artifacts` even though the current chain is better described as reviewed artifacts with rubric-linked provenance when available.
118. Corrected the historical analytics completion report's SDT coverage line so the `7/9` coverage figure no longer reads like a broader learner-growth or Passport/report completeness claim.
119. Corrected live learner credential and learner portfolio badge views so they now tell the learner the honest scope of those surfaces: issued credential records are shown, but evidence, rubric, and growth links are not yet displayed in those views.
120. Corrected the last unscoped release summary lines in the March 3 deployment and RC3 sign-off artifacts so `all systems operational` and `production-ready` now stay explicitly bounded to RC3 launch-blocking scope rather than sounding like blanket capability-first certification.
121. Corrected the learner portfolio AI-coach entry copy so it now discloses that the AI reflection note is experimental and does not replace the learner's evidence record.
122. Corrected the missions progress card so XP, levels, and streaks are explicitly framed as engagement metrics, while capability growth is tied to reviewed evidence and rubric feedback.
123. Corrected parent-facing artifact counts so UI labels no longer call mixed `reviewed` plus `verified` portfolio totals simply `verified`, matching the actual parent service semantics.
124. Corrected the family summary evidence-and-growth answer block so attendance is no longer presented as part of the answer to `How are they growing?`; growth is now described with capability updates, average level, and latest growth timing while attendance remains a separate participation metric.
125. Corrected the parent portfolio AI-guidance entry copy so it now discloses that the guidance is experimental and does not replace the learner evidence record.
126. Corrected parent child detail and Passport fallback copy so those surfaces now describe currently linked evidence and reviewed artifacts rather than stronger blanket `verified artifacts` wording.
127. Reduced parent provenance collapse by threading proof-of-learning component facts and AI-disclosure component facts through the parent models, portfolio detail sheet, portfolio export, Passport cards, and Passport export instead of showing only a single collapsed enum label.
128. Corrected the family summary evidence answer so pending verification prompts are now visible directly in the evidence summary instead of remaining implicit behind a count-only next-step message.
129. Reduced parent provenance collapse further by threading reviewer attribution and rubric score context from capability growth events through the parent models, portfolio detail/export, and Passport detail/export, so family-facing surfaces can show who reviewed the work when that identity is available and what rubric score context produced the growth event.
130. Removed the remaining dependency on growth-event linkage for parent review provenance by falling back to canonical mission review fields and linked proof bundle data, so parent portfolio and Passport surfaces can still show reviewer attribution, rubric score context, learner AI assistance details, proof checkpoint counts, and short proof excerpts when a review exists without a linked growth event.
131. Removed the remaining callable-bundle drift for parent lineage by extending the parent dashboard function to emit reviewer attribution, rubric score context, proof checkpoint lists, full proof notes, learner AI assistance details, and a growth timeline, keeping the callable path aligned with the Firestore fallback instead of silently regressing family surfaces back to compressed summaries.
132. Reduced the last parent surface proof and growth collapse by exposing checkpoint-by-checkpoint proof summaries on portfolio and Passport detail views and by rendering a recent capability growth timeline on the parent summary view, so family-facing surfaces now show dated capability updates with reviewer and rubric context instead of only aggregate growth counters.
133. Reduced growth-justification collapse by storing linked evidence record IDs, linked portfolio item IDs, proof-of-learning status, proof bundle linkage, and verification prompt context directly on capability growth events during educator review, then returning those fields through the parent dashboard callable and family growth timeline so capability updates are no longer detached from the evidence and artifacts that triggered them.
134. Reduced the remaining parent proof and AI provenance collapse by storing actor metadata on proof checkpoints, threading checkpoint actor role through both fallback and callable parent bundle paths, and surfacing AI feedback author and date on portfolio and Passport detail views so families can distinguish learner-authored proof steps from educator review-time AI feedback context.
135. Reduced write-path AI provenance drift by persisting explicit `aiFeedbackBy` and `aiFeedbackAt` metadata during educator review, preferring those explicit fields in parent fallback and callable aggregation, and allowing same-attempt re-reviews to revisit already linked evidence so stale artifact-level AI feedback provenance is cleared instead of surviving after a later human-only review.
136. Corrected the remaining parent passport export wording drift by renaming mixed artifact totals from `Verified Artifacts` to `Reviewed/Verified Artifacts`, keeping downloaded and copied family exports aligned with the in-app semantics instead of overstating the review state of every linked artifact.
137. Hardened the parent child family view against honesty-driven copy growth by allowing the longer `Reviewed/Verified Artifacts` hero-stat label to wrap safely instead of overflowing the layout, so the UI no longer depends on shorter, less accurate wording to stay renderable in workflow tests or real usage.

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
- Focused educator learner supports regressions passed after the provisioning-to-supports roster proof: 11 passed, 0 failed.
- Focused educator learners, learner supports, and attendance downstream workflow regressions passed after the provisioning-to-supports roster proof: 40 passed, 0 failed.
- Focused educator learners regressions passed after the provisioning-to-follow-up support-request proof: 11 passed, 0 failed.
- Focused educator learners, learner supports, and attendance downstream workflow regressions passed after the provisioning-to-follow-up support-request proof: 41 passed, 0 failed.
- Focused parent surface workflow regressions passed after the provisioning-to-parent-schedule reminder-request proof: 14 passed, 0 failed.
- Focused parent surface workflow regressions passed after the provisioning-to-parent-portfolio share-request proof: 15 passed, 0 failed.
- Focused parent consent regressions passed after the provisioning-to-parent-consent review-request proof: 6 passed, 0 failed.
- Focused parent family workflow regressions passed after the provisioning-to-parent-consent review-request proof: 21 passed, 0 failed.
- Focused learner missions regressions passed after the canonical review submission proof: 4 passed, 0 failed.
- Focused educator mission review regressions passed after the live learner-to-educator review handoff proof: 3 passed, 0 failed.
- Focused educator mission review regressions passed after the live rubric growth-linkage proof: 4 passed, 0 failed.
- Focused educator review regressions passed after removing legacy missionSubmissions queue reads from the live review source: 19 passed, 0 failed.
- Focused mission submission and educator review regressions passed after removing new missionSubmissions mirror writes from canonical learner submissions: 24 passed, 0 failed.
- Focused HQ analytics regressions passed after the live learner-to-HQ analytics proof: 11 passed, 0 failed.
- Focused learner portfolio honesty regressions passed after the reviewed-artifact portfolio proof: 6 passed, 0 failed.
- Focused parent surface workflow regressions passed after the reviewed-artifact family portfolio proof: 16 passed, 0 failed.
- Focused parent surface workflow regressions passed after the reviewed-artifact family Passport proof: 17 passed, 0 failed.

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
