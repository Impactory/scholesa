# Repo Map

Last updated: 2026-05-15

This is the current source-of-truth map for the Scholesa repository. It replaces stale assumptions from earlier single-app or Flutter-only views.

## Runnable Products

| Product | Entry points | Primary code roots | Notes |
| --- | --- | --- | --- |
| Web platform | `npm run dev`, `npm run build`, `npm run test:e2e:web` | `app/`, `src/`, `public/`, `locales/` | Next.js App Router product with locale-first protected workflows; `test:e2e:web` runs the browser harness in explicit fake-backend mode |
| Flutter app | `flutter run`, `flutter analyze`, `flutter test` from `apps/empire_flutter/app` | `apps/empire_flutter/app/lib/`, `apps/empire_flutter/app/test/` | Mobile, Flutter Web front door, and multi-platform client with role routing and offline queue |
| Firebase backend | `npm --prefix functions run build`, `firebase deploy --only functions` | `functions/src/` | Functions v2 on Node 24 for workflows, billing, runtime, voice, telemetry |
| Compliance operator | `npm run compliance:serve`, `npm run compliance:run`, `npm run compliance:scan` | `services/scholesa-compliance/src/` | Separate CI and operator-facing compliance service |

## Top-Level Source Roots

| Path | Purpose | Canonical? |
| --- | --- | --- |
| `app/` | Next.js App Router routes, layouts, API endpoints | Yes |
| `src/` | Web application features, Firebase client code, routing, hooks, shared web logic | Yes |
| `functions/src/` | Firebase Functions implementation | Yes |
| `apps/empire_flutter/app/lib/` | Flutter application code | Yes |
| `apps/empire_flutter/app/test/` | Flutter widget, service, and regression tests | Yes |
| `services/scholesa-compliance/src/` | Compliance service and CLI | Yes |
| `packages/` | Shared package roots such as `i18n`, `shared`, and `safety` | Yes |
| `scripts/` | Platform audit, release, repair, seeding, and policy tooling | Yes |
| `docs/` | Canonical architecture, requirement, telemetry, and release docs | Yes |
| `locales/` | Web locale JSON payloads | Yes |
| `public/` | Web static assets including PWA assets | Yes |

## Web App Layout

| Path | Role |
| --- | --- |
| `app/[locale]/page.tsx` | Localized landing page |
| `app/[locale]/summer-camp-2026/page.tsx` | Public Summer Camp page proxied through `scholesa.com` |
| `app/[locale]/(auth)/` | Auth entrypoints |
| `app/[locale]/(protected)/` | Role-gated web workflow routes |
| `app/api/` | Server-side API routes for web-facing integrations |
| `src/features/workflows/WorkflowRoutePage.tsx` | Generic protected workflow renderer used by most web route pages |
| `src/features/workflows/workflowData.ts` | Web workflow data loader and mutation layer |
| `src/lib/routing/workflowRoutes.ts` | Web canonical route list, defaults, role access, and data modes |

## Flutter App Layout

| Path | Role |
| --- | --- |
| `apps/empire_flutter/app/lib/main.dart` | Bootstrap |
| `apps/empire_flutter/app/lib/router/app_router.dart` | Single route registry |
| `apps/empire_flutter/app/lib/router/role_gate.dart` | Role enforcement |
| `apps/empire_flutter/app/lib/dashboards/role_dashboard.dart` | Discoverability hub per role |
| `apps/empire_flutter/app/lib/modules/` | User-facing and admin-facing Flutter pages by domain |
| `apps/empire_flutter/app/lib/offline/` | Queueing, sync, offline status |
| `apps/empire_flutter/app/lib/runtime/` | BOS, MIA, AI help, and runtime surfaces |
| `apps/empire_flutter/app/lib/services/` | Billing, telemetry, storage, export, API, and runtime service integrations |

## Backend and Compliance Layout

| Path | Role |
| --- | --- |
| `functions/src/index.ts` | Main export surface for Firebase Functions |
| `functions/src/workflowOps.ts` | Admin, billing, integration, and workflow callables |
| `functions/src/bosRuntime.ts` | BOS runtime callable surface |
| `functions/src/voiceSystem.ts` | Voice HTTP handlers and orchestration |
| `services/scholesa-compliance/src/checks/` | Compliance gate implementations |
| `services/scholesa-compliance/src/cli.js` | Compliance CLI |
| `services/scholesa-compliance/src/server.js` | Compliance operator service |

## Generated and Shared Code

| Path | Role | Notes |
| --- | --- | --- |
| `src/dataconnect-generated/` | Generated client package | Checked in and consumed by the root app |
| `src/dataconnect-admin-generated/` | Generated admin package | Checked in and consumed by root and functions code |
| `functions/src/dataconnect-admin-generated/` | Functions-local generated admin package | Kept with backend package |
| `packages/i18n/` | Shared localization package root | Shared package surface |
| `packages/shared/` | Shared package root | Shared library surface |
| `packages/safety/` | Shared safety package root | Shared policy and safety surface |

## Tests and Gates

| Path or file | Role |
| --- | --- |
| `test/` | Root Jest and Playwright tests |
| `src/__tests__/` | Web-focused unit and integration tests |
| `apps/empire_flutter/app/test/` | Flutter regression and widget tests |
| `.github/workflows/ci.yml` | Main CI pipeline |
| `TRACEABILITY_MATRIX.md` and `docs/TRACEABILITY_MATRIX.md` | Requirement-to-implementation evidence |
| `scripts/` | Release gates, telemetry audits, no-mock audits, seeding, and repair tooling |

## Refactor Validation Gates

| Command | Scope | Mutation policy |
| --- | --- | --- |
| `npm run refactor:baseline` | Typecheck, lint, no-mock workflow audit, secret scan, AI internal-only gates, compliance scan | Non-mutating local gate; no deploy, no live seed, no native upload |
| `npm run refactor:full` | Baseline plus Firestore/Storage rules emulator tests, Functions build/tests, Flutter CI tests, Next build | Non-deploying local gate; May 15 proof log is `audit-pack/reports/refactor-full-may15.log` |
| `npm run test:uat:blanket-gold` | Full web/security release gate including live role UAT when live env vars are provided | Non-deploying, but may exercise live `scholesa.com` role accounts when configured |

## Current Public Domain Ownership

| URL family | Owner | Notes |
| --- | --- | --- |
| `/welcome`, `/login`, app-shell role paths | Flutter Web `empire-web` | CanvasKit/Flutter Web renders role surfaces; live UAT uses Flutter host and URL proof rather than DOM text selectors. |
| `/en`, `/en/summer-camp-2026` | Next public pages proxied through Flutter nginx | Public marketing and Summer Camp pages are served by the primary Next service behind the Flutter public front door. |
| `/:locale/*` protected Next routes | Next App Router | Primary source for locale web workflow parity and route metadata; not the owner of live `scholesa.com/login`. |

## Firebase and Infra Files

| File | Role |
| --- | --- |
| `firebase.json` | Firebase project configuration and functions runtime settings |
| `firestore.rules` | Firestore RBAC and site-scoped access rules |
| `firestore.indexes.json` | Firestore indexes |
| `storage.rules` | Storage rules |
| `next.config.mjs` | Web build and PWA configuration |
| `cloudbuild.compliance.yaml` | Compliance-oriented cloud build config |
| `cloudbuild.flutter.yaml` | Flutter cloud build config |

## Canonical Documentation

| File | Purpose |
| --- | --- |
| `README.md` | Top-level operator and developer overview |
| `docs/REPO_MAP.md` | This file |
| `docs/ROUTE_MODULE_MATRIX.md` | Route-to-module inventory across web and Flutter |
| `docs/TRACEABILITY_MATRIX.md` | Requirement coverage and verification evidence |
| `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md` | Release policy and cutover posture |

## Non-Canonical Outputs

These exist in the repo but should not be treated as the primary architecture map:

- historical audit snapshots in the repository root
- generated reports under `reports/`, `artifacts/`, `audit-pack/`, and `coverage/`
- log files such as `build.log`, `firebase-debug.log`, and `firestore-debug.log`
- old directory dumps that do not track the current repo structure