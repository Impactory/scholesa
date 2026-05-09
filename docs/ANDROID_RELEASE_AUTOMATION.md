# Android Release Automation

This document describes the local and GitHub Actions setup for Google Play authentication, Android signing, and internal-track release automation.

## Local Setup

1. Install the Google Play service account JSON into the repo-local ignored secrets path:

```bash
./scripts/setup_google_play_key.sh /absolute/path/to/google-play-service-account.json
```

2. Verify the Google Play API wiring locally:

```bash
./scripts/android_release_local.sh verify_play_key
```

3. Install local Android release signing from an existing release keystore:

```bash
ANDROID_KEYSTORE_PASSWORD=<store-password> \
ANDROID_KEY_PASSWORD=<key-password> \
./scripts/setup_android_signing.sh /absolute/path/to/release-keystore.jks <key-alias>
```

This writes the ignored `apps/empire_flutter/app/android/key.properties` file and copies the keystore into the ignored `apps/empire_flutter/app/android/app/release-keystore.jks` path. If `keytool` is available, the helper verifies that the alias exists before writing `key.properties`.

4. Verify local Play-release signing prerequisites without uploading anything:

```bash
./scripts/android_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: `.env.google_play.local`, `GOOGLE_PLAY_JSON_KEY_PATH`, `apps/empire_flutter/app/android/key.properties`, required signing values, and the referenced keystore file.

5. Upload a signed Android App Bundle to Google Play internal testing once signing is configured locally:

```bash
./scripts/android_release_local.sh upload_internal
```

Local configuration is sourced from `.env.google_play.local`, which is ignored by git.

## Local Environment Variables

`./scripts/setup_google_play_key.sh` writes these values into `.env.google_play.local`:

- `GOOGLE_PLAY_JSON_KEY_PATH`
- `ANDROID_APP_IDENTIFIER`
- `PLAY_TRACK`
- `FLUTTER_BIN`

`./scripts/setup_android_signing.sh` writes these values into the ignored Android `key.properties` file:

- `storePassword`
- `keyPassword`
- `keyAlias`
- `storeFile`

## GitHub Actions Secrets

Required for Google Play auth:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`

Required for the `android-internal` workflow job:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

After local Google Play setup and Android signing setup, `./scripts/set_android_github_secrets.sh` can publish the Google Play service account and release signing secrets consumed by `.github/workflows/android-release.yml`:

```bash
./scripts/set_android_github_secrets.sh Impactory/scholesa
```

Set `ANDROID_KEY_PROPERTIES_PATH` when the signing properties file is not at `apps/empire_flutter/app/android/key.properties`.

## Workflow

Use `.github/workflows/android-release.yml`.

The workflow delegates secret validation and signing material setup to `./scripts/android_release_ci.sh` so the CI logic stays aligned with the local release scripts.

- `verify-google-play` validates the Google Play service account configuration.
- `android-internal` is gated behind the `upload_to_internal` workflow input and requires the Android signing secrets above.
- Before upload, CI materializes the Android keystore and `key.properties` from secrets so the build does not depend on runner-local signing files.
- `./scripts/set_android_github_secrets.sh` validates the local Google Play key, `key.properties`, and referenced keystore before publishing GitHub secrets.

## Notes

- Google Play store release readiness requires an Android App Bundle (`.aab`), not just an APK.
- `verify_local_release` is the honest local preflight for Android internal-track readiness. It does not upload a build.
- The current automation targets the Google Play internal testing track.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside iOS and macOS proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.