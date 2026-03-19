#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-}"
RUNNER_TEMP_DIR="${2:-${RUNNER_TEMP:-/tmp}}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$REPO_ROOT/apps/empire_flutter/app/android"

ANDROID_APP_IDENTIFIER="${ANDROID_APP_IDENTIFIER:-com.scholesa.app}"
PLAY_TRACK="${PLAY_TRACK:-internal}"

fail() {
  echo "[android-release-ci] $*" >&2
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

validate_google_play_key_json() {
  local key_path="$1"
  node -e '
    const fs = require("fs");
    const keyPath = process.argv[1];
    const payload = JSON.parse(fs.readFileSync(keyPath, "utf8"));
    const required = ["type", "client_email", "private_key"];
    const missing = required.filter((key) => !payload[key]);
    if (payload.type !== "service_account" || missing.length > 0) {
      console.error(`Invalid Google Play service account JSON. Missing/invalid: ${missing.join(", ") || "type"}`);
      process.exit(1);
    }
  ' "$key_path" || fail "Google Play service account JSON is invalid at $key_path"
}

materialize_google_play_key() {
  require_env_values GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64
  local key_dir="$RUNNER_TEMP_DIR/google_play"
  local key_path="$key_dir/google-play-service-account.json"
  mkdir -p "$key_dir"
  decode_base64_to_file "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64" "$key_path"
  validate_google_play_key_json "$key_path"

  write_github_env "GOOGLE_PLAY_JSON_KEY_PATH=$key_path"
  write_github_env "ANDROID_APP_IDENTIFIER=$ANDROID_APP_IDENTIFIER"
  write_github_env "PLAY_TRACK=$PLAY_TRACK"
  write_github_env "FLUTTER_BIN=flutter"
}

materialize_android_signing() {
  require_env_values ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
  local keystore_path="$ANDROID_DIR/app/release-keystore.jks"
  local key_properties_path="$ANDROID_DIR/key.properties"

  mkdir -p "$ANDROID_DIR/app"
  decode_base64_to_file "$ANDROID_KEYSTORE_BASE64" "$keystore_path"

  cat > "$key_properties_path" <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=app/release-keystore.jks
EOF

  write_github_env "ANDROID_APP_IDENTIFIER=$ANDROID_APP_IDENTIFIER"
}

case "$COMMAND" in
  validate-play-store)
    require_env_values GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64
    ;;
  validate-android-release)
    require_env_values GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD
    ;;
  materialize-play-store-key)
    materialize_google_play_key
    ;;
  materialize-android-signing)
    materialize_android_signing
    ;;
  *)
    fail "Unknown command: $COMMAND"
    ;;
esac