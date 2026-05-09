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

4. Install local iOS distribution signing from external Apple signing assets:

```bash
IOS_SIGNING_CERT_PASSWORD=<p12-password> \
./scripts/setup_apple_signing.sh ios /absolute/path/to/ios-distribution.p12 /absolute/path/to/profile.mobileprovision
```

This imports the Apple Distribution certificate into the local keychain and copies the provisioning profile into `~/Library/MobileDevice/Provisioning Profiles/scholesa-app-store.mobileprovision` after validating the profile app identifier against `com.scholesa.app`.

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

`./scripts/setup_apple_signing.sh ios` consumes `IOS_SIGNING_CERT_PASSWORD` and the external `.p12` / `.mobileprovision` paths provided on the command line. It does not write those secrets to tracked files.

## GitHub Actions Secrets

Required for App Store Connect auth:

- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`

Required for the `ios-testflight` workflow job:

- `APPLE_DEVELOPER_TEAM_ID`
- `IOS_SIGNING_CERT_P12_BASE64`
- `IOS_SIGNING_CERT_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`

Required for the `macos-release` workflow jobs:

- `APPLE_DEVELOPER_TEAM_ID`
- `MACOS_DEVELOPER_ID_CERT_P12_BASE64`
- `MACOS_DEVELOPER_ID_CERT_PASSWORD`

After local App Store Connect setup, `./scripts/set_apple_github_secrets.sh` can publish the shared App Store Connect secrets and optional signing secrets. Set `IOS_SIGNING_CERT_P12_PATH` / `IOS_SIGNING_CERT_PASSWORD` for TestFlight signing and `MACOS_DEVELOPER_ID_CERT_P12_PATH` / `MACOS_DEVELOPER_ID_CERT_PASSWORD` for macOS Developer ID notarization before running it.

## Workflow

Use `.github/workflows/apple-release.yml`.

The workflow delegates secret validation and signing material setup to `./scripts/apple_release_ci.sh` so the CI logic stays aligned with the local release scripts.

- `verify-app-store-connect` validates the App Store Connect API key setup on a macOS runner.
- `ios-testflight` is gated behind the `upload_to_testflight` workflow input and requires the iOS signing secrets above.
- Before upload, CI now validates that the imported certificate exposes an Apple Distribution identity and that the provisioning profile matches both the configured Apple team and `com.scholesa.app`.

If VS Code shows `Context access might be invalid` on the workflow secret references, that is an editor validation warning until the matching GitHub secrets exist for the repository. The workflow logic itself was validated locally through `scripts/apple_release_ci.sh` and `scripts/apple_release_local.sh`.

## Notes

- The App Store Connect API key alone is not enough to upload builds. iOS upload still requires signing certificates and a provisioning profile.
- `verify_local_release` is the honest local preflight for TestFlight readiness. It does not upload a build.
- iOS TestFlight and macOS notarization share App Store Connect auth but use separate signing certificates. Keep Apple Distribution and Developer ID Application certificates distinct.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside Android and macOS proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.