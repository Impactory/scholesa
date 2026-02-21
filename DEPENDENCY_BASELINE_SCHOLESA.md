# Scholesa Dependency and Component Version Baseline

This document serves as the single source of truth for the minimum and target versions for all core libraries and UI components used in this project. All changes to `package.json` must be reflected here.

## Core Frameworks & Libraries

| Dependency | Current Locked Version | Supported Range & Notes |
|---|---|---|
| Node.js (repo + functions runtime) | 22.x | 22.x only. Do not run CI/CD or deploy scripts on Node 20.x. |
| Next.js | 14.2.35 | 14.x only. Do not upgrade to 15.x without a migration plan. |
| React / ReactDOM | 18.3.1 / 18.3.1 | 18.x only. |
| TypeScript | ^5.8.3 | 5.x only. |
| Firebase SDKs | firebase: 11.10.0, firebase-admin: ^13.6.0 | Use latest stable versions compatible with Node 22 and Next 14.x. |
| TailwindCSS | 3.4.19 | 3.x only. |
| Testing Libraries | N/A | No testing libraries are currently in use. |
| PWA / Service Workers | N/A | Manual service worker implementation. No specific libraries used. |

## Flutter App Baseline (apps/empire_flutter/app)

| Dependency | Current Locked Version | Supported Range & Notes |
|---|---|---|
| Flutter SDK | 3.38.9 | 3.x stable only for RC2; validate plugin compatibility before 4.x. |
| Dart SDK | 3.10.8 | 3.x only. |
| firebase_core | ^4.4.0 | Keep all Firebase Flutter plugins on matching major generation. |
| firebase_auth | ^6.1.4 | Keep aligned with firebase_core major. |
| cloud_firestore | ^6.1.2 | Keep aligned with firebase_core major. |
| firebase_storage | ^13.0.6 | Keep aligned with firebase_core major. |
| cloud_functions | ^6.0.6 | Keep aligned with firebase_core major. |
| google_sign_in | ^7.2.0 | Uses singleton API (`GoogleSignIn.instance`) and `initialize()/authenticate()`. |
| go_router | ^17.1.0 | 17.x only unless route migration plan is approved. |
| connectivity_plus | ^7.0.0 | 7.x only for RC2 branch. |
| intl | ^0.20.2 | 0.20.x only in RC2. |
| google_fonts | ^8.0.2 | 8.x only in RC2. |
| file_picker | ^10.3.10 | 10.x only in RC2. |
| flutter_lints | ^6.0.0 | Keep analyzer policy consistent across app modules. |

## UI Components & Design System

| Dependency | Current Locked Version | Supported Range & Notes |
|---|---|---|
| @headlessui/react | ^2.1.2 | |
| @heroicons/react | ^2.1.5 | |
| class-variance-authority | ^0.7.0 | |
| clsx | ^2.1.1 | |
| framer-motion | 11.18.2 | |
| lucide-react | ^0.560.0 | |
| tailwind-merge | 2.6.1 | |
| zod | 3.25.76 | Data validation. |
