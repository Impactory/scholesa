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

3. Prepare a Developer ID Application identity from the App Store Connect `.p8` key:

```bash
./scripts/setup_apple_signing.sh macos
```

Apple may restrict Developer ID Application certificate creation to the Account Holder even when the `.p8` key has Admin access. If that happens, generate a local CSR and keep the private key on this machine:

```bash
./scripts/setup_apple_signing.sh macos-csr
```

The Account Holder must create the Developer ID Application certificate in Apple Developer by uploading the generated CSR. After downloading the `.cer`, import it with:

```bash
./scripts/setup_macos_developer_id_csr.sh import_cer /absolute/path/to/developer_id.cer
```

4. Verify local macOS distribution prerequisites without signing or notarizing anything:

```bash
./scripts/macos_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: Developer ID Application identity, Developer ID private-key signing access, `.env.app_store_connect.local`, App Store Connect key path, key id, and issuer id.

If `verify_local_release` reports blocked Developer ID private-key access, macOS is usually waiting for private-key access approval for the Developer ID Application identity. Approve the Keychain Access prompt if it is visible. If the prompt does not appear, unlock the login keychain and run the key partition-list repair locally with the keychain password typed by the operator:

```bash
security unlock-keychain ~/Library/Keychains/login.keychain-db
security set-key-partition-list -S apple-tool:,apple: -s -k <login-keychain-password> ~/Library/Keychains/login.keychain-db
```

Do not store the keychain password in the repo, shell history, CI logs, or release proof artifacts.

The local preflight uses a bounded temp-file codesign probe. Override `MACOS_CODESIGN_PROBE_TIMEOUT_SECONDS` only when debugging slow keychain prompts. Live app signing is also bounded by `MACOS_CODESIGN_TIMEOUT_SECONDS` so native proof cannot hang indefinitely.

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

- `verify-macos-notary` validates App Store Connect `.p8` credentials, materializes the `.p8` key, generates/downloads the Developer ID Application identity, and verifies notarization auth.
- `macos-notarize` is gated by the `notarize_macos` dispatch input; it builds the macOS release app, signs it with Developer ID, submits it to Apple notarization, staples the ticket, and runs `spctl` assessment.

Required GitHub secrets:

- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APPLE_DEVELOPER_TEAM_ID`

The shared Apple secret helper publishes the App Store Connect `.p8` secrets:

```bash
./scripts/set_apple_github_secrets.sh Impactory/scholesa
```

## Notes

- The local release build can pass without distribution assets; that proves buildability only.
- macOS distribution Gold requires Developer ID signing plus notarization proof, not just `build/macos/Build/Products/Release/scholesa_app.app`.
- `verify_local_release` does not submit a notarization request or staple a ticket. It only verifies that local prerequisites are present.
- `sign_notarize_staple` and `.github/workflows/macos-release.yml` are executable distribution paths, but they remain unproven until valid `.p8` Apple credentials can generate/download Developer ID signing and a live notarization run succeeds.
- Use `./scripts/native_distribution_readiness.sh` when validating the full native-channel distribution boundary across iOS, Android, and macOS.
- Use `./scripts/native_distribution_proof.sh execute-live` only when the release owner is ready to capture live native-channel distribution proof; it requires an explicit confirmation environment variable before uploading builds or notarizing the macOS app.
- Use `.github/workflows/native-distribution-proof.yml` when proof should be captured in CI artifacts alongside iOS and Android proof. The workflow requires `native_distribution_confirmation=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS`.