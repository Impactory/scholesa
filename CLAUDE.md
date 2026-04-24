# CLAUDE.md — Scholesa Platform

## Product Identity

Scholesa is a **capability-first evidence platform** for K-12 schools and learning studios. It is NOT a marks-first LMS or a percentage-first gradebook. Students are evaluated by what they can do, explain, improve, and demonstrate over time.

Every system, route, schema, and workflow must support one or more of these functions:
1. **Capture** evidence
2. **Verify** evidence
3. **Interpret** evidence into capability growth
4. **Communicate** evidence through trustworthy outputs

## Critical Evidence Chain

```
Admin-HQ setup (frameworks, rubrics, checkpoints, progressions)
  -> Session runtime
    -> Educator observation
      -> Learner artifact / reflection / checkpoint
        -> Proof-of-learning verification
          -> Rubric / capability mapping
            -> Capability growth update
              -> Portfolio linkage
                -> Passport / reporting output
                  -> Guardian / school / partner interpretation
```

If this chain is broken, the platform is not ready.

## Monorepo Structure

- **Next.js web app** (App Router, locale-first, 69 routes) — `app/`, `src/`
- **Flutter mobile/desktop client** (WASM web, iOS, Android, macOS) — `apps/empire_flutter/app/`
- **Firebase Functions v2 backend** — `functions/`
- **Compliance operator service** — `services/scholesa-compliance/`
- **Shared packages** — `packages/i18n/` (5 locales), `packages/safety/`

## Quick Reference

```bash
# Web development
npm run dev              # Next.js dev server
npm run build            # Production build
npm run lint             # ESLint
npm run lint:fix         # ESLint autofix
npm run typecheck        # TypeScript type check
npm test                 # Jest unit tests (--runInBand)

# Functions backend
npm --prefix functions run build    # Compile functions
npm --prefix functions run test     # Run function tests

# Flutter
cd apps/empire_flutter/app && flutter run
cd apps/empire_flutter/app && flutter test
cd apps/empire_flutter/app && flutter analyze

# E2E & integration
npm run test:e2e:web                 # Playwright E2E
npm run test:e2e:web:wcag            # WCAG 2.2 AA accessibility tests
npm run test:integration:rules       # Firestore rules (requires emulator)

# Quality gates
npm run compliance:gate              # Full compliance check
npm run qa:vibe-telemetry:blockers   # Telemetry blockers
npm run flow:platform:gates          # Full platform gates (no deploy)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Web framework | Next.js 16 (App Router, Webpack) |
| UI | React 18, Tailwind CSS 3, HeadlessUI, Framer Motion |
| Language | TypeScript 5.5 (strict mode) |
| Backend | Firebase Functions v2, Node.js 24 |
| Database | Firestore with RBAC rules |
| Auth | Firebase Auth with custom role claims |
| Mobile | Flutter (stable), Isar offline DB |
| Testing | Jest, Playwright, Axe Core (a11y) |
| CI/CD | GitHub Actions |
| Hosting | Google Cloud Run + Firebase |
| i18n | 5 locales: en, es, th, zh-CN, zh-TW |

## Primary Roles

| Role | Purpose |
|------|---------|
| `hq` (Admin-HQ) | Defines capability frameworks, rubrics, checkpoints, progression descriptors; manages academic structure |
| `site` (Admin-School) | Manages school-level config, educators, classes, implementation quality |
| `educator` | Runs sessions, logs observations, reviews evidence, applies rubric judgments, verifies proof-of-learning |
| `learner` | Creates artifacts, submits reflections, completes checkpoints, discloses AI use, builds portfolio |
| `parent` (Guardian) | Views progress summaries, understands capability growth with evidence |
| `partner` | External review, marketplace, contracts; sees only evidence-backed, permission-safe outputs |

Role type definition: `src/types/user.ts` — `UserRole = 'learner' | 'parent' | 'educator' | 'hq' | 'siteLead' | 'partner'`
Role aliases and normalization: `src/lib/auth/roleAliases.ts`

## Directory Structure

```
app/[locale]/              # Locale-parameterized web routes
  (auth)/                  # Authentication flows
  (protected)/             # Role-gated pages (thin wrappers -> WorkflowRoutePage)
  api/                     # API routes
src/
  features/                # Feature modules (workflows, auth, dashboards, navigation)
    workflows/
      WorkflowRoutePage.tsx  # Generic workflow renderer (all routes)
      workflowData.ts        # Data loading, create, update, delete per route
  components/              # React components by domain
  lib/
    routing/
      workflowRoutes.ts    # Route definitions, role access, nav groups
    auth/                  # Auth utilities
    firestore/             # Firestore integration
    telemetry/             # Analytics & telemetry
    ai/                    # AI services (internal only, no external providers)
    voice/                 # Voice system
    i18n/                  # Internationalization
    policies/              # Policy enforcement
  hooks/                   # Custom React hooks
  types/
    schema.ts              # All Firestore document types (evidence chain types here)
    user.ts                # UserRole, UserProfile
  dataconnect-generated/   # Generated Data Connect clients (do not edit)
functions/src/             # Firebase Functions backend
  index.ts                 # Function exports + AI coach + BOS scoring
  workflowOps.ts           # Workflow & admin callables
  bosRuntime.ts            # BOS runtime surface (orchestration, intervention, scoring)
  voiceSystem.ts           # Voice handlers (TTS/STT/coach)
  aiCoachExplainBack.ts    # Explain-it-back verification
  coppaOps.ts              # COPPA compliance operations
apps/empire_flutter/app/   # Flutter client
  lib/router/              # Single route registry
  lib/dashboards/          # Role-based dashboards
  lib/modules/             # Feature pages by domain
  lib/offline/             # Offline queue & sync
  lib/runtime/             # MiloOS orchestration, MIA, AI surfaces
  lib/i18n/                # Learning signal i18n (EN, zh-CN, zh-TW)
services/scholesa-compliance/  # Compliance operator service
packages/                  # Shared packages (i18n, safety)
scripts/                   # QA, release, and audit tooling
locales/                   # i18n JSON files (en, es, th, zh-CN, zh-TW)
docs/                      # Architecture & requirement docs
test/                      # Root Jest & Playwright E2E tests
```

## Workflow Route Architecture

All 46 protected web routes are defined in `src/lib/routing/workflowRoutes.ts` as `WorkflowRouteDefinition` objects with `path`, `allowedRoles`, `navGroup`, and `dataMode` (firestore | callable | hybrid).

Route pages in `app/[locale]/(protected)/` are thin wrappers:
```tsx
import { WorkflowRoutePage } from '@/src/features/workflows/WorkflowRoutePage';
export default function Page() {
  return <WorkflowRoutePage routePath='/learner/today' />;
}
```

All data loading and CRUD is handled generically by `WorkflowRoutePage` + `workflowData.ts`. Operational routes (messaging, billing, incidents, provisioning) render through the generic record-list UI with title/subtitle/status/metadata cards. Evidence-chain routes dispatch through `src/features/workflows/customRouteRenderers.tsx` to **dedicated domain renderers** in `src/features/workflows/renderers/` — covering capability framework authoring, rubric building/applying, educator evidence capture and review, proof-of-learning assembly, learner portfolio curation, progress reports, guardian capability views, passport export, and implementation health. Adding a new evidence-chain surface means building a renderer there, not extending the generic card UI.

### Routes by Role

**Learner** (4): `/learner/today`, `/learner/missions`, `/learner/habits`, `/learner/portfolio`
**Educator** (8): `/educator/today`, `/educator/attendance`, `/educator/sessions`, `/educator/learners`, `/educator/missions/review`, `/educator/mission-plans`, `/educator/learner-supports`, `/educator/integrations`
**Parent** (4): `/parent/summary`, `/parent/billing`, `/parent/schedule`, `/parent/portfolio`
**Site** (10): `/site/checkin`, `/site/provisioning`, `/site/dashboard`, `/site/sessions`, `/site/ops`, `/site/incidents`, `/site/identity`, `/site/clever`, `/site/integrations-health`, `/site/billing`
**Partner** (5): `/partner/listings`, `/partner/contracts`, `/partner/deliverables`, `/partner/integrations`, `/partner/payouts`
**HQ** (11): `/hq/user-admin`, `/hq/role-switcher`, `/hq/sites`, `/hq/analytics`, `/hq/billing`, `/hq/approvals`, `/hq/audit`, `/hq/safety`, `/hq/integrations-health`, `/hq/curriculum`, `/hq/feature-flags`
**Common** (4): `/messages`, `/notifications`, `/profile`, `/settings`

## Curriculum Architecture v1 (canonical)

Scholesa is a **K-12 future-readiness operating system**. The curriculum master (`docs/Scholesa_Curriculum_Architecture_Master_v1.pdf`, April 2026) is translated into live repo contracts — all new curriculum, rubric, and analytics work must start here, not from legacy pillar vocabulary.

- **Six strands**: Think · Make · Communicate · Lead · Navigate AI · Build for the World
- **Four stages**: Discoverers (1–3, teacher-led AI) · Builders (4–6, guided assistive) · Explorers (7–9, analytical/critique) · Innovators (10–12, audited advanced use)
- **Annual cycle**: Understand → Design → Test → Showcase
- **Lesson moves (non-negotiable)**: Hook · Micro-skill · Build sprint · Checkpoint · Share-out · Reflection
- **Five proof layers**: Process · Product · Thinking · Improvement · Integrity — no major task may be scored on final artifact alone
- **Three portfolio views**: Timeline · Capability · Best-work showcase

Canonical code sources:

| File | Purpose |
|------|---------|
| `src/lib/curriculum/architecture.ts` | TS contract: strands, stages, cycles, moves, proof layers, portfolio views, `LEGACY_PILLAR_ALIGNMENT` |
| `src/lib/policies/aiPolicyTierGate.ts` | Stage-aware AI governance |
| `src/lib/policies/gradeBandPolicy.ts` | Grade-band product behavior |
| `config/curriculum_display.json` | Shared display source (regenerate via `npm run generate:curriculum-display`) |
| `functions/src/curriculumDisplay.generated.ts` | Generated backend mirror |
| `apps/empire_flutter/app/lib/domain/curriculum/curriculum_display.g.dart` | Generated Flutter mirror |
| `docs/76_CURRICULUM_ARCHITECTURE_ALIGNMENT.md` | Master-doc → repo alignment |
| `docs/45_CURRICULUM_VERSIONING_RUBRICS_SPEC.md` | Versioning + rubrics spec |
| `src/__tests__/curriculum-architecture-contract.test.ts` | Contract tests |

**Legacy compatibility**: the three-pillar model (`FUTURE_SKILLS` / `LEADERSHIP_AGENCY` / `IMPACT_INNOVATION`) still appears in storage, analytics aggregates, and some read models. Treat it as a compatibility roll-up of the canonical six strands, resolved through `LEGACY_PILLAR_ALIGNMENT`. New product copy says **K-12** and names strands/stages directly — never "3 Pillars" or "K-9".

## Evidence Chain — Schema Types (src/types/schema.ts)

These types model the evidence chain in Firestore:

| Type | Collection | Purpose | Evidence Chain Step |
|------|-----------|---------|-------------------|
| `Mission` | `missions` | Learning tasks with pillar codes | Admin-HQ setup |
| `MissionVariant` | N/A (type exists) | Difficulty-differentiated missions | Admin-HQ setup |
| `MicroSkill` | N/A (type exists) | Granular skill definitions with rubric levels | Framework setup |
| `Checkpoint` | `checkpointHistory` | Fast feedback points with explain-it-back | Evidence capture |
| `MissionAttempt` | `missionAttempts` | Learner mission submissions | Evidence capture |
| `ReflectionEntry` | `reflections` / `learnerReflections` | Learner metacognitive reflections | Evidence capture |
| `SkillEvidence` | `skillEvidence` (no Firestore rule) | Evidence submissions linked to micro-skills | Evidence capture |
| `AICoachInteraction` | N/A (type exists) | AI help log with explain-it-back guardrails | Evidence capture |
| `PortfolioItem` | `portfolioItems` | Portfolio artifacts with capability/proof linkage | Portfolio |
| `ShowcaseSubmission` | `showcaseSubmissions` | Public showcase of learner work | Portfolio |
| `Badge` / `BadgeAward` | `recognitionBadges` | Evidence-based badge awards | Growth recognition |
| `ParentSnapshot` | N/A (type exists) | Weekly family-friendly summary | Communication |
| `PeerFeedback` | `peerFeedback` | Structured peer review | Evidence capture |
| `WeeklyGoal` | N/A (type exists) | Learner goal-setting | Growth |
| `MotivationAnalytics` | N/A (type exists) | Proof-of-learning rate, checkpoint pass rate | Interpretation |

Key Firestore collections for evidence chain:
- `capabilities` — HQ-only write, all read
- `rubrics` — Educator write, all read
- `rubricApplications` — Educator write, learner/educator read
- `evidenceRecords` — Educator write, owner/parent read (site-scoped)
- `capabilityMastery` — Educator write, owner/parent read
- `capabilityGrowthEvents` — Educator create only, append-only (immutable provenance)
- `proofOfLearningBundles` — Learner create/update, educator/parent read
- `skillMastery` — Educator write, learner read

## Code Conventions

### Style & Formatting

- **Prettier**: semi, singleQuote, tabWidth 2, printWidth 100, trailingComma es5
- **TypeScript**: strict mode enabled
- **React**: functional components, hooks only
- **Import alias**: `@/*` maps to project root (e.g., `@/src/lib/auth`)

### File Naming

- Components/modules: PascalCase (e.g., `AuthProvider.tsx`, `WorkflowRoutePage.tsx`)
- Utilities/hooks: camelCase (e.g., `useAuth.ts`, `workflowRoutes.ts`)
- Tests: `*.test.ts`, `*.spec.ts`, or in `__tests__/` directories

### Architectural Patterns

- **Locale-first routing**: All web routes parameterized by `[locale]` — URL structure is `/en/...`, `/es/...`, etc.
- **Workflow rendering**: Operational routes share the generic record-list UI; evidence-chain routes dispatch to dedicated renderers via `customRouteRenderers.tsx`
- **Role-based access**: Enforced at 4 layers — Firebase Auth claims, Firestore rules, web route metadata, Flutter role gate
- **Offline-first mobile**: Flutter uses Isar for local state with a sync queue
- **AI services**: Internal only — no external AI providers. Enforced via `npm run ai:internal-only:all`
- **Generated code**: `src/dataconnect-generated/` is auto-generated — do not manually edit

### Security

- Firestore rules: RBAC with site-scoping (`firestore.rules`, 900+ lines)
- Storage rules: Role-gated with file size limits (`storage.rules`)
- Secrets: Use Firebase Secrets Manager, never `.env` for sensitive values
- COPPA compliance: Enforced via `npm run qa:coppa:guards`
- Secret scanning: `npm run qa:secret-scan`

## Testing

Run tests before pushing:

```bash
npm run lint && npm run typecheck && npm test
npm --prefix functions run build && npm --prefix functions run test
```

### Test hierarchy

1. **Unit**: `npm test` (Jest with ts-jest)
2. **Functions**: `npm --prefix functions run test`
3. **Firestore rules**: `npm run test:integration:rules` (requires Firebase emulator)
4. **E2E**: `npm run test:e2e:web` (Playwright)
5. **Accessibility**: `npm run test:e2e:web:wcag` (WCAG 2.2 AA via Axe)
6. **Compliance**: `npm run compliance:gate`

## Environment Setup

**Prerequisites**: Node.js 24 (see `.nvmrc`), npm, Firebase CLI, Flutter stable, Java 21 (Android)

```bash
npm ci
npm --prefix functions ci
cd apps/empire_flutter/app && flutter pub get
firebase emulators:start    # Local backend
npm run dev                 # Web dev server
```

**Environment variables**: Copy `.env.example` for development. Firebase config keys are public; server-side secrets go through Firebase Secrets Manager.

## Deployment

- **Web**: Google Cloud Run (Docker, multi-stage build) — `./scripts/deploy.sh primary-web`
- **Functions**: `firebase deploy --only functions` (auto-runs build + gen2 verify)
- **Flutter WASM web**: Google Cloud Run — `./scripts/deploy.sh flutter-web`
- **Flutter native**: `./scripts/deploy.sh flutter-ios` / `flutter-macos` / `flutter-android`
- **Both web surfaces**: `./scripts/deploy.sh web` (deploys Next.js + Flutter WASM)
- **Full platform**: `./scripts/deploy.sh all`
- **Compliance operator**: `./scripts/deploy.sh compliance-operator`
- **Release policy**: Big-bang only (no canary/progressive rollouts)
- **Traffic rehearsal**: `CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web`

## CI/CD

GitHub Actions runs on push to main/release branches and PRs:
- Lint, typecheck, functions build
- Jest unit tests, Playwright E2E, WCAG accessibility
- Flutter web build and analysis
- Compliance gates, telemetry audits

All checks must pass before merge.

## Key Files

| File | Purpose |
|------|---------|
| `src/types/schema.ts` | All Firestore document types including evidence chain |
| `src/lib/routing/workflowRoutes.ts` | All 46 route definitions with role access |
| `src/features/workflows/WorkflowRoutePage.tsx` | Generic route renderer |
| `src/features/workflows/workflowData.ts` | All route data loading, CRUD logic (~4500 lines) |
| `firestore.rules` | Firestore RBAC security rules (900+ lines) |
| `storage.rules` | Storage security rules |
| `functions/src/index.ts` | Function exports, AI coach, BOS scoring |
| `functions/src/bosRuntime.ts` | BOS orchestration, intervention, MVL scoring |
| `functions/src/voiceSystem.ts` | Voice system (TTS/STT/coach) |
| `firebase.json` | Firebase project config, emulator ports |
| `next.config.mjs` | Next.js config (PWA, webpack) |
| `tailwind.config.js` | Tailwind theme (HSL variables, light/dark) |
| `eslint.config.mjs` | ESLint flat config |
| `jest.config.js` | Root Jest config |
| `.env.example` | Dev environment template |

---

## Evidence Chain State (2026-04-22, post educator-proof handoff)

### A. End-to-end wiring that is in place

**1. Schema + rules** — `src/types/schema.ts` models the full chain; `firestore.rules` enforces HQ-only capability writes, educator-only rubric/growth writes (append-only `capabilityGrowthEvents`), learner-owned proof bundles, site-scoped evidence records, parent-linked reads.

**2. Admin-HQ authoring surface** — `HqCapabilityFrameworkRenderer` + `CapabilityFrameworkEditor` define capabilities, progression descriptors, and strand alignment. `HqRubricBuilderRenderer` manages rubric templates. `/hq/curriculum` renders through these custom renderers, not the generic card UI.

**3. Educator capture + review surface** — `EducatorTodayRenderer`, `EducatorEvidenceCaptureRenderer` (hosts `EducatorFeedbackForm` + `EducatorEvidenceCapture`), `EducatorEvidenceReviewRenderer` (with revision-history UI, site-scoped queues, mission-review portfolio linkage, and `pending_proof` checkpoint recovery), `EducatorRubricApplyRenderer` (fallback evidence flow + direct verified-portfolio handoff into `RubricReviewPanel`), `EducatorProofReviewRenderer`, `EducatorAiAuditRenderer`. Live educator capture now resolves educator-scoped session occurrences, attendance-first rosters, canonical `sessionOccurrenceId`, and the linked canonical `portfolioItemId` for portfolio-candidate observations so later rubric review does not fork provenance; revision resubmission flow closes the loop with learners, including portfolio-item sync.

**4. Learner surface** — `LearnerCheckpointRenderer`, `LearnerReflectionsRenderer`, `LearnerProofAssemblyRenderer` (ExplainItBack + OralCheck + MiniRebuild), `LearnerPortfolioCurationRenderer`, `LearnerEvidenceTimelineRenderer`, `LearnerProgressReportRenderer`, `LearnerShowcasePeerReviewRenderer`, `LearnerMiloOSRenderer`. The learner timeline now back-links growth from `missionAttemptId`, `checkpointId`, `linkedPortfolioItemIds`, and `linkedEvidenceRecordIds`, and renders proof bundles as standalone learner-visible entries, so educator-observation evidence and proof-of-learning steps are both visible in the same chronology. Revision-required items surface as banners on `/learner/today`.

**5. Guardian surface** — `GuardianCapabilityViewRenderer` renders strand/legacy-family breakdowns with source badges (educator observed / reflection / checkpoint); `GuardianPassportRenderer` exports the passport view; `ParentAnalyticsDashboard` is wired into `/parent/summary`. Route-aware section focus lets deep links land on passport/portfolio/growth directly.

**6. Admin-School surface** — `SiteImplementationHealthRenderer` shows educator readiness and evidence-coverage gaps at `/site/dashboard` (and related site routes).

**7. Growth write engine + proof boundary (real, not seeded)** — The chain now separates authenticity from interpretation while preserving canonical provenance:
- `applyRubricToEvidence` (`functions/src/index.ts`) — atomic rubric application → `capabilityMastery` / `processDomainMastery` updates → append-only growth events. When `portfolioItemId` is provided, it updates the existing verified canonical portfolio item in place instead of forking into duplicate `rubric-*` artifacts.
- `processCheckpointMasteryUpdate` (`functions/src/index.ts`) — checkpoint completion → mastery + growth event. Checkpoints with no mapped `capabilityId` emit a surface warning instead of silently writing to a fallback capability (phantom-growth prevention).
- `verifyProofOfLearning` (`functions/src/index.ts`) — authenticity boundary only. It updates proof state, proof bundles, and canonical linkage, returns `capabilitiesReadyForRubric`, and no longer writes `capabilityGrowthEvents` or `capabilityMastery` directly.
- `ProofOfLearningVerification.tsx` now deep-links educators into `/educator/rubrics/apply?portfolioItemId=...`, and mission review forwards the same canonical `portfolioItemId` when rubricing verified work.

**8. Parent dashboard reader** — `buildParentLearnerSummary` aggregates from 7+ collections into a **capability snapshot** (strand-level mastery, with legacy-pillar roll-up resolved via `LEGACY_PILLAR_ALIGNMENT`, normalized 0–1, banded strong/developing/emerging), portfolio snapshot, ideation passport, growth timeline with educator provenance, portfolio items preview with per-artifact proof details, AI disclosure, rubric scores, progression descriptors, checkpoint mappings, and evidence summary.

**9. AI transparency** — `AICoachInteraction` capture, `PortfolioItem.aiDisclosureStatus` with 6 derived values, BOS runtime detection of AI-dependency patterns, `EducatorAiAuditRenderer` for educator oversight.

**10. Honesty entrypoints gated** — `src/__tests__/skills-first-honesty-entrypoints.test.ts` enforces K-12 skills-first wording across landing, manifest, locales, and dashboards; blocks resurrection of "Future Skills Academy", "K–9", and "3 Pillars" copy. Legacy-pillar UI is explicitly labeled as "Legacy Curriculum Families" / "Legacy Families".

**11. Curriculum contract landed** — `src/lib/curriculum/architecture.ts` + generated displays (web, Flutter, backend) + `src/__tests__/curriculum-architecture-contract.test.ts`.

**12. Seed data** — Evidence-chain seed scripts now cover capabilities, rubrics, rubric applications, evidence records, mastery, growth events, portfolio items, and proof bundles (not just users/sites/sessions/missions).

### B. What still needs work

**1. Legacy-pillar compatibility layer is visible** — The three-pillar vocabulary (`futureSkills` / `leadership` / `impact`) still flows through parent-dashboard snapshots, analytics aggregates, and some storage shapes. It is honestly labeled as a compatibility roll-up, but the six-strand model should become the primary read shape over time.

**2. No educator annotation layer on timeline** — Educators can't annotate a learner's timeline in-place.

**3. `workflowData.ts` remains a ~4500-line monolith** — Decomposition by domain is still pending and makes the file hard to navigate.

**4. Flutter offline queue missing evidence ops** — Offline capture/review for evidence remains a separate track; only non-evidence ops queue reliably.

**5. Partner-facing outputs** — Contract/deliverable/showcase surfaces render, but partner-facing evidence views should remain gated until the educator/learner trust loop has more real-world signal.

**6. Design-only types** — `MicroSkill`, `MissionVariant`, `WeeklyGoal`, `MotivationAnalytics` have schema entries but limited write paths and no Firestore rules of their own.

### C. Current verdict

**Beta, gold-candidate.** The evidence chain is wired end-to-end: HQ authoring → educator capture/review → learner artifact/reflection/checkpoint/proof → rubric or checkpoint callable → mastery + growth write → portfolio linkage → guardian passport/analytics. The write side is now stricter and more truthful, the learner read side now surfaces direct evidence-linked growth and proof-of-learning chronology more honestly, and the learner export path now carries richer artifact/growth provenance too. Remaining gaps are legacy-pillar cleanup, publish/share polish, Flutter offline evidence ops, and broader distribution polish — not missing limbs of the chain.

**Before claiming any new evidence-chain feature is done**, verify: (a) it writes through `applyRubricToEvidence` or `processCheckpointMasteryUpdate` if it produces growth, (b) proof verification remains authenticity-only, (c) any proof or mission review handoff preserves the canonical `portfolioItemId`, (d) it site-scopes queries, (e) it names strands/stages rather than pillars in new copy, (f) the relevant custom renderer (not the generic card UI) renders it, and (g) the `skills-first-honesty-entrypoints` test still passes.

**Note**: this audit replaces an earlier, more pessimistic one. If you find stale "no write path" / "no rubric builder" / "no framework editor" claims anywhere in docs, treat them as historical — the current state above is authoritative.
