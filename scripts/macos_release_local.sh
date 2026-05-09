#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
COMMAND="${1:-verify_local_release}"

fail() {
  echo "[macos-release] $*" >&2
  exit 1
}

require_developer_id_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if ! printf '%s\n' "$identities" | grep -Eq '"Developer ID Application: .*\(' ; then
    printf '%s\n' "Missing Developer ID Application signing identity with private key for macOS distribution. Install the Developer ID Application certificate for team ${APPLE_DEVELOPER_TEAM_ID:-unknown}."
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
      echo "Run ./scripts/setup_app_store_connect_key.sh to install notarization credentials, import a Developer ID Application certificate, then rerun ./scripts/macos_release_local.sh verify_local_release."
    } >&2
    exit 1
  fi
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
  *)
    fail "Unknown command: $COMMAND. Supported commands: verify_local_release, verify_notary_auth."
    ;;
esac
