# macOS Release Automation

This document describes the local preflight for macOS distribution signing and notarization. It does not replace the validated local unsigned release build path in `./scripts/deploy.sh flutter-macos`.

## Local Setup

1. Install the App Store Connect `.p8` key into the repo-local ignored secrets path:

```bash
./scripts/setup_app_store_connect_key.sh /absolute/path/to/AuthKey_<KEYID>.p8
```

2. Set the issuer UUID after copying it from App Store Connect -> Users and Access -> Keys:

```bash
./scripts/set_app_store_connect_issuer.sh <issuer-uuid>
```

3. Install a Developer ID Application certificate with private key into the local keychain:

```bash
MACOS_DEVELOPER_ID_CERT_PASSWORD=<p12-password> \
./scripts/setup_apple_signing.sh macos /absolute/path/to/developer-id-application.p12
```

4. Verify local macOS distribution prerequisites without signing or notarizing anything:

```bash
./scripts/macos_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: Developer ID Application identity, `.env.app_store_connect.local`, App Store Connect key path, key id, and issuer id.

5. Verify notarization authentication once the credentials are installed:

```bash
./scripts/macos_release_local.sh verify_notary_auth
```

6. After a release app has been built with `./scripts/deploy.sh flutter-macos`, sign, notarize, staple, and assess the app locally:

```bash
./scripts/macos_release_local.sh sign_notarize_staple
```

Pass an explicit app bundle path as the second argument when notarizing a non-default build artifact.

## GitHub Actions

The `.github/workflows/macos-release.yml` workflow mirrors the local release path for CI-controlled distribution:

- `verify-macos-notary` validates App Store Connect and Developer ID secrets, materializes the `.p8` key, imports the Developer ID Application certificate, and verifies notarization auth.
- `macos-notarize` is gated by the `notarize_macos` dispatch input; it builds the macOS release app, signs it with Developer ID, submits it to Apple notarization, staples the ticket, and runs `spctl` assessment.

Required GitHub secrets:

- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APPLE_DEVELOPER_TEAM_ID`
- `MACOS_DEVELOPER_ID_CERT_P12_BASE64`
- `MACOS_DEVELOPER_ID_CERT_PASSWORD`

The shared Apple secret helper can publish the App Store Connect secrets plus the macOS Developer ID certificate secrets when these variables are set:

```bash
MACOS_DEVELOPER_ID_CERT_P12_PATH=/absolute/path/to/developer-id-application.p12 \
MACOS_DEVELOPER_ID_CERT_PASSWORD=<p12-password> \
./scripts/set_apple_github_secrets.sh Impactory/scholesa
```

## Notes

- The local release build can pass without distribution assets; that proves buildability only.
- macOS distribution Gold requires Developer ID signing plus notarization proof, not just `build/macos/Build/Products/Release/scholesa_app.app`.
- `verify_local_release` does not submit a notarization request or staple a ticket. It only verifies that local prerequisites are present.
- `sign_notarize_staple` and `.github/workflows/macos-release.yml` are executable distribution paths, but they remain unproven until valid Apple credentials and a Developer ID Application certificate are installed and a live notarization run succeeds.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds or notarizing the macOS app.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside iOS and Android proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.