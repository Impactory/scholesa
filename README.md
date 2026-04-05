# Scholesa Platform

Scholesa is a capability-first evidence platform for K-9 learning studios and schools. Students are evaluated by what they can do, explain, improve, and demonstrate over time — not by marks or completion percentages. This repository contains the locale-first web app, the Flutter client, Firebase Gen 2 backend functions, a separate compliance operator, shared/generated packages, and the release and audit tooling that governs them.

## Current Platform Shape

| Surface | Primary paths | Notes |
| --- | --- | --- |
| Web app | `app/`, `src/`, `public/`, `locales/` | Next.js 16 App Router with locale-first URLs, 69 routes, and protected role workflows |
| Flutter app | `apps/empire_flutter/app/` | Mobile and multi-platform client with its own router, role dashboard, offline queue, MiloOS runtime, and learning signal surfaces |
| Backend | `functions/src/` | Firebase Functions v2 on Node 24 for workflow ops, billing, MiloOS orchestration, voice, telemetry, and policy enforcement |
| Compliance operator | `services/scholesa-compliance/` | Separate Node service and CLI for compliance scans and gates |
| Shared and generated code | `packages/`, `src/dataconnect-generated/`, `src/dataconnect-admin-generated/`, `functions/src/dataconnect-admin-generated/` | Shared packages (i18n with 5 locales, safety) plus checked-in generated Data Connect clients |
| Release and audit tooling | `scripts/`, `.github/workflows/`, `docs/` | QA gates, telemetry audits, release cutover scripts, and evidence docs |

## Canonical Docs

- [docs/REPO_MAP.md](docs/REPO_MAP.md): current source-of-truth repo map
- [docs/ROUTE_MODULE_MATRIX.md](docs/ROUTE_MODULE_MATRIX.md): web and Flutter route-to-module matrix
- [docs/TRACEABILITY_MATRIX.md](docs/TRACEABILITY_MATRIX.md): requirement and verification coverage
- [docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md](docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md): execution plan used for current release evidence
- [RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md](RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md): production release control policy
- [tree.md](tree.md): pointer file to the current repo map docs

## Prerequisites

- Node.js 24.x
- npm
- Firebase CLI
- Flutter stable
- Java 21 for Android builds

## Installation

Install root dependencies:

```bash
npm ci
```

Install Firebase Functions dependencies:

```bash
npm --prefix functions ci
```

Install Flutter dependencies:

```bash
cd apps/empire_flutter/app && flutter pub get
```

## Development Commands

Run the web app:

```bash
npm run dev
```

Run Firebase emulators:

```bash
firebase emulators:start
```

Run the Flutter app from the app workspace:

```bash
cd apps/empire_flutter/app
flutter run
```

Run the compliance operator locally:

```bash
npm run compliance:serve
```

## Verification Commands

Web lint and typecheck:

```bash
npm run lint
npm run typecheck
```

Web unit and browser tests:

```bash
npm test
npm run test:e2e:web
npm run test:e2e:web:wcag
```

Functions and rules:

```bash
npm --prefix functions run build
npm run test:integration:rules
npm run qa:coppa:guards
```

Flutter:

```bash
cd apps/empire_flutter/app
flutter analyze
flutter test
```

Platform release gates:

```bash
npm run flow:platform:gates
npm run qa:vibe-telemetry:audit
npm run qa:vibe-telemetry:blockers
npm run compliance:gate
```

## Architecture Notes

### Web

- Locale-first App Router lives in `app/[locale]/`.
- Most protected workflow pages are thin wrappers around `src/features/workflows/WorkflowRoutePage.tsx`.
- Workflow route metadata and canonical route defaults live in `src/lib/routing/workflowRoutes.ts`.

### Flutter

- The single route registry lives in `apps/empire_flutter/app/lib/router/app_router.dart`.
- Role-gated access is enforced by `apps/empire_flutter/app/lib/router/role_gate.dart`.
- Discoverability is centered on `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart`.
- Offline state and replay live under `apps/empire_flutter/app/lib/offline/`.

### Backend

- Firebase Functions v2 are implemented in `functions/src/index.ts` and supporting modules.
- Workflow callables, MiloOS orchestration runtime, voice surfaces, notifications, billing, and telemetry are all exported from the functions package.
- MiloOS (formerly BOS) is the learner AI support system — internal code uses `bos` identifiers but all user-facing strings say "MiloOS".

### Compliance and Guardrails

- Compliance scanning and CI gating live in `services/scholesa-compliance/`.
- Repo-wide release, telemetry, identity, and no-mock audits live in `scripts/`.

## Deployment

Deploy web and Firebase resources with the repository deployment script:

```bash
./scripts/deploy.sh all
```

Deploy web surfaces (primary Next.js + Flutter WASM):

```bash
./scripts/deploy.sh web
```

For a Cloud Run rehearsal that creates a revision without shifting traffic:

```bash
CLOUD_RUN_NO_TRAFFIC=1 ./scripts/deploy.sh web
```

Deploy only Firebase Functions:

```bash
npm --prefix functions run build
npm --prefix functions run verify:gen2
firebase deploy --only functions
```

Other deploy targets:

```bash
./scripts/deploy.sh primary-web          # Next.js Cloud Run only
./scripts/deploy.sh flutter-web          # Flutter WASM Cloud Run only
./scripts/deploy.sh flutter-ios          # Flutter iOS release build
./scripts/deploy.sh flutter-macos        # Flutter macOS release build
./scripts/deploy.sh flutter-android      # Flutter Android bundle + APK
./scripts/deploy.sh compliance-operator  # Compliance Cloud Run service
./scripts/deploy.sh rules               # Firestore + Storage rules
```

Production rollout policy is big-bang only. Use the RC3 release gate documents and operator scripts in the repository root for launch control.

## Notes

- The source of truth for repo structure is the code and manifests, not historical audit dumps.
- Checked-in generated clients under `src/dataconnect-generated/` and related directories are part of the live dependency graph.
- Large audit reports and release artifacts in the repository root are evidence outputs, not runtime entrypoints.
- All user-facing AI support surfaces use the **MiloOS** product name. Internal code identifiers retain `bos` for the Behavioral Orchestration System specification.
- The platform supports 5 locales: en, es, th, zh-CN, zh-TW via `packages/i18n/locales/`.
- Internationalization keys are served through `packages/i18n/` for Flutter and `locales/` for web.

## Roles

| Role | Description |
| --- | --- |
| `admin` / `hq` | Defines capability frameworks, rubrics, checkpoints, and progression descriptors |
| `siteLead` / `site` | Manages school-level config, educators, classes, schedules, and implementation quality |
| `educator` | Runs sessions, logs observations, reviews evidence, applies rubric judgments |
| `learner` | Creates artifacts, submits reflections, completes checkpoints, discloses AI use |
| `parent` | Views trustworthy progress summaries and evidence-backed reports |
| `partner` | External review, marketplace, and opportunity workflows |
