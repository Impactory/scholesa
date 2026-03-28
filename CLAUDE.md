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

1. **Firestore schema types** (`src/types/schema.ts`) — Rich, well-designed types for the full evidence chain: `Checkpoint`, `MissionAttempt`, `ReflectionEntry`, `SkillEvidence`, `PortfolioItem`, `AICoachInteraction`, `Badge`/`BadgeAward`, `ParentSnapshot`, `PeerFeedback`, `MotivationAnalytics`, `MicroSkill`, `MissionVariant`, `ShowcaseSubmission`, `WeeklyGoal`. These types model capability-first learning correctly.

2. **Firestore security rules** — Correctly implement the evidence chain permissions:
   - `capabilities`: HQ-only write (aligned with Admin-HQ framework ownership)
   - `capabilityGrowthEvents`: Educator create-only, append-only, immutable (correct provenance)
   - `capabilityMastery`: Educator write, parent-linked read (correct growth tracking)
   - `rubrics` / `rubricApplications`: Educator write (correct)
   - `proofOfLearningBundles`: Learner create/update (learner-owned proof)
   - `portfolioItems`: Learner + educator create, parent-linked read
   - `evidenceRecords`: Educator write, site-scoped (correct)

3. **PortfolioItem schema** — Includes `capabilityIds`, `growthEventIds`, `rubricApplicationId`, `proofBundleId`, `proofOfLearningStatus`, `aiDisclosureStatus`, `verificationStatus`. This is structurally aligned with the evidence chain — portfolio items can link to capabilities, rubric applications, proof bundles, and AI disclosure.

4. **AI transparency model** — `AICoachInteraction` captures mode, student question, AI response, explain-it-back requirement/approval, version history check. `PortfolioItem.aiDisclosureStatus` has nuanced values (`learner-ai-not-used`, `learner-ai-verified`, `learner-ai-verification-gap`, etc.). BOS runtime detects AI-dependency signals (rapid submit after AI help).

5. **BOS runtime** (`functions/src/bosRuntime.ts`) — Real implementation with orchestration, intervention scoring, MVL (Minimum Viable Learning) scoring. Tracks `checkpoint_submitted`, `artifact_submitted` events. Computes cognition proxy from checkpoint success rates.

6. **Voice system** (`functions/src/voiceSystem.ts`) — Real implementation with role-based command policies (learner vs teacher), checkpoint-aware context, rubric feedback drafting for teachers.

7. **46 workflow routes** — All defined with correct role access, data modes, and nav groups.

8. **Role-based access** — 4-layer enforcement (Auth claims, Firestore rules, route metadata, Flutter gate) is structurally sound.

### B. What Exists But Needs Refactor

1. **Generic workflow UI** — ALL routes render through a single `WorkflowRoutePage` that shows a flat record-list with title/subtitle/status/metadata cards. This is appropriate for operational routes (messages, billing, incidents) but **fundamentally wrong for evidence chain routes**:
   - `/hq/curriculum` shows missions as flat cards — no capability framework builder, no rubric template editor, no progression descriptor manager
   - `/educator/missions/review` shows submissions as flat cards — no evidence review UI, no rubric application interface, no observation logger
   - `/learner/portfolio` allows adding portfolio items — but no evidence curation, no capability mapping, no proof-of-learning assembly
   - `/parent/summary` shows computed snapshots — but no capability growth visualization, no evidence drill-down

2. **HQ curriculum route** — Currently only manages `missions` (CRUD) and `trainingCycles`. Does NOT manage capabilities, rubrics, checkpoints, progression descriptors, or micro-skills. The route name suggests curriculum but delivers only mission administration.

3. **Parent portfolio route** — Computes `capabilitySnapshot` and `portfolioSnapshot` from learner profiles, which is good. But the data appears to come from pre-computed snapshots on the user document rather than from actual `capabilityMastery` or `capabilityGrowthEvents` collections. The snapshot provenance is unclear.

4. **`workflowData.ts` monolith** (~4500 lines) — All route-specific data loading, CRUD, and business logic is in a single file with a massive switch statement. This needs to be decomposed by domain as evidence chain features are built out.

### C. What Is Fake, Partial, or Misleading

1. **No dedicated evidence capture UI** — Educators have no observation-logging tool. The `/educator/today` route shows session records but has no "log evidence now" workflow. The 10-second evidence capture rule cannot be met with the current generic card UI.

2. **No rubric builder or application UI** — `rubrics` and `rubricApplications` collections exist in Firestore rules and types, but there is no route or UI for creating rubrics, applying rubrics to learner work, or viewing rubric judgments. The `/hq/curriculum` route does not surface rubric management.

3. **No proof-of-learning assembly workflow** — `proofOfLearningBundles` collection exists with correct rules (learner create/update) but there is no UI for learners to assemble proof bundles or for educators to verify them.

4. **No capability growth engine** — `capabilityMastery` and `capabilityGrowthEvents` collections exist with correct rules, but there is no code that writes to these collections in response to rubric applications or checkpoint completions. The growth update logic does not exist.

5. **No passport/reporting output** — No route, component, or function generates a learner passport, capability report, or family-friendly progress report from evidence data.

6. **No dedicated checkpoint UI** — `Checkpoint` type exists with explain-it-back fields, but the learner-facing checkpoint submission UI is not implemented. Checkpoints are tracked as BOS events but not as standalone workflow steps.

7. **MicroSkill, MissionVariant, WeeklyGoal, ParentSnapshot, MotivationAnalytics** — Types exist in `schema.ts` but have no corresponding Firestore rule collections (except partial coverage). These are design-only, not persisted.

8. **SkillEvidence type** — Defined in `schema.ts` but no corresponding Firestore rule for a `skillEvidence` collection. The type describes rich evidence submissions but nothing writes or reads this data.

### D. What Is Missing

1. **Capability Framework admin UI** — No way for Admin-HQ to define capability frameworks, create progression descriptors, or map capabilities to units/projects/checkpoints. The `capabilities` collection exists but has no management surface.

2. **Educator live observation tool** — No quick-capture interface for logging observations during studio/build time. Critical for the educator rule (evidence in under 10 seconds).

3. **Learner evidence submission flow** — No guided workflow for learners to submit artifacts, attach reflections, disclose AI use, and request checkpoint review.

4. **Growth visualization** — No charts, timelines, or progression views showing capability growth over time for any role.

5. **Portfolio curation** — No UI for learners to select best evidence, curate portfolio, or mark items as showcase-ready with capability mapping.

6. **Guardian capability view** — No view that answers "what can this learner do now?" with evidence provenance. Parent routes show computed snapshots but no evidence drill-down.

7. **Admin-School implementation health** — No dashboard showing educator readiness, evidence coverage gaps, or implementation quality metrics.

8. **Canonical seeded data for evidence chain** — Seed scripts create users, sites, sessions, missions. They do NOT seed capabilities, rubrics, checkpoints, evidence records, capability mastery, growth events, portfolio items, or proof bundles. The evidence chain cannot be tested or demoed.

### E. Most Blocked Role

**Admin-HQ** — Cannot define capability frameworks, rubrics, or progression descriptors. Without these, the entire downstream chain (educator observation against rubrics, learner checkpoints against capabilities, growth tracking, portfolio mapping, reporting) has no structural foundation.

Second most blocked: **Educator** — Has session routes but no evidence capture or rubric application workflow.

### F. Highest-Risk Break in the Evidence Chain

**Admin-HQ setup -> Session runtime**: The framework definition step does not exist. Capabilities are a Firestore collection with HQ-only write rules, but there is no UI to create them, no way to attach rubrics, no way to define progression levels. Everything downstream depends on this.

### G. Current Recommendation

**Not ready.**

The schema design is strong. The Firestore security model is correct. The types in `schema.ts` demonstrate genuine understanding of capability-first pedagogy. But the implementation stops at the data model layer. The generic `WorkflowRoutePage` renders every route as flat record cards, which works for operational workflows but cannot deliver the evidence chain experience.

### H. Build Priority (To Strengthen Evidence Chain)

1. Admin-HQ capability framework + rubric management UI
2. Educator live evidence capture (observation logger, < 10 seconds)
3. Learner artifact/reflection/checkpoint submission flow
4. Proof-of-learning assembly + verification
5. Capability growth update engine (rubric application -> mastery update -> growth event)
6. Portfolio curation with evidence linking
7. Passport/reporting output
8. Guardian/Admin-School interpretation layers
9. Canonical seed data covering the full evidence chain
10. Partner-facing outputs (only after trust is proven)
