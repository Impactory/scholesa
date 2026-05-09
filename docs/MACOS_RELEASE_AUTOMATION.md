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

3. Install a Developer ID Application certificate with private key into the local keychain.

4. Verify local macOS distribution prerequisites without signing or notarizing anything:

```bash
./scripts/macos_release_local.sh verify_local_release
```

This fails closed and reports all missing local prerequisites in one pass: Developer ID Application identity, `.env.app_store_connect.local`, App Store Connect key path, key id, and issuer id.

5. Verify notarization authentication once the credentials are installed:

```bash
./scripts/macos_release_local.sh verify_notary_auth
```

## Notes

- The local release build can pass without distribution assets; that proves buildability only.
- macOS distribution Gold requires Developer ID signing plus notarization proof, not just `build/macos/Build/Products/Release/scholesa_app.app`.
- This preflight does not submit a notarization request or staple a ticket. It only verifies that local prerequisites are present.