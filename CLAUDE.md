# CLAUDE.md — Scholesa Platform

## Product Identity

Scholesa is a **capability-first evidence platform** for K-9 learning studios and schools. It is NOT a marks-first LMS or a percentage-first gradebook. Students are evaluated by what they can do, explain, improve, and demonstrate over time.

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

- **Next.js web app** (App Router, locale-first) — `app/`, `src/`
- **Flutter mobile/desktop client** — `apps/empire_flutter/app/`
- **Firebase Functions v2 backend** — `functions/`
- **Compliance operator service** — `services/scholesa-compliance/`
- **Shared packages** — `packages/i18n/`, `packages/safety/`

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
  lib/runtime/             # BOS, MIA, AI surfaces
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

All data loading, CRUD, and UI rendering is handled generically by `WorkflowRoutePage` + `workflowData.ts`. This means **every route renders through the same generic record-list UI** with title/subtitle/status/metadata cards. There are no dedicated domain-specific components for capability frameworks, rubric builders, evidence review, portfolio curation, or growth visualization.

### Routes by Role

**Learner** (4): `/learner/today`, `/learner/missions`, `/learner/habits`, `/learner/portfolio`
**Educator** (8): `/educator/today`, `/educator/attendance`, `/educator/sessions`, `/educator/learners`, `/educator/missions/review`, `/educator/mission-plans`, `/educator/learner-supports`, `/educator/integrations`
**Parent** (4): `/parent/summary`, `/parent/billing`, `/parent/schedule`, `/parent/portfolio`
**Site** (10): `/site/checkin`, `/site/provisioning`, `/site/dashboard`, `/site/sessions`, `/site/ops`, `/site/incidents`, `/site/identity`, `/site/clever`, `/site/integrations-health`, `/site/billing`
**Partner** (5): `/partner/listings`, `/partner/contracts`, `/partner/deliverables`, `/partner/integrations`, `/partner/payouts`
**HQ** (11): `/hq/user-admin`, `/hq/role-switcher`, `/hq/sites`, `/hq/analytics`, `/hq/billing`, `/hq/approvals`, `/hq/audit`, `/hq/safety`, `/hq/integrations-health`, `/hq/curriculum`, `/hq/feature-flags`
**Common** (4): `/messages`, `/notifications`, `/profile`, `/settings`

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
- **Generic workflow rendering**: All routes use the same `WorkflowRoutePage` component with record-list UI
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

- **Web**: Google Cloud Run (Docker, multi-stage build)
- **Functions**: `firebase deploy --only functions` (auto-runs build + gen2 verify)
- **Flutter**: Google Cloud Run (separate service)
- **Full platform**: `./scripts/deploy.sh all`
- **Release policy**: Big-bang only (no canary/progressive rollouts)

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

## Evidence Chain Audit (Current State)

### A. What Exists and Is Aligned

**1. Firestore schema types** (`src/types/schema.ts`) — Rich, well-designed types for the full evidence chain: `Checkpoint`, `MissionAttempt`, `ReflectionEntry`, `SkillEvidence`, `PortfolioItem`, `AICoachInteraction`, `Badge`/`BadgeAward`, `ParentSnapshot`, `PeerFeedback`, `MotivationAnalytics`, `MicroSkill`, `MissionVariant`, `ShowcaseSubmission`, `WeeklyGoal`. These types model capability-first learning correctly.

**2. Firestore security rules** — Correctly implement the evidence chain permissions:
- `capabilities`: HQ-only write (aligned with Admin-HQ framework ownership)
- `capabilityGrowthEvents`: Educator create-only, append-only, immutable (correct provenance)
- `capabilityMastery`: Educator write, parent-linked read (correct growth tracking)
- `rubrics` / `rubricApplications`: Educator write (correct)
- `proofOfLearningBundles`: Learner create/update (learner-owned proof)
- `portfolioItems`: Learner + educator create, parent-linked read
- `evidenceRecords`: Educator write, site-scoped (correct)

**3. Parent dashboard backend** (`functions/src/index.ts`, `buildParentLearnerSummary`) — A comprehensive evidence chain *reader* that aggregates from 7+ collections (`portfolioItems`, `evidenceRecords`, `capabilityMastery`, `capabilityGrowthEvents`, `learnerReflections`, `missionAttempts`, `proofOfLearningBundles`) into:
- **Capability snapshot**: pillar-level mastery (futureSkills, leadership, impact) normalized to 0-1 scale, banded as strong/developing/emerging
- **Portfolio snapshot**: artifact counts, verified counts, evidence-linked counts, badge counts
- **Ideation passport**: mission attempts, completed missions, reflections, voice interactions, collaboration signals, evidence-backed capability claims
- **Growth timeline**: per-capability progression with educator names, rubric scores, linked evidence, proof-of-learning status
- **Portfolio items preview**: each artifact with proof details (ExplainItBack, OralCheck, MiniRebuild), AI disclosure status, reviewer info, rubric scores, progression descriptors, checkpoint mappings
- **Evidence summary**: record count, reviewed count, portfolio-linked count, verification prompts

**4. AI transparency model** — Multi-layered:
- `AICoachInteraction` schema: captures mode, question, response, explain-it-back requirement, version history check
- `PortfolioItem.aiDisclosureStatus`: 6 nuanced values (`learner-ai-not-used`, `learner-ai-verified`, `learner-ai-verification-gap`, `educator-feedback-ai`, `no-learner-ai-signal`, `not-available`)
- Backend computation: AI disclosure status is *derived* from multiple signals (proof bundle declarations, interaction events, explain-it-back events, educator AI feedback) — not just self-reported
- BOS runtime: detects AI-dependency patterns (rapid submit after AI help, heavy AI use, verification gaps)

**5. Proof-of-learning verification model** — Backend computes proof status from 3 verification methods: ExplainItBack + OralCheck + MiniRebuild. All three = "verified", any subset = "partial", none = "missing". Proof bundles are fetched from `proofOfLearningBundles` collection with version history and excerpts.

**6. BOS runtime** (`functions/src/bosRuntime.ts`) — Real implementation with orchestration, intervention scoring, MVL scoring. Tracks `checkpoint_submitted`, `artifact_submitted` events. Computes cognition proxy from checkpoint success rates. Autonomy risk detection with 5 signals.

**7. Voice system** (`functions/src/voiceSystem.ts`) — Real implementation with role-based command policies, checkpoint-aware context, rubric feedback drafting for teachers.

**8. Individual UI components** (exist but not wired into routes):
- `EducatorFeedbackForm.tsx` — structured observation capture (engagement, participation, motivation profile, strategies)
- `CheckpointSubmission.tsx` — checkpoint submission with skill-based questions
- `ReflectionJournal.tsx` — metacognitive reflection with emoji scales
- `ShowcaseSubmissionForm.tsx` — showcase submission with visibility controls
- `AICoachScreen.tsx` — AI coaching with hint/verify/debug modes
- `ParentAnalyticsDashboard.tsx` — SDT scores, activities, engagement insights

**9. Role-based access** — 4-layer enforcement (Auth claims, Firestore rules, route metadata, Flutter gate) is structurally sound.

**10. Synthetic test data** — 14,400 evidence bundles in `docs/scholesa_synthetic_fulltesting_pack_v2/` with evidence records, teacher observations, AI traces, and integrity assessments.

### B. What Exists But Needs Refactor

**1. Generic workflow UI** — ALL 46 routes render through `WorkflowRoutePage` showing flat record-list cards. This is appropriate for operational routes (messaging, billing, incidents) but **wrong for evidence chain routes**:
- `/hq/curriculum` shows missions as flat cards — no capability framework builder, no rubric template editor
- `/educator/missions/review` shows submissions as flat cards — no rubric application interface
- `/learner/portfolio` allows adding portfolio items — but no guided evidence curation
- `/parent/summary` and `/parent/portfolio` show computed snapshots — but through the same generic card renderer, losing the rich data structure the backend computes

**2. Backend-to-UI gap** — The `buildParentLearnerSummary` function produces deeply structured evidence data (growth timelines, passport claims, AI disclosure details, proof excerpts), but the `workflowData.ts` frontend flattens this into generic `WorkflowRecord` cards with title/subtitle/status/metadata. The rich structure is computed but not rendered.

**3. HQ curriculum route** — Currently only manages `missions` (CRUD) and `trainingCycles`. Does NOT manage capabilities, rubrics, checkpoints, progression descriptors, or micro-skills.

**4. Evidence components not wired to routes** — `EducatorFeedbackForm`, `CheckpointSubmission`, `ReflectionJournal`, `ShowcaseSubmissionForm`, `AICoachScreen`, `ParentAnalyticsDashboard` exist as standalone components but are not integrated into the workflow route system.

**5. `workflowData.ts` monolith** (~4500 lines) — All route-specific data loading, CRUD, and business logic in a single file. Needs decomposition by domain.

### C. What Is Fake, Partial, or Misleading

**1. No educator observation in routes** — `EducatorFeedbackForm.tsx` exists with full implementation, but educators have no way to reach it from `/educator/today` or `/educator/missions/review`. The 10-second evidence capture rule cannot be met.

**2. No rubric builder or application UI** — `rubrics` and `rubricApplications` collections exist in Firestore rules, but there is no route or UI for creating/applying rubrics.

**3. No proof-of-learning assembly workflow** — The backend *reads* proof bundles beautifully, but there is no learner-facing UI to *create* proof bundles (assemble ExplainItBack, OralCheck, MiniRebuild).

**4. No capability growth *write* path** — `capabilityMastery` and `capabilityGrowthEvents` collections are read by the parent dashboard backend, but no code *writes* to these collections in response to rubric applications or checkpoint completions. Growth data must currently be seeded manually.

**5. Rich parent data rendered as flat cards** — The parent dashboard backend computes growth timelines, passport claims, portfolio previews with proof details, AI disclosure, and rubric scores. But `workflowData.ts` converts these into generic `WorkflowRecord` objects, losing most of the structure.

**6. MicroSkill, MissionVariant, WeeklyGoal, MotivationAnalytics** — Types exist in `schema.ts` with no Firestore rules or write paths. Design-only.

### D. What Is Missing

**1. Capability Framework admin UI** — No way for Admin-HQ to define frameworks, progression descriptors, or map capabilities to units/projects/checkpoints. The `capabilities` collection exists but has no management surface.

**2. Dedicated evidence chain UI components** — The route system needs domain-specific renderers for:
- Growth timeline visualization (data exists in backend, no renderer)
- Portfolio curation with evidence linking (schema supports it, no UI)
- Passport/capability report view (backend computes claims, no output format)
- Rubric builder and application interface
- Evidence review dashboard for educators

**3. Capability growth write engine** — The logic that connects rubric applications -> mastery updates -> growth events does not exist.

**4. Admin-School implementation health** — No dashboard showing educator readiness, evidence coverage gaps, or implementation quality metrics.

**5. Canonical seeded data for evidence chain** — Seed scripts create users/sites/sessions/missions but NOT capabilities, rubrics, evidence records, mastery, growth events, portfolio items, or proof bundles.

### E. Most Blocked Role

**Admin-HQ** — Cannot define capability frameworks, rubrics, or progression descriptors. Without these, the entire downstream chain has no structural foundation.

Second most blocked: **Educator** — Has components (`EducatorFeedbackForm`, `CheckpointSubmission`) but they aren't reachable from workflow routes. Evidence capture is possible in code but not in practice.

Third most blocked: **Learner** — Can add portfolio items but cannot assemble proof bundles, and the growth engine doesn't update from their submissions.

### F. Highest-Risk Break in the Evidence Chain

**Two critical breaks:**

1. **Admin-HQ setup -> Session runtime**: No UI to define capability frameworks. Everything downstream depends on this.

2. **Rubric/checkpoint completion -> Growth update**: No write path from evidence events to `capabilityMastery` / `capabilityGrowthEvents`. The parent dashboard backend beautifully *reads* growth data, but nothing *writes* it. The read side is gold-quality; the write side is absent.

### G. Current Recommendation

**Not ready for gold. Beta-candidate with caveats.**

The backend evidence aggregation is surprisingly strong — `buildParentLearnerSummary` is a ~800-line function that correctly joins 7+ collections, computes growth bands, AI disclosure status, proof verification status, and passport claims. The schema types are pedagogically correct. The security rules are right. Individual UI components for evidence capture exist.

**The gap is integration:** components exist in isolation (backend aggregation, UI components, types, rules) but are not connected into end-to-end flows through the route system. The generic `WorkflowRoutePage` card renderer sits between the rich backend and the user, flattening everything.

### H. Build Priority (To Strengthen Evidence Chain)

1. **Admin-HQ capability framework + rubric management UI** (unblocks the entire chain)
2. **Wire existing components into routes** (EducatorFeedbackForm -> educator routes, CheckpointSubmission -> learner routes, ParentAnalyticsDashboard -> parent routes)
3. **Domain-specific route renderers** replacing generic cards for evidence chain routes (growth timeline, portfolio curation, passport view)
4. **Capability growth write engine** (rubric application -> mastery update -> growth event)
5. **Proof-of-learning assembly UI** for learners (ExplainItBack, OralCheck, MiniRebuild)
6. **Canonical seed data** covering the full evidence chain for demo/dev/UAT
7. **Admin-School implementation health dashboard**
8. **Partner-facing outputs** (only after trust is proven)
