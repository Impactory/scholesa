# Dependency Baseline Scholesa

Last reviewed: 2026-03-12
Authority: repo root manifests and Flutter pubspecs

## Purpose

This document is the version authority for Scholesa core frameworks, Firebase SDKs, testing tools, and shared UI layers. Update this file in the same change whenever a listed dependency version changes.

## Runtime Baseline

| Surface | Current locked version | Supported range | Notes |
| --- | --- | --- | --- |
| Node.js (root) | 24.x | 24.x only | Declared in [package.json](/Users/simonluke/dev/scholesa/package.json) engines. |
| Node.js (functions) | 24 | 24.x only | Declared in [functions/package.json](/Users/simonluke/dev/scholesa/functions/package.json) engines. |
| Dart SDK | >=3.5.0 <4.0.0 | Dart 3.5.x through current stable 3.x compatible with Flutter stable | Declared in [apps/empire_flutter/app/pubspec.yaml](/Users/simonluke/dev/scholesa/apps/empire_flutter/app/pubspec.yaml). |
| Flutter SDK | Stable channel, Dart 3.5+ compatible | Stay on stable Flutter 3.x until an explicit migration plan lands | SDK version is environment-managed; keep CI/dev aligned with the Dart constraint above. |

## Web App Baseline

Source: [package.json](/Users/simonluke/dev/scholesa/package.json)

| Package | Current locked version | Supported range | Notes |
| --- | --- | --- | --- |
| next | ^16.1.6 | 16.x only | App Router baseline is already on Next 16; re-validate routing, PWA, and deployment before a 17.x migration. |
| react | ^18.3.1 | 18.x only | Keep React and React DOM on the same major. |
| react-dom | ^18.3.1 | 18.x only | Must stay aligned with React. |
| typescript | ^5.5.3 | 5.x only | Upgrade within 5.x unless tooling migration is planned. |
| firebase | ^11.10.0 | 11.x only | Do not jump to 12.x without a compatibility pass. |
| firebase-admin | ^10.3.0 | 10.x only | Root web/server bundle still depends on the 10.x line; functions use a newer major independently. |
| firebase-functions | ^4.9.0 | 4.x only | Root web/server helpers still target this line; do not jump majors without a server integration audit. |
| next-pwa | ^2.0.2 | 2.x only | Current PWA helper baseline in the root app; re-validate service worker output on any upgrade. On Next 16 this legacy line still emits Workbox and `Compilation.assets` deprecation warnings during `next build --webpack`, but the RC3 build and preflight remain green. Treat that as package debt until an explicit PWA migration is approved. |
| tailwindcss | ^3.4.19 | 3.x only | Do not mix with Tailwind 4 until config/plugins are migrated. |
| tailwind-merge | ^2.6.1 | 2.x only | Upgrade together with Tailwind utility strategy. |
| zod | ^3.25.76 | 3.x only | Zod 4 requires an explicit migration. |
| framer-motion | ^11.18.2 | 11.x only | 12.x is out; defer until animation regressions are audited. |
| lucide-react | ^0.560.0 | 0.x current minor line | Safe to update within the same API shape after icon audit. |

## Functions Baseline

Source: [functions/package.json](/Users/simonluke/dev/scholesa/functions/package.json)

| Package | Current locked version | Supported range | Notes |
| --- | --- | --- | --- |
| typescript | ^5.4.5 | 5.x only | Keep compatible with ts-jest and ts-node. |
| jest | ^29.7.0 | 29.x only | Do not move to 30.x until tests/config are upgraded together. |
| @types/jest | ^29.5.14 | 29.x only | Keep aligned with the Jest 29 line. |
| @types/node | ^25.4.0 | 25.x only | Keep Node type definitions aligned with the functions toolchain. |
| ts-jest | ^29.1.2 | 29.x only | Must match the Jest major. |
| ts-node | ^10.9.2 | 10.x only | Used by spec scripts and local tooling. |
| firebase-admin | ^13.7.0 | 13.x only | Match root baseline. |
| firebase-functions | ^7.1.1 | 7.x only | Match root baseline. |
| stripe | ^20.4.1 | 20.x only | Validate webhook and checkout flows before major upgrades. |

## Flutter App Baseline

Source: [apps/empire_flutter/app/pubspec.yaml](/Users/simonluke/dev/scholesa/apps/empire_flutter/app/pubspec.yaml)

| Package | Current locked version | Supported range | Notes |
| --- | --- | --- | --- |
| firebase_core | ^4.5.0 | 4.x only | Align all FlutterFire packages before major upgrades. |
| firebase_auth | ^6.2.0 | 6.x only | Keep aligned with firebase_core and cloud_firestore. |
| cloud_firestore | ^6.1.3 | 6.x only | Re-test offline sync and emulator flows on upgrades. |
| firebase_storage | ^13.1.0 | 13.x only | Re-test upload rules and portfolio media flows on upgrades. |
| cloud_functions | ^6.0.7 | 6.x only | Keep callable payloads validated against backend changes. |
| google_sign_in | ^7.2.0 | 7.x only | Re-check auth configuration on upgrades. |
| provider | ^6.1.5+1 | 6.x only | Current state-management baseline. |
| go_router | ^17.1.0 | 17.x only | Route refactors required before a major upgrade. |
| connectivity_plus | ^7.0.0 | 7.x only | Used by offline queue and connectivity gates. |
| intl | ^0.20.2 | 0.20.x only | Keep aligned with flutter_localizations. |
| google_fonts | ^8.0.2 | 8.x only | Current typography baseline. |
| flutter_svg | ^2.2.0 | 2.x only | Required so Flutter renders the canonical `scholesa.svg` brand asset directly. |
| audioplayers | ^6.6.0 | 6.x only | Validate BOS voice flows before major upgrades. |
| record | ^6.2.0 | 6.x only | Validate microphone permissions and runtime flows before upgrade. |
| speech_to_text | ^7.3.0 | 7.x only | Voice runtime sensitive. |
| flutter_tts | ^4.2.5 | 4.x only | Voice runtime sensitive. Current upstream web implementation still trips Flutter's wasm dry-run JS interop lint, so Scholesa deploy/build scripts must stay on the stable non-WASM web path until that package becomes wasm-clean. |
| shared_preferences | ^2.5.4 | 2.x only | Storage behavior should stay compatible across mobile/web. |
| equatable | ^2.0.8 | 2.x only | Model baseline. |
| file_picker | ^10.3.10 | 10.x only | Re-test platform pickers on upgrade. |

## UI And Design System Baseline

| Surface | Library | Current version | Supported range | Notes |
| --- | --- | --- | --- | --- |
| Web headless primitives | @headlessui/react | ^2.1.2 | 2.x only | Do not mix with another Headless UI major. |
| Web iconography | @heroicons/react | ^2.1.5 | 2.x only | Match current Tailwind/React setup. |
| Web iconography | lucide-react | ^0.560.0 | Current 0.x line | One icon library per surface when possible; prefer Lucide in app code. |
| Flutter typography | google_fonts | ^8.0.2 | 8.x only | Current Flutter design baseline. |
| Web class composition | class-variance-authority | ^0.7.0 | 0.7.x line | Keep aligned with Tailwind class strategy. |

## Testing And Quality Baseline

| Tool | Current version | Supported range | Notes |
| --- | --- | --- | --- |
| jest | ^29.7.0 | 29.x only | Root and functions should remain on the same major. |
| @playwright/test | ^1.58.2 | 1.x only | Browser automation baseline. `npm run test:e2e:web` is intentionally non-emulator and depends on the `NEXT_PUBLIC_E2E_TEST_MODE` browser test harness instead of Firebase emulators. This harness is never a production dependency or release gate substitute. |
| @firebase/rules-unit-testing | ^4.0.1 | 4.x only | Rules harness baseline. |
| eslint | ^9.39.4 | 9.x only | Do not jump to 10.x without config migration. |
| @eslint/js | ^9.39.4 | 9.x only | Must track eslint major. |
| flutter_test | SDK | Match Flutter SDK | Flutter test baseline is controlled by the active SDK. |

## Drift Snapshot

Command run on 2026-03-12: `npm outdated`, `npm outdated --prefix functions`, and `flutter pub outdated --json`

Key findings:

- Root manifests were refreshed to the currently resolved approved-major versions for Firebase client, framer-motion, Tailwind 3, Zod 3, and React 18 type packages.
- Functions drift had one clean in-range patch candidate: `@types/node` advanced from 25.3.5 to 25.4.0.
- Flutter direct dependency floors were refreshed to the currently resolved approved-major lines for provider, audioplayers, record, shared_preferences, equatable, build_runner, and fake_cloud_firestore.
- Next.js 17+, React 19, Tailwind 4, Firebase 12/13, Jest 30, and Zod 4 remain intentionally deferred pending explicit migration plans.
- March 12, 2026 cleanup verified that Next 16-specific app warnings were removed by migrating the route interceptor to `proxy.ts` and sanitizing the exported Next config. Remaining production-build warnings come from the approved `next-pwa` 2.x plugin internals, not from unsupported Scholesa config keys.
- `build_resolvers` and `build_runner_core` remain reported as discontinued Flutter transitives; clearing that debt requires an explicit build-runner toolchain migration rather than another patch bump.
- Flutter web deployment stays on `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run` for now. The previous `--wasm` deploy path is intentionally retired because `flutter_tts` 4.2.5 still emits wasm dry-run interop violations outside Scholesa source.

## Upgrade Rules

1. Keep React and React DOM on the same major and within the supported range above.
2. Keep Firebase client, admin, and functions SDKs on approved majors; do not resolve peer conflicts with force flags.
3. Upgrade Jest and ts-jest together.
4. Upgrade FlutterFire packages as a compatible set, not one at a time across majors.
5. Update this document and rerun the relevant build/test gates whenever any baseline entry changes.