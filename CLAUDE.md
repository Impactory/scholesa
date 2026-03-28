# CLAUDE.md — Scholesa Platform

## Project Overview

Scholesa is a multi-surface education platform for K-9 learning studios and schools. It is a monorepo containing:

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

## Directory Structure

```
app/[locale]/              # Locale-parameterized web routes
  (auth)/                  # Authentication flows
  (protected)/             # Role-gated pages (thin wrappers → WorkflowRoutePage)
  api/                     # API routes
src/
  features/                # Feature modules (workflows, auth, dashboards, navigation)
  components/              # React components by domain
  lib/
    routing/               # Route definitions & role access
    auth/                  # Auth utilities
    firestore/             # Firestore integration
    telemetry/             # Analytics & telemetry
    ai/                    # AI services (internal only, no external providers)
    voice/                 # Voice system
    i18n/                  # Internationalization
    policies/              # Policy enforcement
  hooks/                   # Custom React hooks
  types/                   # TypeScript type definitions
  dataconnect-generated/   # Generated Data Connect clients (do not edit)
functions/src/             # Firebase Functions backend
  index.ts                 # Function exports
  workflowOps.ts           # Workflow & admin callables
  bosRuntime.ts            # BOS runtime surface
  voiceSystem.ts           # Voice handlers
apps/empire_flutter/app/   # Flutter client
  lib/router/              # Single route registry
  lib/dashboards/          # Role-based dashboards
  lib/modules/             # Feature pages by domain
  lib/offline/             # Offline queue & sync
  lib/runtime/             # BOS, MIA, AI surfaces
services/scholesa-compliance/  # Compliance operator service
packages/                  # Shared packages (i18n, safety)
scripts/                   # QA, release, and audit tooling
locales/                   # i18n JSON files
docs/                      # Architecture & requirement docs
test/                      # Root Jest & Playwright E2E tests
```

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
- **Thin route pages**: Most protected pages are thin wrappers delegating to `src/features/workflows/WorkflowRoutePage.tsx`; route metadata lives in `src/lib/routing/workflowRoutes.ts`
- **Role-based access**: Enforced at 4 layers — Firebase Auth claims, Firestore rules, web route metadata, Flutter role gate
- **Roles**: educator, siteLead, site, hq, admin, partner, learner
- **Offline-first mobile**: Flutter uses Isar for local state with a sync queue
- **AI services**: Internal only — no external AI providers. See `npm run ai:internal-only:all` for enforcement checks
- **Generated code**: `src/dataconnect-generated/` is auto-generated — do not manually edit

### Security

- Firestore rules: RBAC with site-scoping (`firestore.rules`)
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
| `firebase.json` | Firebase project config, emulator ports |
| `firestore.rules` | Firestore security rules |
| `storage.rules` | Storage security rules |
| `next.config.mjs` | Next.js config (PWA, webpack) |
| `tailwind.config.js` | Tailwind theme (HSL variables, light/dark) |
| `eslint.config.mjs` | ESLint flat config |
| `playwright.config.ts` | Playwright E2E config |
| `jest.config.js` | Root Jest config |
| `.env.example` | Dev environment template |
