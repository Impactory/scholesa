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

If this reports that Play Console rejected app access, add the service-account email from `.env.google_play.local`'s JSON key to Google Play Console -> Users and permissions for `com.scholesa.app`, with permission to view app information and manage releases for the internal testing track.

3. Install local Android release signing from an existing release keystore:

```bash
ANDROID_KEYSTORE_PASSWORD=<store-password> \
ANDROID_KEY_PASSWORD=<key-password> \
./scripts/setup_android_signing.sh /absolute/path/to/release-keystore.jks <key-alias>
```

This writes the ignored `apps/empire_flutter/app/android/key.properties` file and copies the keystore into the ignored `apps/empire_flutter/app/android/app/release-keystore.jks` path. If `keytool` is available, the helper verifies that the alias exists before writing `key.properties`.

If no existing Google Play upload key exists yet, generate a local upload keystore instead:

```bash
./scripts/setup_android_signing.sh --generate
```

This generates ignored local signing files with random passwords. Back up `apps/empire_flutter/app/android/key.properties` and `apps/empire_flutter/app/android/app/release-keystore.jks` securely before registering the upload key with Google Play.

4. Configure the Google Play privacy policy URL when the Android app requests microphone access:

```bash
ANDROID_PRIVACY_POLICY_URL=https://<production-domain>/en/privacy
ANDROID_PRIVACY_POLICY_CONFIRMED=I_HAVE_SET_PLAY_CONSOLE_PRIVACY_POLICY
```

Set the same public privacy policy URL in Google Play Console for `com.scholesa.app` before setting `ANDROID_PRIVACY_POLICY_CONFIRMED`. The current Android app declares `android.permission.RECORD_AUDIO` for voice input in the AI coach experience, so Google Play rejects internal-track uploads until the Play Console privacy policy URL is configured.

5. Verify local Play-release signing prerequisites without uploading anything:

```bash
./scripts/android_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: `.env.google_play.local`, `GOOGLE_PLAY_JSON_KEY_PATH`, `apps/empire_flutter/app/android/key.properties`, required signing values, and the referenced keystore file.

6. Upload a signed Android App Bundle to Google Play internal testing once signing and the Play Console privacy policy are configured locally:

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

Set these local-only values after configuring the privacy policy URL in Google Play Console:

- `ANDROID_PRIVACY_POLICY_URL`
- `ANDROID_PRIVACY_POLICY_CONFIRMED=I_HAVE_SET_PLAY_CONSOLE_PRIVACY_POLICY`

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

Required GitHub Actions variables after configuring the Google Play Console privacy policy URL:

- `ANDROID_PRIVACY_POLICY_URL`
- `ANDROID_PRIVACY_POLICY_CONFIRMED=I_HAVE_SET_PLAY_CONSOLE_PRIVACY_POLICY`

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
- Before upload, CI also fails closed unless the Google Play privacy policy URL variables are set when the Android manifest declares microphone access.
- `./scripts/set_android_github_secrets.sh` validates the local Google Play key, `key.properties`, and referenced keystore before publishing GitHub secrets.

## Notes

- Google Play store release readiness requires an Android App Bundle (`.aab`), not just an APK.
- Google Play store release readiness also requires the public privacy policy URL to be configured in Play Console when the app declares microphone access for voice input.
- `verify_local_release` is the honest local preflight for Android internal-track readiness. It does not upload a build.
- The current automation targets the Google Play internal testing track.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside iOS and macOS proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.