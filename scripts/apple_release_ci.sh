#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
RUNNER_TEMP_DIR="${2:-${RUNNER_TEMP:-/tmp}}"

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

materialize_app_store_connect_key() {
  require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
  local key_dir="$RUNNER_TEMP_DIR/app_store_connect"
  local key_path="$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  mkdir -p "$key_dir"
  printf '%s' "$APP_STORE_CONNECT_API_KEY_P8_BASE64" | base64 --decode > "$key_path"
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

  printf '%s' "$IOS_SIGNING_CERT_P12_BASE64" | base64 --decode > "$cert_path"
  security create-keychain -p temp-signing "$keychain_path"
  security set-keychain-settings -lut 21600 "$keychain_path"
  security unlock-keychain -p temp-signing "$keychain_path"
  security import "$cert_path" -P "$IOS_SIGNING_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
  security list-keychain -d user -s "$keychain_path"
  security default-keychain -s "$keychain_path"
  security set-key-partition-list -S apple-tool:,apple: -s -k temp-signing "$keychain_path"

  mkdir -p "$profile_dir"
  printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$profile_path"
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