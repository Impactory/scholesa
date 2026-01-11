# Scholesa Dependency and Component Version Baseline

This document serves as the single source of truth for the minimum and target versions for all core libraries and UI components used in this project. All changes to `package.json` must be reflected here.

## Core Frameworks & Libraries

| Dependency | Current Locked Version | Supported Range & Notes |
|---|---|---|
| Next.js | 14.2.5 | 14.x only. Do not upgrade to 15.x without a migration plan. |
| React / ReactDOM | ^18 | 18.x only. |
| TypeScript | ^5.5.3 | 5.x only. |
| Firebase SDKs | firebase: ^11.1.0, firebase-admin: ^13.6.0 | Use latest stable versions. |
| TailwindCSS | ^3.4.6 | 3.x only. |
| Testing Libraries | N/A | No testing libraries are currently in use. |
| PWA / Service Workers | N/A | Manual service worker implementation. No specific libraries used. |

## UI Components & Design System

| Dependency | Current Locked Version | Supported Range & Notes |
|---|---|---|
| @headlessui/react | ^2.1.2 | |
| @heroicons/react | ^2.1.5 | |
| class-variance-authority | ^0.7.0 | |
| clsx | ^2.1.1 | |
| framer-motion | ^11.3.8 | |
| lucide-react | ^0.560.0 | |
| tailwind-merge | ^2.3.0 | |
| zod | ^3.23.8 | Data validation. |
