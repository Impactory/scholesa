# Scholesa Flutter App

The Flutter client for the Scholesa capability-first evidence platform. Targets iOS, Android, macOS, Windows, and web (WASM) from a single codebase.

## Architecture

- **Single route registry**: `lib/router/app_router.dart`
- **Role-gated access**: `lib/router/role_gate.dart` enforces per-route permissions
- **Role dashboards**: `lib/dashboards/role_dashboard.dart` provides role-specific home screens
- **Offline-first**: `lib/offline/` provides Isar-backed local state with a replay sync queue
- **MiloOS runtime**: `lib/runtime/` implements the AI support surfaces (BOS orchestration, interventions, voice, MIA coaching)
- **i18n**: `lib/i18n/bos_coaching_i18n.dart` provides learning signal translations (EN, zh-CN, zh-TW)

## Roles

educator, siteLead, site, hq, admin, partner, learner

## Getting Started

```bash
flutter pub get
flutter run
```

## Quality Gates

```bash
flutter analyze --no-pub           # Must pass with 0 issues
flutter test                       # Unit and widget tests
```

The deploy script (`scripts/deploy.sh`) runs `flutter analyze --no-pub --no-fatal-infos` as a gate before any Flutter build target. All info-level issues should still be fixed in code — the flag prevents spurious deploy failures from advisory diagnostics.

## Key Directories

| Directory | Purpose |
| --- | --- |
| `lib/router/` | Route definitions and role gate |
| `lib/dashboards/` | Per-role dashboard widgets |
| `lib/modules/` | Feature pages organized by domain |
| `lib/runtime/` | MiloOS orchestration, interventions, voice, MIA |
| `lib/offline/` | Offline queue and Isar sync |
| `lib/i18n/` | Centralized i18n for learning signals |
| `test/` | Unit, widget, and regression tests |
| `scripts/` | Icon sync and build tooling |

## Platform Icon Sync

Platform icons are maintained in `assets/icons/` and synced across all targets by:

```bash
bash scripts/sync_platform_icons.sh
```

This runs automatically as part of `npm run build` (via `prebuild`) and during `./scripts/deploy.sh` before any Flutter build.

## Deployment

```bash
# Via the repo deploy script (recommended):
../../scripts/deploy.sh flutter-web       # WASM Cloud Run
../../scripts/deploy.sh flutter-ios       # iOS release
../../scripts/deploy.sh flutter-macos     # macOS release
../../scripts/deploy.sh flutter-android   # Android bundle + APK
```
