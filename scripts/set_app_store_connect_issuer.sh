#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
ISSUER_ID="${1:-${APP_STORE_CONNECT_ISSUER_ID:-}}"

fail() {
  echo "[app-store-connect] $*" >&2
  exit 1
}

[[ -f "$LOCAL_ENV_FILE" ]] || fail "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_app_store_connect_key.sh first."
[[ -n "$ISSUER_ID" ]] || fail "Usage: ./scripts/set_app_store_connect_issuer.sh <issuer-uuid>"

if ! printf '%s' "$ISSUER_ID" | grep -Eq '^[0-9a-fA-F-]{36}$'; then
  fail "Issuer ID should look like a UUID: $ISSUER_ID"
fi

tmp_file="$(mktemp)"
awk -v issuer="$ISSUER_ID" '
  BEGIN { updated = 0 }
  /^APP_STORE_CONNECT_ISSUER_ID=/ {
    print "APP_STORE_CONNECT_ISSUER_ID=" issuer
    updated = 1
    next
  }
  { print }
  END {
    if (!updated) {
      print "APP_STORE_CONNECT_ISSUER_ID=" issuer
    }
  }
' "$LOCAL_ENV_FILE" > "$tmp_file"
mv "$tmp_file" "$LOCAL_ENV_FILE"

echo "[app-store-connect] Updated APP_STORE_CONNECT_ISSUER_ID in $LOCAL_ENV_FILE"