#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
RUNNER_TEMP_DIR="${2:-${RUNNER_TEMP:-/tmp}}"

IOS_APP_IDENTIFIER="${IOS_APP_IDENTIFIER:-com.scholesa.app}"

fail() {
  echo "[apple-release-ci] $*" >&2
  exit 1
}

require_env_values() {
  local missing=()
  local key
  for key in "$@"; do
    if [[ -z "${!key:-}" ]]; then
      missing+=("$key")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "Missing required environment values: ${missing[*]}"
  fi
}

write_github_env() {
  [[ -n "${GITHUB_ENV:-}" ]] || fail "GITHUB_ENV is not set"
  printf '%s\n' "$1" >> "$GITHUB_ENV"
}

decode_base64_to_file() {
  local payload="$1"
  local destination="$2"
  if ! printf '%s' "$payload" | base64 --decode > "$destination"; then
    fail "Unable to decode base64 payload into $destination"
  fi
}

extract_plist_value() {
  local plist_path="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" 2>/dev/null || true
}

validate_distribution_identity() {
  local keychain_path="$1"
  local identities
  identities="$(security find-identity -v -p codesigning "$keychain_path" 2>/dev/null || true)"

  if ! printf '%s\n' "$identities" | grep -Eq '"(Apple|iOS) Distribution: .*\(' ; then
    fail "Imported signing certificate does not expose an Apple Distribution identity. Check IOS_SIGNING_CERT_P12_BASE64 and IOS_SIGNING_CERT_PASSWORD."
  fi
}

validate_provisioning_profile() {
  local profile_path="$1"
  local plist_path="$RUNNER_TEMP_DIR/provisioning-profile.plist"
  local application_identifier
  local expected_application_identifier
  local profile_team_id
  local profile_uuid
  local profile_name

  security cms -D -i "$profile_path" > "$plist_path" 2>/dev/null \
    || fail "Unable to decode provisioning profile at $profile_path"

  application_identifier="$(extract_plist_value "$plist_path" 'Entitlements:application-identifier')"
  profile_team_id="$(extract_plist_value "$plist_path" 'TeamIdentifier:0')"
  profile_uuid="$(extract_plist_value "$plist_path" 'UUID')"
  profile_name="$(extract_plist_value "$plist_path" 'Name')"

  [[ -n "$profile_team_id" ]] || fail "Provisioning profile is missing TeamIdentifier"
  [[ -n "$application_identifier" ]] || fail "Provisioning profile is missing Entitlements:application-identifier"

  if [[ -n "${APPLE_DEVELOPER_TEAM_ID:-}" && "$profile_team_id" != "$APPLE_DEVELOPER_TEAM_ID" ]]; then
    fail "Provisioning profile team mismatch: expected $APPLE_DEVELOPER_TEAM_ID, found $profile_team_id"
  fi

  expected_application_identifier="$profile_team_id.$IOS_APP_IDENTIFIER"
  if [[ "$application_identifier" != "$expected_application_identifier" ]]; then
    fail "Provisioning profile app identifier mismatch: expected $expected_application_identifier, found $application_identifier"
  fi

  echo "[apple-release-ci] Provisioning profile validated: ${profile_name:-unknown} (${profile_uuid:-unknown})"
}

materialize_app_store_connect_key() {
  require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
  local key_dir="$RUNNER_TEMP_DIR/app_store_connect"
  local key_path="$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  mkdir -p "$key_dir"
  decode_base64_to_file "$APP_STORE_CONNECT_API_KEY_P8_BASE64" "$key_path"
  chmod 600 "$key_path"

  write_github_env "APP_STORE_CONNECT_API_KEY_PATH=$key_path"
  write_github_env "APP_STORE_CONNECT_KEY_ID=$APP_STORE_CONNECT_KEY_ID"
  write_github_env "APP_STORE_CONNECT_ISSUER_ID=$APP_STORE_CONNECT_ISSUER_ID"
  write_github_env "IOS_APP_IDENTIFIER=com.scholesa.app"
  write_github_env "APPLE_DEVELOPER_TEAM_ID=$APPLE_DEVELOPER_TEAM_ID"
  write_github_env "FLUTTER_BIN=flutter"
}

import_signing_assets() {
  require_env_values IOS_SIGNING_CERT_P12_BASE64 IOS_SIGNING_CERT_PASSWORD IOS_PROVISIONING_PROFILE_BASE64
  local cert_path="$RUNNER_TEMP_DIR/ios-signing-cert.p12"
  local keychain_path="$RUNNER_TEMP_DIR/app-signing.keychain-db"
  local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
  local profile_path="$profile_dir/scholesa.mobileprovision"

  decode_base64_to_file "$IOS_SIGNING_CERT_P12_BASE64" "$cert_path"
  security create-keychain -p temp-signing "$keychain_path"
  security set-keychain-settings -lut 21600 "$keychain_path"
  security unlock-keychain -p temp-signing "$keychain_path"
  security import "$cert_path" -P "$IOS_SIGNING_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
  security list-keychain -d user -s "$keychain_path"
  security default-keychain -s "$keychain_path"
  security set-key-partition-list -S apple-tool:,apple: -s -k temp-signing "$keychain_path"
  validate_distribution_identity "$keychain_path"

  mkdir -p "$profile_dir"
  decode_base64_to_file "$IOS_PROVISIONING_PROFILE_BASE64" "$profile_path"
  validate_provisioning_profile "$profile_path"

  write_github_env "IOS_APP_IDENTIFIER=$IOS_APP_IDENTIFIER"
}

case "$COMMAND" in
  validate-app-store-connect)
    require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
    ;;
  validate-ios-release)
    require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID IOS_SIGNING_CERT_P12_BASE64 IOS_SIGNING_CERT_PASSWORD IOS_PROVISIONING_PROFILE_BASE64
    ;;
  materialize-app-store-connect)
    materialize_app_store_connect_key
    ;;
  import-signing-assets)
    import_signing_assets
    ;;
  *)
    fail "Unknown command: $COMMAND"
    ;;
esac