#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$REPO_ROOT/apps/empire_flutter/app/android"
SOURCE_KEYSTORE_PATH="${1:-}"
KEY_ALIAS="${2:-${ANDROID_KEY_ALIAS:-}}"
DEST_KEYSTORE_PATH="${ANDROID_RELEASE_KEYSTORE_PATH:-$ANDROID_DIR/app/release-keystore.jks}"
KEY_PROPERTIES_FILE="$ANDROID_DIR/key.properties"
DEFAULT_KEY_ALIAS="scholesa_upload"

fail() {
  echo "[android-signing] $*" >&2
  exit 1
}

generate_password() {
  openssl rand -base64 48 | tr -d '\n'
}

write_key_properties() {
  local store_file="app/$(basename "$DEST_KEYSTORE_PATH")"
  cat > "$KEY_PROPERTIES_FILE" <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$store_file
EOF
  chmod 600 "$KEY_PROPERTIES_FILE"
}

install_existing_keystore() {
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

  write_key_properties

  cat <<EOF
[android-signing] Installed release keystore at: $DEST_KEYSTORE_PATH
[android-signing] Wrote local signing file: $KEY_PROPERTIES_FILE
[android-signing] Ready to run ./scripts/android_release_local.sh verify_local_release
EOF
}

generate_upload_keystore() {
  command -v keytool >/dev/null 2>&1 || fail "keytool is required to generate an Android upload keystore. Install a JDK first."
  command -v openssl >/dev/null 2>&1 || fail "openssl is required to generate local Android signing passwords."

  KEY_ALIAS="${KEY_ALIAS:-$DEFAULT_KEY_ALIAS}"
  ANDROID_KEYSTORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:-$(generate_password)}"
  ANDROID_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"

  mkdir -p "$(dirname "$DEST_KEYSTORE_PATH")"
  [[ ! -f "$DEST_KEYSTORE_PATH" ]] || fail "Refusing to overwrite existing keystore at $DEST_KEYSTORE_PATH. Move it aside or set ANDROID_RELEASE_KEYSTORE_PATH."

  keytool -genkeypair \
    -v \
    -keystore "$DEST_KEYSTORE_PATH" \
    -storepass "$ANDROID_KEYSTORE_PASSWORD" \
    -keypass "$ANDROID_KEY_PASSWORD" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Scholesa Android Upload, OU=Release, O=Scholesa, L=Bangkok, ST=Bangkok, C=TH" >/dev/null
  chmod 600 "$DEST_KEYSTORE_PATH"

  write_key_properties

  cat <<EOF
[android-signing] Generated local Android upload keystore at: $DEST_KEYSTORE_PATH
[android-signing] Wrote local signing file: $KEY_PROPERTIES_FILE
[android-signing] Back up both ignored files securely before registering this upload key with Google Play.
[android-signing] Ready to run ./scripts/android_release_local.sh verify_local_release after Google Play API credentials are installed.
EOF
}

case "$SOURCE_KEYSTORE_PATH" in
  --generate|generate)
    generate_upload_keystore
    ;;
  *)
    install_existing_keystore
    ;;
esac
