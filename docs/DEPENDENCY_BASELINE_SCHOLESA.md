# Scholesa Dependency and Component Version Baseline

Single source of truth for core framework, SDK, testing, and design-system versions.
When dependency versions change in `package.json` or `apps/empire_flutter/app/pubspec.yaml`, update this document in the same PR.

Last audit run: 2026-03-02 (`npm outdated` + `flutter pub outdated` + `npm run rc3:preflight`).

## Web/Node Platform Baseline

| Dependency | Current (resolved) | Declared in manifest | Supported Range & Notes |
|---|---|---|---|
| Node.js | 24.x | `engines.node: 24.x` | 24.x only for CI/CD and deploy. |
| Next.js | 14.2.35 | `^14.2.35` | 14.x only; do not move to 15/16 without migration plan. |
| React / ReactDOM | 18.3.1 / 18.3.1 | `^18` / `^18` | 18.x only; keep in lockstep majors. |
| TypeScript | 5.9.3 | `^5.5.3` | 5.x only. |
| Firebase Web SDK | 11.10.0 | `^11.1.0` | 11.x only on this release line. |
| Firebase Admin SDK | 13.7.0 | `^13.7.0` | 13.x only. |
| Tailwind CSS | 3.4.19 | `^3.4.6` | 3.x only; no Tailwind 4 migration in this branch. |
| next-pwa | 5.6.0 | `^5.6.0` | 5.x only; paired with Next 14 in this branch. |

## Testing Baseline (Web/Node)

| Dependency | Current (resolved) | Declared in manifest | Supported Range & Notes |
|---|---|---|---|
| Jest | 29.7.0 | `^29.7.0` | 29.x only in this branch. |
| @jest/globals | 29.7.0 | `^29.7.0` | Keep same major as Jest. |
| @types/jest | 29.5.14 | `^29.5.14` | Keep same major as Jest. |
| @firebase/rules-unit-testing | 4.0.1 | `^4.0.1` | 4.x only until Firebase test harness migration. |

## UI / Design System Baseline

| Dependency | Current (resolved) | Declared in manifest | Supported Range & Notes |
|---|---|---|---|
| @headlessui/react | 2.2.9 | `^2.1.2` | 2.x only. |
| @heroicons/react | 2.2.0 | `^2.1.5` | 2.x only. |
| lucide-react | 0.560.0 | `^0.560.0` | 0.x line pinned for icon consistency. |
| class-variance-authority | 0.7.0 | `^0.7.0` | 0.7.x only. |
| clsx | 2.1.1 | `^2.1.1` | 2.x only. |
| framer-motion | 11.18.2 | `^11.3.8` | 11.x only; no 12.x migration in this branch. |
| tailwind-merge | 2.6.1 | `^2.3.0` | 2.x only; no 3.x migration in this branch. |
| zod | 3.25.76 | `^3.23.8` | 3.x only; no zod 4 migration in this branch. |

## Flutter App Baseline (apps/empire_flutter/app)

| Dependency | Current | Declared in manifest | Supported Range & Notes |
|---|---|---|---|
| Flutter SDK | 3.38.9 | FVM-managed | 3.x stable only for current release line. |
| Dart SDK | 3.10.8 | `>=3.2.0 <4.0.0` | 3.x only. |
| firebase_core | 4.5.0 | `^4.4.0` | Keep Flutter Firebase family aligned. |
| firebase_auth | 6.2.0 | `^6.1.4` | Keep aligned with firebase_core generation. |
| cloud_firestore | 6.1.3 | `^6.1.2` | Keep aligned with firebase_core generation. |
| firebase_storage | 13.1.0 | `^13.0.6` | Keep aligned with firebase_core generation. |
| cloud_functions | 6.0.7 | `^6.0.6` | Keep aligned with firebase_core generation. |
| google_sign_in | 7.2.0 | `^7.2.0` | 7.x only. |
| go_router | 17.1.0 | `^17.1.0` | 17.x only in this branch. |
| connectivity_plus | 7.0.0 | `^7.0.0` | 7.x only in this branch. |
| google_fonts | 8.0.2 | `^8.0.2` | 8.x only in this branch. |
| intl | 0.20.2 | `^0.20.2` | 0.20.x only in this branch. |
| file_picker | 10.3.10 | `^10.3.10` | 10.x only in this branch. |
| uuid | 4.5.3 | `^4.4.2` | 4.x only in Flutter app. |
| flutter_lints | 6.0.0 | `^6.0.0` | Keep analyzer/lint policy stable. |

## Drift Snapshot (2026-03-02)

- Web major upgrades available but intentionally deferred by policy: Next 16, React 19, Tailwind 4, Zod 4, Jest 30.
- Applied safe in-major npm upgrades in this pass: `firebase-admin`, `@eslint/eslintrc`, `autoprefixer`, `postcss`, `globals`, `@types/node`.
- Applied safe in-major Flutter lockfile upgrades in this pass: `firebase_core 4.5.0`, `firebase_auth 6.2.0`, `cloud_firestore 6.1.3`, `firebase_storage 13.1.0`, `cloud_functions 6.0.7`, `uuid 4.5.3`.
- Remaining web in-major drift includes `@typescript-eslint/*` + `typescript-eslint` (peer-resolution conflict), plus `@stripe/stripe-js` minor (`8.8.0 -> 8.9.0`).
- Flutter build toolchain has discontinued transitive packages (`build_resolvers`, `build_runner_core`); defer changes to a dedicated build-runner migration PR.
- `flutter pub outdated` now reports direct dependencies up-to-date, with 5 lockfile-upgradable transitive packages and toolchain deprecation warnings; no blocker on current RC3 gate.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `DEPENDENCY_BASELINE_SCHOLESA.md`
<!-- TELEMETRY_WIRING:END -->
