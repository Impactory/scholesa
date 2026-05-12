#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
COMMAND="${1:-verify_local_release}"
APP_ROOT="$REPO_ROOT/apps/empire_flutter/app"
DEFAULT_APP_PATH="$APP_ROOT/build/macos/Build/Products/Release/scholesa_app.app"
DEFAULT_TEAM_ID="CEUD8LB243"
MACOS_APP_PATH="${2:-${MACOS_APP_PATH:-$DEFAULT_APP_PATH}}"
MACOS_ENTITLEMENTS_PATH="${MACOS_ENTITLEMENTS_PATH:-$APP_ROOT/macos/Runner/Release.entitlements}"
MACOS_ARCHIVE_PATH="${MACOS_ARCHIVE_PATH:-$REPO_ROOT/.tmp/scholesa-macos-notary.zip}"

fail() {
  echo "[macos-release] $*" >&2
  exit 1
}

require_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  local team_id="${APPLE_DEVELOPER_TEAM_ID:-$DEFAULT_TEAM_ID}"
  if ! printf '%s\n' "$identities" | grep -Eq '"Developer ID Application: .*\(' ; then
    printf '%s\n' "Missing Developer ID Application signing identity with private key for macOS distribution. Run ./scripts/apple_release_local.sh prepare_macos_developer_id to generate/download it with the App Store Connect .p8 key for team $team_id."
    return 1
  fi

  return 0
}

require_notary_credentials() {
  [[ -f "$LOCAL_ENV_FILE" ]] || {
    printf '%s\n' "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_app_store_connect_key.sh first."
    return 1
  }

  set -a
  # shellcheck disable=SC1090
  source "$LOCAL_ENV_FILE"
  set +a

  [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]] || {
    printf '%s\n' "APP_STORE_CONNECT_API_KEY_PATH is empty in $LOCAL_ENV_FILE."
    return 1
  }
  [[ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]] || {
    printf '%s\n' "App Store Connect API key file not found at $APP_STORE_CONNECT_API_KEY_PATH."
    return 1
  }
  [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] || {
    printf '%s\n' "APP_STORE_CONNECT_KEY_ID is empty in $LOCAL_ENV_FILE."
    return 1
  }
  [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || {
    printf '%s\n' "APP_STORE_CONNECT_ISSUER_ID is empty in $LOCAL_ENV_FILE."
    return 1
  }
}

require_local_macos_distribution_prereqs() {
  local issues=()
  local message

  if ! message="$(require_developer_id_identity 2>&1)"; then
    issues+=("$message")
  fi

  if ! message="$(require_notary_credentials 2>&1)"; then
    issues+=("$message")
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    {
      echo "Local macOS distribution prerequisites are incomplete:"
      printf ' - %s\n' "${issues[@]}"
      echo "Run ./scripts/setup_app_store_connect_key.sh to install notarization credentials, then ./scripts/apple_release_local.sh prepare_macos_developer_id to generate/download the Developer ID Application identity with the .p8 key."
    } >&2
    exit 1
  fi
}

resolve_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  if [[ -n "${APPLE_DEVELOPER_TEAM_ID:-}" ]]; then
    identity="$(printf '%s\n' "$identities" | awk -v team="$APPLE_DEVELOPER_TEAM_ID" '/"Developer ID Application: / && index($0, "(" team ")") { sub(/^.*\"/, ""); sub(/\".*$/, ""); print; exit }')"
  else
    identity="$(printf '%s\n' "$identities" | awk '/"Developer ID Application: / { sub(/^.*\"/, ""); sub(/\".*$/, ""); print; exit }')"
  fi

  [[ -n "$identity" ]] || fail "Developer ID Application signing identity is not available in the active keychain."
  printf '%s\n' "$identity"
}

sign_macos_app() {
  require_local_macos_distribution_prereqs
  [[ -d "$MACOS_APP_PATH" ]] || fail "macOS app bundle not found at $MACOS_APP_PATH. Build it with ./scripts/deploy.sh flutter-macos before signing."
  [[ -f "$MACOS_ENTITLEMENTS_PATH" ]] || fail "macOS entitlements file not found at $MACOS_ENTITLEMENTS_PATH."

  local identity
  identity="$(resolve_developer_id_identity)"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$MACOS_ENTITLEMENTS_PATH" \
    --sign "$identity" \
    "$MACOS_APP_PATH"
  codesign --verify --deep --strict --verbose=2 "$MACOS_APP_PATH"
  echo "[macos-release] Signed macOS app at $MACOS_APP_PATH."
}

notarize_and_staple_macos_app() {
  require_notary_credentials
  [[ -d "$MACOS_APP_PATH" ]] || fail "macOS app bundle not found at $MACOS_APP_PATH."
  mkdir -p "$(dirname "$MACOS_ARCHIVE_PATH")"
  rm -f "$MACOS_ARCHIVE_PATH"
  ditto -c -k --keepParent "$MACOS_APP_PATH" "$MACOS_ARCHIVE_PATH"
  xcrun notarytool submit "$MACOS_ARCHIVE_PATH" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait
  xcrun stapler staple "$MACOS_APP_PATH"
  spctl --assess --type execute --verbose=4 "$MACOS_APP_PATH"
  echo "[macos-release] Notarized and stapled macOS app at $MACOS_APP_PATH."
}

case "$COMMAND" in
  verify_local_release)
    require_local_macos_distribution_prereqs
    echo "[macos-release] Local macOS distribution prerequisites are installed."
    ;;
  verify_notary_auth)
    require_notary_credentials
    xcrun notarytool history \
      --key "$APP_STORE_CONNECT_API_KEY_PATH" \
      --key-id "$APP_STORE_CONNECT_KEY_ID" \
      --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
      --output-format json >/dev/null
    echo "[macos-release] App Store Connect notarization auth verified."
    ;;
  sign_macos_app)
    sign_macos_app
    ;;
  notarize_and_staple)
    notarize_and_staple_macos_app
    ;;
  sign_notarize_staple)
    sign_macos_app
    notarize_and_staple_macos_app
    ;;
  *)
    fail "Unknown command: $COMMAND. Supported commands: verify_local_release, verify_notary_auth, sign_macos_app, notarize_and_staple, sign_notarize_staple."
    ;;
esac
