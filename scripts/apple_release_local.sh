#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
IOS_DIR="$REPO_ROOT/apps/empire_flutter/app/ios"
BUNDLE_DIR="$IOS_DIR/vendor/bundle"
BUNDLE_APP_CONFIG="$IOS_DIR/.bundle"
COMMAND="${1:-verify_api_key}"

fail() {
  echo "[apple-release] $*" >&2
  exit 1
}

require_app_store_connect_env() {
  [[ -f "$LOCAL_ENV_FILE" ]] || {
    printf '%s\n' "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_app_store_connect_key.sh first."
    return 1
  }

  set -a
  # shellcheck disable=SC1090
  source "$LOCAL_ENV_FILE"
  set +a

  [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || {
    printf '%s\n' "APP_STORE_CONNECT_ISSUER_ID is empty in $LOCAL_ENV_FILE. Add the issuer UUID from App Store Connect -> Users and Access -> Keys."
    return 1
  }
}

require_local_ios_distribution_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if ! printf '%s\n' "$identities" | grep -Eq '"(Apple|iOS) Distribution: .*\(' ; then
    printf '%s\n' "Missing Apple Distribution signing identity with private key for iOS archive/TestFlight upload. Import the iOS distribution .p12 for team ${APPLE_DEVELOPER_TEAM_ID:-unknown}."
    return 1
  fi

  return 0
}

require_local_provisioning_profile() {
  local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"

  if [[ ! -d "$profile_dir" ]] || ! find "$profile_dir" -maxdepth 1 -name '*.mobileprovision' -print -quit | grep -q .; then
    printf '%s\n' "Missing local iOS provisioning profile. Install the App Store provisioning profile for ${IOS_APP_IDENTIFIER:-com.scholesa.app} into $profile_dir."
    return 1
  fi

  return 0
}

require_local_ios_distribution_prereqs() {
  local issues=()
  local message

  if ! message="$(require_app_store_connect_env 2>&1)"; then
    issues+=("$message")
  fi

  if ! message="$(require_local_ios_distribution_identity 2>&1)"; then
    issues+=("$message")
  fi

  if ! message="$(require_local_provisioning_profile 2>&1)"; then
    issues+=("$message")
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    {
      echo "Local iOS distribution prerequisites are incomplete:"
      printf ' - %s\n' "${issues[@]}"
      echo "Run ./scripts/apple_release_local.sh verify_api_key to confirm App Store Connect auth, then rerun ./scripts/apple_release_local.sh verify_local_release once the signing assets are installed."
    } >&2
    exit 1
  fi
}

if [[ "$COMMAND" != "verify_local_release" ]]; then
  require_app_store_connect_env || exit 1
fi

export IOS_APP_IDENTIFIER="${IOS_APP_IDENTIFIER:-com.scholesa.app}"
export APPLE_DEVELOPER_TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:-CEUD8LB243}"
export FLUTTER_BIN="${FLUTTER_BIN:-$REPO_ROOT/apps/empire_flutter/app/.fvm/flutter_sdk/bin/flutter}"
export BUNDLE_PATH="${BUNDLE_PATH:-$BUNDLE_DIR}"
export BUNDLE_APP_CONFIG

FASTLANE_LANE="$COMMAND"

case "$COMMAND" in
  verify_local_release)
    require_local_ios_distribution_prereqs
    FASTLANE_LANE="verify_api_key"
    ;;
  upload_testflight)
    require_local_ios_distribution_prereqs
    ;;
esac

if [[ "$FASTLANE_LANE" != "verify_api_key" && "$FASTLANE_LANE" != "upload_testflight" ]]; then
  fail "Unknown command: $COMMAND. Supported commands: verify_api_key, verify_local_release, upload_testflight."
fi

cd "$IOS_DIR"
mkdir -p "$BUNDLE_PATH" "$BUNDLE_APP_CONFIG"
bundle install
bundle exec fastlane ios "$FASTLANE_LANE"