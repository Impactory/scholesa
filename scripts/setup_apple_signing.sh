#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
MODE="${1:-}"
CERT_PATH="${2:-}"
PROFILE_PATH="${3:-}"
KEYCHAIN_PATH="${APPLE_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
PROFILE_DEST_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
PROFILE_DEST_PATH="$PROFILE_DEST_DIR/scholesa-app-store.mobileprovision"
DEFAULT_TEAM_ID="CEUD8LB243"
DEFAULT_IOS_APP_IDENTIFIER="com.scholesa.app"

fail() {
  echo "[apple-signing] $*" >&2
  exit 1
}

extract_plist_value() {
  local plist_path="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" 2>/dev/null || true
}

load_app_store_env_if_present() {
  if [[ -f "$LOCAL_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$LOCAL_ENV_FILE"
    set +a
  fi
}

validate_identity() {
  local pattern="$1"
  local message="$2"
  local identities
  identities="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null || true)"
  if ! printf '%s\n' "$identities" | grep -Eq "$pattern"; then
    fail "$message"
  fi
}

import_certificate() {
  local password="$1"
  [[ -f "$CERT_PATH" ]] || fail "Signing certificate not found at $CERT_PATH"
  [[ -n "$password" ]] || fail "Signing certificate password is required."
  [[ -f "$KEYCHAIN_PATH" ]] || fail "Keychain not found at $KEYCHAIN_PATH. Set APPLE_SIGNING_KEYCHAIN to a valid keychain path."

  security import "$CERT_PATH" -P "$password" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH" >/dev/null
}

install_ios_profile() {
  [[ -f "$PROFILE_PATH" ]] || fail "iOS provisioning profile not found at $PROFILE_PATH"

  local plist_path
  plist_path="$(mktemp)"
  security cms -D -i "$PROFILE_PATH" > "$plist_path" 2>/dev/null \
    || fail "Unable to decode provisioning profile at $PROFILE_PATH"

  local team_id ios_app_identifier expected_app_identifier application_identifier
  team_id="${APPLE_DEVELOPER_TEAM_ID:-$DEFAULT_TEAM_ID}"
  ios_app_identifier="${IOS_APP_IDENTIFIER:-$DEFAULT_IOS_APP_IDENTIFIER}"
  expected_app_identifier="$team_id.$ios_app_identifier"
  application_identifier="$(extract_plist_value "$plist_path" 'Entitlements:application-identifier')"

  rm -f "$plist_path"

  [[ "$application_identifier" == "$expected_app_identifier" ]] \
    || fail "Provisioning profile app identifier mismatch: expected $expected_app_identifier, found ${application_identifier:-missing}"

  mkdir -p "$PROFILE_DEST_DIR"
  cp "$PROFILE_PATH" "$PROFILE_DEST_PATH"
  chmod 600 "$PROFILE_DEST_PATH"
}

load_app_store_env_if_present

case "$MODE" in
  ios)
    [[ -n "$CERT_PATH" && -n "$PROFILE_PATH" ]] || fail "Usage: IOS_SIGNING_CERT_PASSWORD=... ./scripts/setup_apple_signing.sh ios /absolute/path/to/ios-distribution.p12 /absolute/path/to/profile.mobileprovision"
    import_certificate "${IOS_SIGNING_CERT_PASSWORD:-}"
    validate_identity '"(Apple|iOS) Distribution: .*\(' "Apple Distribution signing identity was not found in $KEYCHAIN_PATH after import."
    install_ios_profile
    echo "[apple-signing] Installed iOS distribution signing identity and provisioning profile."
    ;;
  macos)
    [[ -n "$CERT_PATH" ]] || fail "Usage: MACOS_DEVELOPER_ID_CERT_PASSWORD=... ./scripts/setup_apple_signing.sh macos /absolute/path/to/developer-id-application.p12"
    import_certificate "${MACOS_DEVELOPER_ID_CERT_PASSWORD:-}"
    validate_identity '"Developer ID Application: .*\(' "Developer ID Application signing identity was not found in $KEYCHAIN_PATH after import."
    echo "[apple-signing] Installed macOS Developer ID Application signing identity."
    ;;
  *)
    fail "Unknown mode: ${MODE:-missing}. Supported modes: ios, macos."
    ;;
esac
