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
MACOS_CODESIGN_PROBE_TIMEOUT_SECONDS="${MACOS_CODESIGN_PROBE_TIMEOUT_SECONDS:-20}"
MACOS_CODESIGN_TIMEOUT_SECONDS="${MACOS_CODESIGN_TIMEOUT_SECONDS:-300}"

fail() {
  echo "[macos-release] $*" >&2
  exit 1
}

run_with_timeout() {
  local timeout_seconds="$1"
  local timeout_message="$2"
  shift 2

  "$@" &
  local command_pid=$!
  local elapsed_seconds=0

  while kill -0 "$command_pid" 2>/dev/null; do
    if (( elapsed_seconds >= timeout_seconds )); then
      kill "$command_pid" 2>/dev/null || true
      wait "$command_pid" 2>/dev/null || true
      printf '%s\n' "$timeout_message" >&2
      return 124
    fi
    sleep 1
    elapsed_seconds=$((elapsed_seconds + 1))
  done

  wait "$command_pid"
}

require_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  local team_id="${APPLE_DEVELOPER_TEAM_ID:-$DEFAULT_TEAM_ID}"
  if ! printf '%s\n' "$identities" | grep -Eq '"Developer ID Application: .*\(' ; then
    printf '%s\n' "Missing Developer ID Application signing identity with private key for macOS distribution. Try ./scripts/apple_release_local.sh prepare_macos_developer_id first. If Apple reports that only the Account Holder can create Developer ID certificates, run ./scripts/setup_apple_signing.sh macos-csr and have the Account Holder create the certificate from that CSR."
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

  if ! message="$(require_codesign_private_key_access 2>&1)"; then
    issues+=("$message")
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    {
      echo "Local macOS distribution prerequisites are incomplete:"
      printf ' - %s\n' "${issues[@]}"
      echo "Run ./scripts/setup_app_store_connect_key.sh to install notarization credentials. Then run ./scripts/apple_release_local.sh prepare_macos_developer_id, or ./scripts/setup_apple_signing.sh macos-csr if Apple requires the Account Holder to create the Developer ID certificate."
    } >&2
    exit 1
  fi
}

resolve_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  if [[ -n "${APPLE_DEVELOPER_TEAM_ID:-}" ]]; then
    identity="$(printf '%s\n' "$identities" | sed -nE "/\"Developer ID Application: .*\\($APPLE_DEVELOPER_TEAM_ID\\)\"/s/^ *[0-9]+\) [A-F0-9]+ \"([^\"]+)\".*$/\1/p" | head -n 1)"
  else
    identity="$(printf '%s\n' "$identities" | sed -nE '/"Developer ID Application: /s/^ *[0-9]+\) [A-F0-9]+ "([^"]+)".*$/\1/p' | head -n 1)"
  fi

  [[ -n "$identity" ]] || fail "Developer ID Application signing identity is not available in the active keychain."
  printf '%s\n' "$identity"
}

keychain_access_message() {
  printf '%s\n' "Developer ID private-key access is blocked. Approve the Keychain Access prompt, or run security unlock-keychain ~/Library/Keychains/login.keychain-db and security set-key-partition-list -S apple-tool:,apple: -s -k <login-keychain-password> ~/Library/Keychains/login.keychain-db locally. Do not store the keychain password in repo files, shell history, CI logs, or release proof artifacts."
}

require_codesign_private_key_access() {
  local identity
  identity="$(resolve_developer_id_identity)"

  local probe_dir
  probe_dir="$(mktemp -d)"
  trap 'rm -rf "$probe_dir"' RETURN
  printf 'scholesa macos codesign probe\n' > "$probe_dir/probe.txt"

  run_with_timeout "$MACOS_CODESIGN_PROBE_TIMEOUT_SECONDS" "$(keychain_access_message)" \
    codesign --force --sign "$identity" "$probe_dir/probe.txt" >/dev/null
}

sign_macos_app() {
  require_local_macos_distribution_prereqs
  [[ -d "$MACOS_APP_PATH" ]] || fail "macOS app bundle not found at $MACOS_APP_PATH. Build it with ./scripts/deploy.sh flutter-macos before signing."
  [[ -f "$MACOS_ENTITLEMENTS_PATH" ]] || fail "macOS entitlements file not found at $MACOS_ENTITLEMENTS_PATH."

  local identity
  identity="$(resolve_developer_id_identity)"
  run_with_timeout "$MACOS_CODESIGN_TIMEOUT_SECONDS" "$(keychain_access_message)" \
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
