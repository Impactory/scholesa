#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$REPO_ROOT/apps/empire_flutter/app/android"
SOURCE_KEYSTORE_PATH="${1:-}"
KEY_ALIAS="${2:-${ANDROID_KEY_ALIAS:-}}"
DEST_KEYSTORE_PATH="${ANDROID_RELEASE_KEYSTORE_PATH:-$ANDROID_DIR/app/release-keystore.jks}"
KEY_PROPERTIES_FILE="$ANDROID_DIR/key.properties"

fail() {
  echo "[android-signing] $*" >&2
  exit 1
}

[[ -n "$SOURCE_KEYSTORE_PATH" ]] || fail "Usage: ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_PASSWORD=... ./scripts/setup_android_signing.sh /absolute/path/to/release-keystore.jks <key-alias>"
[[ -f "$SOURCE_KEYSTORE_PATH" ]] || fail "File not found: $SOURCE_KEYSTORE_PATH"
[[ -n "$KEY_ALIAS" ]] || fail "Android key alias is required as the second argument or ANDROID_KEY_ALIAS."
[[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] || fail "ANDROID_KEYSTORE_PASSWORD is required."
[[ -n "${ANDROID_KEY_PASSWORD:-}" ]] || fail "ANDROID_KEY_PASSWORD is required."

mkdir -p "$(dirname "$DEST_KEYSTORE_PATH")"
cp "$SOURCE_KEYSTORE_PATH" "$DEST_KEYSTORE_PATH"
chmod 600 "$DEST_KEYSTORE_PATH"

if command -v keytool >/dev/null 2>&1; then
  if ! keytool -list -keystore "$DEST_KEYSTORE_PATH" -storepass "$ANDROID_KEYSTORE_PASSWORD" -alias "$KEY_ALIAS" >/dev/null 2>&1; then
    fail "Keystore alias $KEY_ALIAS was not found in $DEST_KEYSTORE_PATH or the keystore password is invalid."
  fi
fi

store_file="app/$(basename "$DEST_KEYSTORE_PATH")"
cat > "$KEY_PROPERTIES_FILE" <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$store_file
EOF
chmod 600 "$KEY_PROPERTIES_FILE"

cat <<EOF
[android-signing] Installed release keystore at: $DEST_KEYSTORE_PATH
[android-signing] Wrote local signing file: $KEY_PROPERTIES_FILE
[android-signing] Ready to run ./scripts/android_release_local.sh verify_local_release
EOF
