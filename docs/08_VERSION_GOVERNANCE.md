# 08_VERSION_GOVERNANCE.md

This prevents “versioning issues” and brittle builds.

## Pinning
- Use FVM to pin Flutter SDK version.
- Commit pubspec.lock.
- Use compatible Dart SDK constraints.
- API uses pinned Dart SDK and lockfile.

## Upgrade rhythm
- monthly dependency review
- upgrade only if builds + QA + audit pass

## CI baseline
- Flutter: analyze, test, build web --release
- API: analyze, test, docker build
- Firestore rules: emulator tests (recommended)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `08_VERSION_GOVERNANCE.md`
<!-- TELEMETRY_WIRING:END -->
