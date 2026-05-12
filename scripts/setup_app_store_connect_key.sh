#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_KEY_PATH="${1:-}"
ISSUER_ID="${2:-}"
LOCAL_SECRET_DIR="$REPO_ROOT/.secrets/app_store_connect"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
DEFAULT_TEAM_ID="CEUD8LB243"
DEFAULT_IOS_BUNDLE_ID="com.scholesa.app"
default_flutter_bin() {
  local fvm_flutter="$REPO_ROOT/apps/empire_flutter/app/.fvm/flutter_sdk/bin/flutter"
  if [[ -x "$fvm_flutter" ]]; then
    printf '%s\n' "$fvm_flutter"
    return 0
  fi

  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return 0
  fi

  printf '%s\n' "$fvm_flutter"
}

fail() {
  echo "[app-store-connect] $*" >&2
  exit 1
}

[[ -n "$SOURCE_KEY_PATH" ]] || fail "Usage: ./scripts/setup_app_store_connect_key.sh /absolute/path/to/AuthKey_<KEYID>.p8 [issuer-id]"
[[ -f "$SOURCE_KEY_PATH" ]] || fail "File not found: $SOURCE_KEY_PATH"

SOURCE_BASENAME="$(basename "$SOURCE_KEY_PATH")"
KEY_ID="$(printf '%s' "$SOURCE_BASENAME" | sed -E 's/^AuthKey_([A-Z0-9]+)\.p8$/\1/')"

if [[ -z "$KEY_ID" || "$KEY_ID" == "$SOURCE_BASENAME" ]]; then
  fail "Unable to derive App Store Connect key ID from filename: $SOURCE_BASENAME"
fi

if [[ -n "$ISSUER_ID" ]] && ! printf '%s' "$ISSUER_ID" | grep -Eq '^[0-9a-fA-F-]{36}$'; then
  fail "Issuer ID should look like a UUID: $ISSUER_ID"
fi

mkdir -p "$LOCAL_SECRET_DIR"
DEST_KEY_PATH="$LOCAL_SECRET_DIR/$SOURCE_BASENAME"
cp "$SOURCE_KEY_PATH" "$DEST_KEY_PATH"
chmod 600 "$DEST_KEY_PATH"
FLUTTER_BIN_VALUE="$(default_flutter_bin)"

cat > "$LOCAL_ENV_FILE" <<EOF
APP_STORE_CONNECT_API_KEY_PATH=$DEST_KEY_PATH
APP_STORE_CONNECT_KEY_ID=$KEY_ID
APP_STORE_CONNECT_ISSUER_ID=$ISSUER_ID
IOS_APP_IDENTIFIER=$DEFAULT_IOS_BUNDLE_ID
APPLE_DEVELOPER_TEAM_ID=$DEFAULT_TEAM_ID
FLUTTER_BIN=$FLUTTER_BIN_VALUE
EOF

if [[ -z "$ISSUER_ID" ]]; then
  cat <<EOF
[app-store-connect] Installed key at: $DEST_KEY_PATH
[app-store-connect] Wrote local env stub: $LOCAL_ENV_FILE
[app-store-connect] Derived key id: $KEY_ID
[app-store-connect] Missing issuer id. Set APP_STORE_CONNECT_ISSUER_ID in $LOCAL_ENV_FILE after you copy it from App Store Connect.
[app-store-connect] GitHub secrets to add later:
  - APP_STORE_CONNECT_API_KEY_P8_BASE64
  - APP_STORE_CONNECT_KEY_ID
  - APP_STORE_CONNECT_ISSUER_ID
EOF
  exit 0
fi

cat <<EOF
[app-store-connect] Installed key at: $DEST_KEY_PATH
[app-store-connect] Wrote local env file: $LOCAL_ENV_FILE
[app-store-connect] Ready with key id $KEY_ID and issuer id $ISSUER_ID
EOF