#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
RUNNER_TEMP_DIR="${2:-${RUNNER_TEMP:-/tmp}}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
APP_ROOT="$REPO_ROOT/apps/empire_flutter/app"
DEFAULT_APP_PATH="$APP_ROOT/build/macos/Build/Products/Release/scholesa_app.app"
MACOS_APP_PATH="${MACOS_APP_PATH:-$DEFAULT_APP_PATH}"
MACOS_ENTITLEMENTS_PATH="${MACOS_ENTITLEMENTS_PATH:-$APP_ROOT/macos/Runner/Release.entitlements}"
MACOS_ARCHIVE_PATH="${MACOS_ARCHIVE_PATH:-$RUNNER_TEMP_DIR/scholesa-macos.zip}"

fail() {
  echo "[macos-release-ci] $*" >&2
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
  [[ -n "${GITHUB_ENV:-}" ]] || return 0
  printf '%s\n' "$1" >> "$GITHUB_ENV"
}

decode_base64_to_file() {
  local payload="$1"
  local destination="$2"
  if ! printf '%s' "$payload" | base64 --decode > "$destination" 2>/dev/null && \
    ! printf '%s' "$payload" | base64 -D > "$destination" 2>/dev/null; then
    fail "Unable to decode base64 payload into $destination"
  fi
}

resolve_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  if [[ -n "${APPLE_DEVELOPER_TEAM_ID:-}" ]]; then
    identity="$(printf '%s\n' "$identities" | awk -v team="$APPLE_DEVELOPER_TEAM_ID" '/"Developer ID Application: / && index($0, "(" team ")") { sub(/^.*\"/, ""); sub(/\".*$/, ""); print; exit }')"
  else
    identity="$(printf '%s\n' "$identities" | awk '/"Developer ID Application: / { sub(/^.*\"/, ""); sub(/\".*$/, ""); print; exit }')"
  fi

  [[ -n "$identity" ]] || fail "Developer ID Application signing identity is not available in the active keychain."
  printf '%s\n' "$identity"
}

materialize_app_store_connect_key() {
  require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
  local key_dir="$RUNNER_TEMP_DIR/app_store_connect"
  local key_path="$key_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  mkdir -p "$key_dir"
  decode_base64_to_file "$APP_STORE_CONNECT_API_KEY_P8_BASE64" "$key_path"
  chmod 600 "$key_path"

  cat > "$LOCAL_ENV_FILE" <<EOF
APP_STORE_CONNECT_API_KEY_PATH=$key_path
APP_STORE_CONNECT_KEY_ID=$APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID=$APP_STORE_CONNECT_ISSUER_ID
APPLE_DEVELOPER_TEAM_ID=$APPLE_DEVELOPER_TEAM_ID
FLUTTER_BIN=flutter
EOF

  write_github_env "APP_STORE_CONNECT_API_KEY_PATH=$key_path"
  write_github_env "APP_STORE_CONNECT_KEY_ID=$APP_STORE_CONNECT_KEY_ID"
  write_github_env "APP_STORE_CONNECT_ISSUER_ID=$APP_STORE_CONNECT_ISSUER_ID"
  write_github_env "APPLE_DEVELOPER_TEAM_ID=$APPLE_DEVELOPER_TEAM_ID"
}

import_developer_id_certificate() {
  require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
  [[ -f "$LOCAL_ENV_FILE" ]] || materialize_app_store_connect_key
  "$REPO_ROOT/scripts/apple_release_local.sh" prepare_macos_developer_id
}

verify_notary_auth() {
  require_env_values APP_STORE_CONNECT_API_KEY_PATH APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID
  xcrun notarytool history \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --output-format json >/dev/null
}

sign_macos_app() {
  [[ -d "$MACOS_APP_PATH" ]] || fail "macOS app bundle not found at $MACOS_APP_PATH. Build it before signing."
  [[ -f "$MACOS_ENTITLEMENTS_PATH" ]] || fail "macOS entitlements file not found at $MACOS_ENTITLEMENTS_PATH."

  local identity
  identity="$(resolve_developer_id_identity)"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$MACOS_ENTITLEMENTS_PATH" \
    --sign "$identity" \
    "$MACOS_APP_PATH"
  codesign --verify --deep --strict --verbose=2 "$MACOS_APP_PATH"
}

notarize_and_staple_macos_app() {
  verify_notary_auth
  rm -f "$MACOS_ARCHIVE_PATH"
  ditto -c -k --keepParent "$MACOS_APP_PATH" "$MACOS_ARCHIVE_PATH"
  xcrun notarytool submit "$MACOS_ARCHIVE_PATH" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait
  xcrun stapler staple "$MACOS_APP_PATH"
  spctl --assess --type execute --verbose=4 "$MACOS_APP_PATH"
}

case "$COMMAND" in
  validate-macos-release)
    require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
    ;;
  materialize-app-store-connect)
    materialize_app_store_connect_key
    ;;
  import-developer-id-certificate)
    import_developer_id_certificate
    ;;
  verify-notary-auth)
    verify_notary_auth
    ;;
  sign-macos-app)
    sign_macos_app
    ;;
  notarize-and-staple)
    notarize_and_staple_macos_app
    ;;
  sign-notarize-staple)
    sign_macos_app
    notarize_and_staple_macos_app
    ;;
  *)
    fail "Unknown command: $COMMAND"
    ;;
esac
