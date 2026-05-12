#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
RUNNER_TEMP_DIR="${2:-${RUNNER_TEMP:-/tmp}}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"

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
IOS_APP_IDENTIFIER=$IOS_APP_IDENTIFIER
APPLE_DEVELOPER_TEAM_ID=$APPLE_DEVELOPER_TEAM_ID
FLUTTER_BIN=flutter
EOF

  write_github_env "APP_STORE_CONNECT_API_KEY_PATH=$key_path"
  write_github_env "APP_STORE_CONNECT_KEY_ID=$APP_STORE_CONNECT_KEY_ID"
  write_github_env "APP_STORE_CONNECT_ISSUER_ID=$APP_STORE_CONNECT_ISSUER_ID"
  write_github_env "IOS_APP_IDENTIFIER=com.scholesa.app"
  write_github_env "APPLE_DEVELOPER_TEAM_ID=$APPLE_DEVELOPER_TEAM_ID"
  write_github_env "FLUTTER_BIN=flutter"
}

import_signing_assets() {
  require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
  [[ -f "$LOCAL_ENV_FILE" ]] || materialize_app_store_connect_key
  "$REPO_ROOT/scripts/apple_release_local.sh" prepare_signing
}

case "$COMMAND" in
  validate-app-store-connect)
    require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
    ;;
  validate-ios-release)
    require_env_values APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8_BASE64 APPLE_DEVELOPER_TEAM_ID
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