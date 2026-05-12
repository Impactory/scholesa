#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${1:-Impactory/scholesa}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"

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

base64 < "$APP_STORE_CONNECT_API_KEY_PATH" | tr -d '\n' | gh secret set APP_STORE_CONNECT_API_KEY_P8_BASE64 -R "$REPO_SLUG" -b-
printf '%s' "$APP_STORE_CONNECT_KEY_ID" | gh secret set APP_STORE_CONNECT_KEY_ID -R "$REPO_SLUG" -b-
printf '%s' "$APP_STORE_CONNECT_ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID -R "$REPO_SLUG" -b-
printf '%s' "$APPLE_DEVELOPER_TEAM_ID" | gh secret set APPLE_DEVELOPER_TEAM_ID -R "$REPO_SLUG" -b-

echo "[apple-gh-secrets] Updated .p8-only Apple GitHub secrets for $REPO_SLUG"