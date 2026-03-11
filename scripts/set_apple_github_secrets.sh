#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${1:-Impactory/scholesa}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
PROFILE_PATH_DEFAULT="$HOME/Library/MobileDevice/Provisioning Profiles/scholesa-app-store.mobileprovision"
PROFILE_PATH="${IOS_PROVISIONING_PROFILE_PATH:-$PROFILE_PATH_DEFAULT}"

fail() {
  echo "[apple-gh-secrets] $*" >&2
  exit 1
}

[[ -f "$LOCAL_ENV_FILE" ]] || fail "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_app_store_connect_key.sh first."
command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is required."

set -a
# shellcheck disable=SC1090
source "$LOCAL_ENV_FILE"
set +a

[[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" && -f "$APP_STORE_CONNECT_API_KEY_PATH" ]] || fail "APP_STORE_CONNECT_API_KEY_PATH is missing or unreadable."
[[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] || fail "APP_STORE_CONNECT_KEY_ID is missing in $LOCAL_ENV_FILE."
[[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || fail "APP_STORE_CONNECT_ISSUER_ID is missing in $LOCAL_ENV_FILE."
[[ -n "${APPLE_DEVELOPER_TEAM_ID:-}" ]] || fail "APPLE_DEVELOPER_TEAM_ID is missing in $LOCAL_ENV_FILE."
[[ -f "$PROFILE_PATH" ]] || fail "Provisioning profile not found at $PROFILE_PATH"

base64 < "$APP_STORE_CONNECT_API_KEY_PATH" | tr -d '\n' | gh secret set APP_STORE_CONNECT_API_KEY_P8_BASE64 -R "$REPO_SLUG" -b-
printf '%s' "$APP_STORE_CONNECT_KEY_ID" | gh secret set APP_STORE_CONNECT_KEY_ID -R "$REPO_SLUG" -b-
printf '%s' "$APP_STORE_CONNECT_ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID -R "$REPO_SLUG" -b-
printf '%s' "$APPLE_DEVELOPER_TEAM_ID" | gh secret set APPLE_DEVELOPER_TEAM_ID -R "$REPO_SLUG" -b-
base64 < "$PROFILE_PATH" | tr -d '\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64 -R "$REPO_SLUG" -b-

if [[ -n "${IOS_SIGNING_CERT_P12_PATH:-}" ]]; then
  [[ -f "$IOS_SIGNING_CERT_P12_PATH" ]] || fail "IOS_SIGNING_CERT_P12_PATH is set but the file does not exist: $IOS_SIGNING_CERT_P12_PATH"
  [[ -n "${IOS_SIGNING_CERT_PASSWORD:-}" ]] || fail "IOS_SIGNING_CERT_PASSWORD is required when IOS_SIGNING_CERT_P12_PATH is set."
  base64 < "$IOS_SIGNING_CERT_P12_PATH" | tr -d '\n' | gh secret set IOS_SIGNING_CERT_P12_BASE64 -R "$REPO_SLUG" -b-
  printf '%s' "$IOS_SIGNING_CERT_PASSWORD" | gh secret set IOS_SIGNING_CERT_PASSWORD -R "$REPO_SLUG" -b-
fi

echo "[apple-gh-secrets] Updated Apple GitHub secrets for $REPO_SLUG"