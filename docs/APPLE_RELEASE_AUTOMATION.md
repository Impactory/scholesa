# Apple Release Automation

This document describes the local and GitHub Actions setup for App Store Connect authentication and iOS TestFlight release automation.

## Local Setup

1. Install the App Store Connect `.p8` key into the repo-local ignored secrets path:

```bash
./scripts/setup_app_store_connect_key.sh /absolute/path/to/AuthKey_<KEYID>.p8
```

2. Set the issuer UUID after copying it from App Store Connect -> Users and Access -> Keys:

```bash
./scripts/set_app_store_connect_issuer.sh <issuer-uuid>
```

3. Verify the API key wiring locally:

```bash
./scripts/apple_release_local.sh verify_api_key
```

4. Prepare local iOS distribution signing from the App Store Connect `.p8` key:

```bash
./scripts/setup_apple_signing.sh ios
```

This delegates to `./scripts/apple_release_local.sh prepare_signing`, which asks Apple to generate/download the Apple Distribution identity and App Store provisioning profile through the configured App Store Connect `.p8` key.

5. Verify local TestFlight signing prerequisites without uploading anything:

```bash
./scripts/apple_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: `.env.app_store_connect.local`, App Store Connect issuer configuration, a local Apple Distribution identity, and at least one installed `.mobileprovision` profile.

6. Upload a signed iOS build to TestFlight once signing is configured locally:

```bash
./scripts/apple_release_local.sh upload_testflight
```

Local configuration is sourced from `.env.app_store_connect.local`, which is ignored by git.

## Local Environment Variables

`./scripts/setup_app_store_connect_key.sh` writes these values into `.env.app_store_connect.local`:

- `APP_STORE_CONNECT_API_KEY_PATH`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `IOS_APP_IDENTIFIER`
- `APPLE_DEVELOPER_TEAM_ID`
- `FLUTTER_BIN`

`./scripts/setup_apple_signing.sh ios` consumes the repo-local `.env.app_store_connect.local` values and generates signing material through Apple APIs.

## GitHub Actions Secrets

Required for App Store Connect auth:

- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

Required for the `ios-testflight` workflow job:

- `APPLE_DEVELOPER_TEAM_ID`

Required for the `macos-release` workflow jobs:

- `APPLE_DEVELOPER_TEAM_ID`

After local App Store Connect setup, `./scripts/set_apple_github_secrets.sh` publishes the `.p8` App Store Connect secrets used by both TestFlight and macOS notarization automation.

## Workflow

Use `.github/workflows/apple-release.yml`.

The workflow delegates secret validation and signing material setup to `./scripts/apple_release_ci.sh` so the CI logic stays aligned with the local release scripts.

- `verify-app-store-connect` validates the App Store Connect API key setup on a macOS runner.
- `ios-testflight` is gated behind the `upload_to_testflight` workflow input and generates signing assets from the `.p8` credentials before upload.

If VS Code shows `Context access might be invalid` on the workflow secret references, that is an editor validation warning until the matching GitHub secrets exist for the repository. The workflow logic itself was validated locally through `scripts/apple_release_ci.sh` and `scripts/apple_release_local.sh`.

## Notes

- The App Store Connect `.p8` key must be authorized to generate/download certificates and profiles; if Apple rejects the key, signing cannot proceed.
- `verify_local_release` is the honest local preflight for TestFlight readiness. It does not upload a build.
- iOS TestFlight and macOS notarization share App Store Connect auth but generate/use separate signing identities. Keep Apple Distribution and Developer ID Application identities distinct.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside Android and macOS proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.