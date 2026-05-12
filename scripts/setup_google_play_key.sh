#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_KEY_PATH="${1:-}"
LOCAL_SECRET_DIR="$REPO_ROOT/.secrets/google_play"
LOCAL_ENV_FILE="$REPO_ROOT/.env.google_play.local"
DEFAULT_ANDROID_APP_IDENTIFIER="com.scholesa.app"
DEFAULT_PLAY_TRACK="internal"
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
  echo "[google-play] $*" >&2
  exit 1
}

[[ -n "$SOURCE_KEY_PATH" ]] || fail "Usage: ./scripts/setup_google_play_key.sh /absolute/path/to/google-play-service-account.json"
[[ -f "$SOURCE_KEY_PATH" ]] || fail "File not found: $SOURCE_KEY_PATH"

mkdir -p "$LOCAL_SECRET_DIR"
DEST_KEY_PATH="$LOCAL_SECRET_DIR/$(basename "$SOURCE_KEY_PATH")"
if [[ "$(cd "$(dirname "$SOURCE_KEY_PATH")" && pwd)/$(basename "$SOURCE_KEY_PATH")" != "$DEST_KEY_PATH" ]]; then
  cp "$SOURCE_KEY_PATH" "$DEST_KEY_PATH"
fi
chmod 600 "$DEST_KEY_PATH"
FLUTTER_BIN_VALUE="$(default_flutter_bin)"

cat > "$LOCAL_ENV_FILE" <<EOF
GOOGLE_PLAY_JSON_KEY_PATH=$DEST_KEY_PATH
ANDROID_APP_IDENTIFIER=$DEFAULT_ANDROID_APP_IDENTIFIER
PLAY_TRACK=$DEFAULT_PLAY_TRACK
FLUTTER_BIN=$FLUTTER_BIN_VALUE
EOF

cat <<EOF
[google-play] Installed key at: $DEST_KEY_PATH
[google-play] Wrote local env file: $LOCAL_ENV_FILE
[google-play] Ready to run ./scripts/android_release_local.sh verify_play_key
EOF