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
