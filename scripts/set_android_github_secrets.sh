#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${1:-Impactory/scholesa}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.google_play.local"
ANDROID_DIR="$REPO_ROOT/apps/empire_flutter/app/android"
KEY_PROPERTIES_FILE="${ANDROID_KEY_PROPERTIES_PATH:-$ANDROID_DIR/key.properties}"

fail() {
  echo "[android-gh-secrets] $*" >&2
  exit 1
}

read_key_property() {
  local key="$1"
  grep "^${key}=" "$KEY_PROPERTIES_FILE" | head -1 | cut -d= -f2- || true
}

[[ -f "$LOCAL_ENV_FILE" ]] || fail "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_google_play_key.sh first."
command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is required."

set -a
# shellcheck disable=SC1090
source "$LOCAL_ENV_FILE"
set +a

[[ -n "${GOOGLE_PLAY_JSON_KEY_PATH:-}" && -f "$GOOGLE_PLAY_JSON_KEY_PATH" ]] || fail "GOOGLE_PLAY_JSON_KEY_PATH is missing or unreadable."
[[ -f "$KEY_PROPERTIES_FILE" ]] || fail "Android key.properties not found at $KEY_PROPERTIES_FILE"

key_alias="$(read_key_property keyAlias)"
key_password="$(read_key_property keyPassword)"
store_file="$(read_key_property storeFile)"
store_password="$(read_key_property storePassword)"

[[ -n "$key_alias" ]] || fail "keyAlias is empty in $KEY_PROPERTIES_FILE"
[[ -n "$key_password" ]] || fail "keyPassword is empty in $KEY_PROPERTIES_FILE"
[[ -n "$store_file" ]] || fail "storeFile is empty in $KEY_PROPERTIES_FILE"
[[ -n "$store_password" ]] || fail "storePassword is empty in $KEY_PROPERTIES_FILE"

keystore_path="$ANDROID_DIR/$store_file"
[[ -f "$keystore_path" ]] || fail "Release keystore not found at $keystore_path"

base64 < "$GOOGLE_PLAY_JSON_KEY_PATH" | tr -d '\n' | gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 -R "$REPO_SLUG" -b-
base64 < "$keystore_path" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 -R "$REPO_SLUG" -b-
printf '%s' "$store_password" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO_SLUG" -b-
printf '%s' "$key_alias" | gh secret set ANDROID_KEY_ALIAS -R "$REPO_SLUG" -b-
printf '%s' "$key_password" | gh secret set ANDROID_KEY_PASSWORD -R "$REPO_SLUG" -b-

echo "[android-gh-secrets] Updated Android GitHub secrets for $REPO_SLUG"
