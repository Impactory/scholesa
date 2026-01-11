# 75_REPO_FILE_MAP_REQUIRED.md
Repo File Map (what files MUST exist for running state)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.

---

## Purpose
This list prevents “missing glue” problems by explicitly naming the files that must exist and compile.

---

## Flutter app (app/)
Required:
- `lib/main.dart` (bootstrap)
- `lib/app_config.dart` (dart-define single source)
- `lib/auth/app_state.dart` (session + role + activeSite + entitlements)
- `lib/router/app_router.dart` (single route registry)
- `lib/router/role_gate.dart` (role-based route guard)
- `lib/dashboards/role_dashboard.dart` (cards per `47`)
- `lib/services/api_client.dart` (adds auth token, handles base URL)
- `lib/services/session_bootstrap.dart` (calls `/v1/me`)
- `lib/offline/offline_queue.dart` (persisted queue)
- `lib/offline/sync_coordinator.dart` (online detection + sync loop)
- `lib/ui/error/fatal_error_screen.dart`
- `lib/ui/common/loading.dart`, `empty_state.dart`, `error_state.dart`

Modules (at least these for running workflows):
- `lib/modules/provisioning/*`
- `lib/modules/attendance/*`

---

## API service (api/)
Required:
- server entrypoint (Node or Dart) that:
  - listens on `$PORT`
  - implements `/healthz`
  - verifies Firebase tokens
  - exposes `/v1/me`
  - exposes provisioning endpoints used by site admin
  - exposes attendance endpoints + `/v1/sync/batch`

Required shared:
- `auth/verify_firebase_token.*`
- `auth/authorize_role_site.*`
- `audit/audit_log_repo.*`
- `firestore/firestore_admin_init.*`
- `routes/*` (grouped by module)
- `webhooks/*` (even if only stubs, keep disabled until used)

---

## Firebase infra (infra/firebase/)
Required:
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`
- `firebase.json`
- `rules_test/*` (emulator tests)

---

## Tools
Recommended:
- `tools/seed/*` (Admin SDK seeding)
- `tools/migrations/*`

---

## Proof commands
- `flutter analyze`
- `flutter test`
- `firebase emulators:exec "npm test"` (or equivalent rules tests)
- `gcloud run deploy ...` (API and web)
