# Scholesa Feature Set End-to-End Execution Plan

Version: 2026-03-12
Owner: Platform engineering
Status: Active execution plan
Primary input: ../feature sets 2025 March 12.md
Canonical telemetry contracts: ./18_ANALYTICS_TELEMETRY_SPEC.md, ./infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md
Canonical requirement matrix: ./TRACEABILITY_MATRIX.md

## 1. Purpose

This document turns the March 12 feature set into an execution program that can be implemented, verified, and audited end to end.

It exists because the source feature file mixes three different categories:

1. Shipped platform capabilities already evidenced in code, tests, and live deployment.
2. Partial capabilities that have schema, rules, or UI scaffolding but are not yet fully wired.
3. Future-state or optional capabilities that are not implemented and must not be treated as release-complete.

The goal is to close real product gaps without overstating coverage, while preserving compliance, tenant isolation, and COPPA-safe telemetry.

## 2. End-to-End Definition Of Done

A feature is only considered end to end when all of the following are true:

1. Product behavior exists in user-facing UI or API flows.
2. Data model and authorization are implemented, including site scoping and auditability.
3. Telemetry is emitted with the canonical privacy-safe contract.
4. Tests exist at the right layer: unit, integration, E2E, or runtime audit.
5. i18n coverage exists for en, zh-CN, and zh-TW. Add th only where the runtime contract already requires it.
6. Accessibility and degraded-mode behavior are explicitly validated where applicable.
7. Operational runbooks and traceability references are updated.

If any of these are missing, the feature remains partial.

## 3. Current Status Snapshot

### 3.1 Shipped or strongly evidenced

- Mission engine, portfolio system, role routing, site-scoped authorization, attendance, audit logs, and core dashboard slices.
- Learner-facing runtime confidence gate at 0.97 with escalation behavior.
- MVL-related explain-back enforcement evidence in runtime and rules.
- Core telemetry baseline, trace correlation, privacy-safe logging, and compliance runtime audit automation.
- Google/Firebase auth baseline, PWA deployment path, tri-locale web coverage, and Flutter role dashboards.

### 3.2 Partial and requiring completion

- Onboarding diagnostics and learner profile calibration.
- Interleaving implementation beyond content structure.
- Accessibility completeness, especially keyboard-only, drag alternatives, and formal WCAG gate automation.
- Educator authoring, rubric-driven grading, messaging, analytics dashboards, and selected operations modules.
- Google Classroom and GitHub integration surfaces with incomplete backend wiring.

### 3.3 Missing or explicitly future-state

- LTI 1.3, grade passback, Clever/ClassLink sync, and enterprise SAML/OIDC.
- SEP-based hallucination detection and a true keystroke/pointer FDM implementation.
- Federated learning and gradient aggregation infrastructure.
- Full live session mode with polls, cold-calls, exit tickets, and misconception alerting.

## 4. Blockers And Contract Corrections

These blockers must be resolved at the planning layer before implementation claims are made.

| Blocker | Why it blocks end-to-end status | Resolution |
| --- | --- | --- |
| Source feature file mixes shipped and future-state items | Causes false confidence and unclear release scope | Every item in the March 12 file must be marked as `shipped`, `partial`, `planned`, or `deferred` in traceability updates |
| PostHog/Segment listed in feature spec | Current compliance posture bans ad-tech style vendor analytics paths | Treat vendor capture as not approved. Use internal telemetry pipeline plus BigQuery-compatible export only |
| SAML/OIDC listed as baseline security | Current codebase supports Firebase auth baseline, not enterprise SSO parity | Split into a dedicated enterprise auth workstream with separate acceptance gates |
| Federated learning listed as moat | No implementation, infrastructure, or compliance review exists | Reclassify as R and D until architecture, privacy review, and device-runtime plan exist |
| WCAG 2.2 AA stated as global fact | Current repo has accessibility intent but not full automated enforcement | Add automated accessibility gates before claiming compliance completeness |
| Optional live session mode listed inside core educator features | Optional items cannot be counted toward mandatory release completion | Keep as a separate workstream, not a blocker for core platform completion |

## 5. Execution Phases

## Phase 0. Contract alignment and traceability

Objective: make the feature contract auditable.

Required actions:

- Add March 12 feature rows into the canonical traceability matrix with explicit status labels.
- Normalize each requirement into one owner, one implementation surface, one verification method, and one telemetry contract.
- Mark non-shipped items as planned or deferred instead of leaving them implied.

Exit criteria:

- No feature in the March 12 file remains unclassified.
- Traceability rows reference code, tests, docs, or a deferred decision.

## Phase 1. Learner core loop completion

Objective: complete the learner loop promised by the feature set.

Work items:

| Area | Current gap | Required implementation |
| --- | --- | --- |
| Onboarding | Reading level, interests, accommodations, and diagnostic are not fully wired as one flow | Build a unified onboarding flow that persists learner preferences, accommodation flags, interests, diagnostic results, and initial mastery priors |
| Goals and reminders | Goal and reminder planning is not fully surfaced | Add learner goal configuration, reminder cadence, and value-prompt capture with persistence and notification hooks |
| FSRS | Baseline evidence exists, but UX contract is broader than current evidence | Expose daily review queue, Again/Hard/Good/Easy scoring, snooze, suspend, and reschedule with telemetry |
| Interleaving | Confusability matrix logic is not fully implemented | Add content tagging, confusability scoring, mode toggle, and scheduler selection logic |
| Worked examples | Fading exists in concept, not fully enforced as a product contract | Add worked-example injection rules, fade progression, and decay after sustained correctness |
| Reflection | Reflection telemetry exists, but the full card flow is incomplete | Add pre-plan, post-session, and weekly review cards tied to progression and analytics |
| Motivation | Autonomy choices and competence signals are partial | Wire autonomy-next-path selection, shout-outs, and value-linked messaging into learner flows |
| Accessibility | Controls are not complete or formally verified | Add settings surfaces for reduced distraction, reading level, TTS, contrast, and keyboard alternatives |

Exit criteria:

- A learner can onboard, study, reflect, and review with persisted state, telemetry, and test coverage.
- No learner loop step requires undocumented manual fallback.

## Phase 2. Educator creation and classroom operations

Objective: complete the educator workflows promised by the feature set.

Work items:

| Area | Current gap | Required implementation |
| --- | --- | --- |
| Class management | Create and join patterns are partial, CSV and role depth incomplete | Implement class creation, invite or join codes, roster CSV ingestion, and teacher/co-teacher/aide role assignments |
| Lesson builder | Evidence-default sequencing is not complete | Add lesson builder pipeline for worked, faded, practice, retrieval checkpoint, and interleaving slot generation |
| Content authoring | Misconception tagging and approvals are not fully productized | Build authoring templates, difficulty estimation capture, versioning, media, and approval workflow |
| Assignments and grading | Rubric and AI feedback paths are partial | Complete assignment publish, due-window management, retry policy, editable AI feedback suggestions, and rubric evaluation |
| Differentiation | Policy evidence exists; educator controls need parity | Surface lane assignment, teacher override, printable practice export, and telemetry |
| Live session mode | Optional feature absent | Treat as optional phase deliverable with polls, exit tickets, pacing, and misconception alerting only after core flows are complete |
| School ops | Timetable, kit checklist, and safety note parity incomplete | Complete sessions, attendance, timetable, kit checklist, and safety note modules with role-scoped access |

Exit criteria:

- Educators can create, assign, monitor, and operate classes without leaving the platform.
- Every privileged write is site-scoped and audit-logged.

## Phase 3. AI safety and integrity hardening

Objective: turn BOS and MIA safety claims into verifiable runtime behavior.

Work items:

| Area | Current gap | Required implementation |
| --- | --- | --- |
| Learner-facing confidence guard | Present, but traceability should be made explicit | Preserve 0.97 floor and add test evidence for all fallback paths |
| MVL | Explain-back exists, broader proof-of-learning loop incomplete | Add explain-back completion state, oral-check alternative flows where allowed, and progression gates |
| Autonomy risk | Signals exist, but self-explanation follow-through needs fuller product wiring | Add risk triggers, learner self-explanation prompts, educator visibility, and telemetry |
| SEP | No production implementation found | Either implement semantic-entropy verification logic or downgrade the feature to planned |
| FDM | No keystroke or pointer affect model found | Either implement a privacy-reviewed affect model or downgrade the feature to planned |
| Tutor policies | Hint-first and content grounding need stronger acceptance tests | Add policy tests for nudge-first, no answer dumping, profanity and PII masking, and rationale logging |
| Moderation | Blocklist and allowlist are described but need explicit E2E proof | Add organization-level moderation configuration, escalation trails, and evidence tests |

Exit criteria:

- All safety claims in product copy have executable or auditable proof.
- Any unimplemented claim is downgraded in source docs before release.

## Phase 4. Data, telemetry, compliance, and accessibility enforcement

Objective: make telemetry and audit evidence complete enough to support confidence claims.

Work items:

| Area | Current gap | Required implementation |
| --- | --- | --- |
| Telemetry coverage | Baseline exists, but March 12 feature set needs explicit event coverage | Add feature-level event map for onboarding, FSRS, interleaving, reflections, authoring, grading, integrations, and guardrails |
| Privacy schema | Must remain COPPA-safe while expanding coverage | Enforce no PII, no raw prompts, no transcripts, siteId and role tagging, appVersion, locale, traceId continuity |
| Longitudinal metacognition data | Product claim is broader than current proof | Persist confidence-alignment and verification outcomes in analytics-safe records |
| Data exports | BigQuery-compatible sink exists conceptually, vendor analytics conflict remains | Keep internal pipeline as source of truth; implement export adapters only after privacy review |
| WCAG 2.2 AA | No automated gate proving compliance completeness | Add CI or audit jobs for focus order, focus visibility, target size, reduced motion, keyboard traps, and drag alternatives |
| Compliance docs | Need explicit mapping to shipped behavior | Update compliance and audit runbooks whenever feature-level telemetry or retention rules change |

Exit criteria:

- Feature coverage and telemetry coverage match.
- CI can fail on privacy, trace continuity, and accessibility blockers.

## Phase 5. Enterprise auth and external integrations

Objective: deliver only the integrations that can be safely supported and verified.

Work items:

| Area | Current gap | Required implementation |
| --- | --- | --- |
| Google Classroom | Partial surface, incomplete backend wiring | Finish OAuth, sync jobs, course mapping, submission sync, and educator/admin controls |
| SAML and OIDC | Not implemented as enterprise auth parity | Implement identity provider configuration, role mapping, JIT provisioning, logout, and audit trails |
| LTI 1.3 | No implementation found | Build launch, deep linking, roster or line item handling, and assignment return workflows |
| Grade passback | Not implemented | Add grade sync contract and retry-safe export jobs with audit logs |
| SIS CSV | Mentioned but not complete | Implement robust import validation, preview, error reporting, and audit evidence |
| Clever and ClassLink | Planned only | Keep deferred unless a full integration charter is approved |

Exit criteria:

- Every supported integration has auth, sync, telemetry, audit, and failure-handling coverage.
- Unsupported integrations are clearly documented as deferred.

## 6. Telemetry Wiring Contract For March 12 Features

The following event families must be present before the feature set can be called end to end.

### 6.1 Existing canonical baseline

- auth.login
- auth.logout
- attendance.recorded
- mission.attempt.submitted
- message.sent
- order.paid
- cms.page.viewed
- popup.shown
- popup.dismissed
- popup.completed
- nudge.snoozed
- insight.viewed
- support.applied
- support.outcome.logged
- voice.transcribe
- voice.message
- voice.tts

### 6.2 Required additions for March 12 execution

| Event | Required when | Minimum dimensions |
| --- | --- | --- |
| onboarding.started | Learner begins first-run flow | traceId, siteId, role, locale, appVersion |
| onboarding.completed | Learner completes setup | traceId, siteId, role, locale, accommodationFlags, interestCount |
| diagnostic.submitted | Initial mastery calibration is recorded | traceId, siteId, role, skillBankId, itemCount, scoreBand |
| learner.goal.updated | Minutes or reminder targets change | traceId, siteId, role, reminderEnabled |
| fsrs.review.rated | Learner selects Again, Hard, Good, or Easy | traceId, siteId, role, itemType, rating |
| fsrs.queue.snoozed | Learner snoozes queue items | traceId, siteId, role, itemCount |
| fsrs.queue.rescheduled | Bulk or manual reschedule occurs | traceId, siteId, role, itemCount |
| interleaving.mode.changed | Learner switches Focus only or Mixed | traceId, siteId, role, mode |
| worked_example.shown | Worked example injected by engine | traceId, siteId, role, triggerTag, fadeStage |
| reflection.submitted | Pre-plan, post-session, or weekly review completed | traceId, siteId, role, reflectionType |
| accessibility.setting.changed | Accessibility preference updated | traceId, siteId, role, settingKey |
| class.created | Educator creates class | traceId, siteId, role |
| class.join_code.created | Join code generated | traceId, siteId, role |
| roster.import.completed | CSV or external roster import succeeds | traceId, siteId, role, importedCount, rejectedCount |
| lesson.builder.saved | Lesson draft or publish saved | traceId, siteId, role, lessonStageCount |
| assignment.published | Assignment becomes learner-visible | traceId, siteId, role, targetCount |
| grading.feedback.applied | Educator applies or edits AI feedback | traceId, siteId, role, rubricAttached |
| live_session.started | Optional live mode begins | traceId, siteId, role, classId |
| ai.guard.escalated | Learner response falls below confidence or policy threshold | traceId, siteId, role, escalationType |
| mvl.required | Explain-back required for progression | traceId, siteId, role, triggerReason |
| mvl.completed | Explain-back completed | traceId, siteId, role, outcome |
| autonomy_risk.detected | Offloading or shortcut behavior detected | traceId, siteId, role, signalType |
| sep.verify.prompted | SEP verification prompt triggered | traceId, siteId, role, entropyBand |
| moderation.escalated | Teacher or org moderation review triggered | traceId, siteId, role, category |
| integration.sync.started | Any external sync job starts | traceId, siteId, role, integrationType |
| integration.sync.completed | Sync job ends | traceId, siteId, role, integrationType, outcome |
| auth.sso.login | Enterprise SSO login succeeds | traceId, siteId, role, providerType |
| grade.passback.sent | External grade export attempted | traceId, siteId, role, integrationType, outcome |

### 6.3 Telemetry privacy rules

These remain non-negotiable:

- No names, emails, message bodies, raw prompts, raw transcripts, or audio bytes.
- Include siteId, role, locale, appVersion, traceId, and environment wherever technically feasible.
- Preserve cross-service trace continuity for guarded AI flows.
- Keep analytics internal-first. Do not add vendor analytics SDKs that violate the current compliance posture.

## 7. Verification Matrix

Each workstream must provide the following evidence before status changes from partial to complete.

| Layer | Evidence required |
| --- | --- |
| Unit | scheduling logic, policy logic, telemetry payload validation, permission guards |
| Integration | repository writes, Firestore rules, auth mapping, sync jobs, escalation flows |
| E2E | learner journey, educator journey, protected route behavior, integration happy path and failure path |
| Runtime audit | telemetry schema validation, trace continuity, tenant isolation, compliance smoke checks |
| Accessibility | keyboard navigation, drag alternatives, focus visibility, reduced motion, target size |
| Localization | en, zh-CN, zh-TW coverage for user-facing surfaces and prompts |

## 8. Immediate Priority Order

Implement in this order unless a release-critical blocker overrides it:

1. Phase 0 traceability alignment.
2. Phase 1 learner core loop gaps.
3. Phase 4 telemetry and accessibility enforcement for newly completed learner flows.
4. Phase 2 educator core workflow gaps.
5. Phase 3 safety hardening where claims already exist in product copy.
6. Phase 5 integrations and enterprise auth.

## 9. Acceptance Rules For Release Claims

Before claiming that the March 12 feature set is fully end to end, all of the following must be true:

1. No item in the source feature file is still implicitly assumed.
2. Every shipped item has code, authorization, telemetry, and tests.
3. Every partial item has an active implementation owner and gap list.
4. Every planned item is explicitly labeled planned or deferred in traceability and user-facing docs.
5. Compliance and telemetry audit jobs pass with no blocker violations.

## 10. Next Document Updates Required

After using this plan, update these sources in lockstep:

1. ./TRACEABILITY_MATRIX.md and ./docs/TRACEABILITY_MATRIX.md
2. ./18_ANALYTICS_TELEMETRY_SPEC.md
3. ./infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md
4. Any release-readiness or compliance report that claims feature completeness
