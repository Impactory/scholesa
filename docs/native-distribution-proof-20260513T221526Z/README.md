# Native Distribution Proof - 2026-05-14

This packet captures the native-channel distribution proof for Scholesa.

## iOS TestFlight

- Proof log: `ios-testflight-visibility.log`
- Result: App Store Connect shows TestFlight build `5` for `com.scholesa.app` with `processing_state=VALID`.

## Android Play Internal

- Proof log: `android-play-internal.log`
- Privacy policy URL used for Play Console attestation: `https://scholesa.com/en/privacy`
- Result: Google Play internal upload completed successfully for `com.scholesa.app`.

## macOS Developer ID

- Build proof log: `macos-build.log`
- Notarization proof log: `macos-notarization.log`
- Result: Flutter tests passed, release app built, Developer ID signing completed, notarization returned `Accepted`, stapling validated, and Gatekeeper assessment reported `source=Notarized Developer ID`.

## Log Hygiene

Proof logs were sanitized with `scripts/redact_native_proof_log.sh` before retention. Transient signed upload URLs and cloud-storage query credentials are redacted from proof artifacts.

## Release Owner Check

Before including native-channel scope in Blanket Gold, the release owner should inspect App Store Connect TestFlight, Google Play internal testing, and the notarized macOS app artifact against this proof packet.