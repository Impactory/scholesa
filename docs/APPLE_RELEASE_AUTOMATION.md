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

4. Upload a signed iOS build to TestFlight once signing is configured locally in Xcode:

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

## Workflow

Use `.github/workflows/apple-release.yml`.

The workflow delegates secret validation and signing material setup to `./scripts/apple_release_ci.sh` so the CI logic stays aligned with the local release scripts.

- `verify-app-store-connect` validates the App Store Connect API key setup on a macOS runner.
- `ios-testflight` is gated behind the `upload_to_testflight` workflow input and requires the iOS signing secrets above.

If VS Code shows `Context access might be invalid` on the workflow secret references, that is an editor validation warning until the matching GitHub secrets exist for the repository. The workflow logic itself was validated locally through `scripts/apple_release_ci.sh` and `scripts/apple_release_local.sh`.

## Notes

- The App Store Connect API key alone is not enough to upload builds. iOS upload still requires signing certificates and a provisioning profile.
- The current automation targets iOS TestFlight. macOS notarization remains a separate Apple signing/notary flow.