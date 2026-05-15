# Native Small-Screen UX Rethink - Phase 2 - May 15 2026

Status: design and implementation plan for Flutter native app refinement.

The native app should feel like Scholesa in a small-screen studio setting, not like a compressed web dashboard. Phase 2 focuses on fast evidence capture, readable learner progress, Family trust, and safe MiloOS Coach support on phone-width screens.

## Product Principle

Native screens must protect the same chain as web:

`capability -> mission -> session -> checkpoint -> evidence -> reflection -> capability review -> portfolio -> badge -> showcase -> growth report`

The app must help an Educator act in under 10 seconds during a live session and help a Learner submit or explain evidence without hunting through dense dashboards.

## Current Native Distribution Status

| Channel | Current state |
| --- | --- |
| iOS | TestFlight build `5` for `com.scholesa.app` is visible and `processing_state=VALID`. |
| Android | Local distribution readiness passed in the May 15 aggregate gate. |
| macOS | Distribution readiness is blocked by Developer ID keychain access: `errSecInternalComponent`. Notarization proof must be rerun after keychain repair. |

## Phase 2 UX Goals

| Goal | Required outcome |
| --- | --- |
| One-thumb navigation | Primary Learner, Educator, Family, site, and MiloOS Coach actions are reachable from thumb-safe bottom actions or clear top-level cards. |
| Evidence-first screens | Each screen starts with what the user can do now, then shows evidence/provenance details. |
| Small-screen readability | No horizontal overflow at 390px or 430px logical widths; long capability names and evidence titles wrap cleanly. |
| Live-session speed | Educator capture path supports tap, select learner/cohort/session, capture note/artifact, and save without admin cleanup. |
| Family trust | Family surfaces show evidence provenance and clear empty states instead of unsupported claims. |
| MiloOS safety | MiloOS Coach makes support/disclosure clear and never presents AI output as capability mastery. |
| Offline honesty | Offline capture queues evidence or proof bundles but does not directly write server-owned growth/mastery records. |

## Target Native Information Architecture

| Role | Home screen focus | Primary mobile actions |
| --- | --- | --- |
| Learner | Today, active Mission, next checkpoint, Portfolio proof | Submit artifact, record reflection, explain back, open MiloOS Coach, view Portfolio. |
| Educator | Live session roster and quick evidence capture | Log evidence, request reflection, open proof queue, apply capability review, message Family when appropriate. |
| Family | Evidence-backed progress and upcoming session context | View Growth Report, view Portfolio artifact, review Home Connection, contact site. |
| Site | Evidence health and operating exceptions | Check cohort readiness, view coverage gaps, resolve incidents, review session health. |
| HQ | Capability framework and rollout health | Review framework coverage, site evidence health, rubric adoption, safety/compliance signals. |
| Partner | Deliverables and evidence-facing commitments | Review contract deliverables, submit evidence URL, monitor accepted/revision-requested status. |

## Native Layout Patterns

| Pattern | Use for | Requirements |
| --- | --- | --- |
| Role home rail | Native home screen after sign-in | 3 to 5 role-relevant destinations; no nested card stacks. |
| Bottom action dock | Repeated live actions | Icon plus short label, 44px minimum target, safe-area aware. |
| Evidence timeline item | Portfolio, Growth Report, Family views | Shows artifact/reflection/reviewer/provenance in compact rows. |
| Live capture sheet | Educator quick evidence | Opens over current session, preserves context, saves in under 10 seconds. |
| Checkpoint card | Learner missions and sessions | Stable height, readable title, action button, offline status. |
| MiloOS Coach sheet | Support and explain-back | Discloses AI support, records modality, shows next step and explain-back prompt. |
| Empty evidence state | Missing Portfolio/Growth Report data | Says no evidence exists yet and gives next evidence action; does not make learner claims. |

## Screen-Level Refactor Backlog

| Priority | Screen family | UX change | Required proof |
| --- | --- | --- | --- |
| P0 | Login and onboarding | Keep email login simple, make role destination clear, preserve direct `/login` behavior on web. | Existing public entry tests plus native login smoke. |
| P0 | Learner Today | Convert to action-first layout: active Mission, next checkpoint, evidence action, MiloOS Coach. | 390px and 430px widget tests, no overflow. |
| P0 | Educator Today | Add live session capture sheet and pinned roster context. | Under-10-second capture test and persistence proof. |
| P0 | Evidence capture | Streamline learner/cohort/session context, note, capability tag, save. | Same-site write test and wrong-site denial. |
| P1 | Proof Review | Mobile queue with status chips, revision request action, and evidence preview. | Same-site queue test and revision persistence. |
| P1 | Learner Portfolio | Show reviewed proof with artifact, reflection, capability, reviewer, AI disclosure. | Portfolio provenance test. |
| P1 | Family Growth Report | Evidence-backed growth timeline with missing-evidence fallback. | Linked learner only; unrelated learner denied. |
| P1 | MiloOS Coach | Use bottom sheet, typed/spoken modality, explain-back recovery. | Modality serialization and no-mastery-write tests. |
| P2 | Site Evidence Health | Compact coverage dashboard with tap-through gaps. | Site-scope read and mobile overflow tests. |
| P2 | Partner Deliverables | Mobile deliverable status and evidence URL submission. | Partner-owned contract/deliverable proof. |

## Visual Design Language

- Use restrained Scholesa public colors: navy, teal, gold, coral accents, and white/cream surfaces.
- Keep cards at 8px radius or less.
- Use icon buttons for recurring tools and text buttons only for clear commands.
- Avoid marketing hero treatment inside native app workflows.
- Prefer compact section headers, stable action bars, and dense but readable evidence rows.
- Use capability color chips sparingly so screens do not become one-hue dashboards.

## Accessibility And Safety Requirements

- Every tappable target must be at least 44px high.
- Text must wrap within its container at 390px width.
- Screens must support dynamic text up to at least a large accessibility preset without hiding the primary action.
- Voice and microphone access must be opt-in and must show why the permission is requested.
- MiloOS Coach output must remain support, not a substitute for learner understanding.
- Family and partner views must never expose unrelated learner evidence.

## Phase 2 Implementation Order

1. Add a native responsive shell contract: safe-area bottom dock, top context bar, and role-aware primary action slot.
2. Refactor Learner Today into action-first sections and add 390px/430px tests.
3. Refactor Educator Today and observation capture into a live capture sheet.
4. Refactor Family Growth Report and Portfolio proof rows around evidence provenance.
5. Move MiloOS Coach to a native bottom sheet pattern and preserve explain-back/disclosure telemetry.
6. Run full Flutter analyzer/test gate, then native distribution readiness.

## Acceptance Gates

```bash
cd apps/empire_flutter/app
flutter analyze
flutter test test/learner_today_page_test.dart test/educator_today_page_test.dart test/observation_capture_page_test.dart
flutter test test/parent_surfaces_workflow_test.dart test/proof_assembly_page_test.dart test/ai_coach_widget_regression_test.dart
```

Before a native-channel Gold claim:

```bash
npm run native:distribution:readiness
SCHOLESA_NATIVE_DISTRIBUTION_CONFIRM=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS bash scripts/native_distribution_proof.sh execute-live
```

Do not run the guarded live native proof command until the release owner explicitly authorizes uploads and macOS notarization credentials are working.