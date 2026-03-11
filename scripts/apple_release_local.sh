#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.app_store_connect.local"
IOS_DIR="$REPO_ROOT/apps/empire_flutter/app/ios"
BUNDLE_DIR="$IOS_DIR/vendor/bundle"
BUNDLE_APP_CONFIG="$IOS_DIR/.bundle"
LANE="${1:-verify_api_key}"

fail() {
  echo "[apple-release] $*" >&2
  exit 1
}

[[ -f "$LOCAL_ENV_FILE" ]] || fail "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_app_store_connect_key.sh first."

set -a
# shellcheck disable=SC1090
source "$LOCAL_ENV_FILE"
set +a

export IOS_APP_IDENTIFIER="${IOS_APP_IDENTIFIER:-com.scholesa.app}"
export APPLE_DEVELOPER_TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:-CEUD8LB243}"
export FLUTTER_BIN="${FLUTTER_BIN:-$REPO_ROOT/apps/empire_flutter/app/.fvm/flutter_sdk/bin/flutter}"
export BUNDLE_PATH="${BUNDLE_PATH:-$BUNDLE_DIR}"
export BUNDLE_APP_CONFIG

[[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || fail "APP_STORE_CONNECT_ISSUER_ID is empty in $LOCAL_ENV_FILE. Add the issuer UUID from App Store Connect -> Users and Access -> Keys."

cd "$IOS_DIR"
mkdir -p "$BUNDLE_PATH" "$BUNDLE_APP_CONFIG"
bundle install
bundle exec fastlane ios "$LANE"