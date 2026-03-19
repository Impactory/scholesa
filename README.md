# Scholesa Platform

Scholesa is a multi-surface education platform for K-9 learning studios and schools. This repository now contains the locale-first web app, the Flutter client, Firebase Gen 2 backend functions, a separate compliance operator, shared/generated packages, and the release and audit tooling that governs them.

## Current Platform Shape

| Surface | Primary paths | Notes |
| --- | --- | --- |
| Web app | `app/`, `src/`, `public/`, `locales/` | Next.js App Router with locale-first URLs and protected role workflows |
| Flutter app | `apps/empire_flutter/app/` | Mobile and multi-platform client with its own router, role dashboard, offline queue, and runtime surfaces |
| Backend | `functions/src/` | Firebase Functions v2 on Node 24 for workflow ops, billing, BOS/MIA, voice, telemetry, and policy enforcement |
| Compliance operator | `services/scholesa-compliance/` | Separate Node service and CLI for compliance scans and gates |
| Shared and generated code | `packages/`, `src/dataconnect-generated/`, `src/dataconnect-admin-generated/`, `functions/src/dataconnect-admin-generated/` | Shared packages plus checked-in generated Data Connect clients |
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
- Workflow callables, BOS runtime, voice surfaces, notifications, billing, and telemetry are all exported from the functions package.

### Compliance and Guardrails

- Compliance scanning and CI gating live in `services/scholesa-compliance/`.
- Repo-wide release, telemetry, identity, and no-mock audits live in `scripts/`.

## Deployment

Deploy web and Firebase resources with the repository deployment script:

```bash
./scripts/deploy.sh all
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

Production rollout policy is big-bang only. Use the RC3 release gate documents and operator scripts in the repository root for launch control.

## Notes

- The source of truth for repo structure is the code and manifests, not historical audit dumps.
- Checked-in generated clients under `src/dataconnect-generated/` and related directories are part of the live dependency graph.
- Large audit reports and release artifacts in the repository root are evidence outputs, not runtime entrypoints.
