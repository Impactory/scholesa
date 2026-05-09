#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_ENV_FILE="$REPO_ROOT/.env.google_play.local"
ANDROID_DIR="$REPO_ROOT/apps/empire_flutter/app/android"
BUNDLE_DIR="$ANDROID_DIR/vendor/bundle"
BUNDLE_APP_CONFIG="$ANDROID_DIR/.bundle"
BUNDLE_USER_HOME_DIR="$ANDROID_DIR/.bundle_home"
KEY_PROPERTIES_FILE="$ANDROID_DIR/key.properties"
COMMAND="${1:-verify_play_key}"

fail() {
  echo "[android-release] $*" >&2
  exit 1
}

require_google_play_env() {
  [[ -f "$LOCAL_ENV_FILE" ]] || {
    printf '%s\n' "Missing $LOCAL_ENV_FILE. Run ./scripts/setup_google_play_key.sh first."
    return 1
  }

  set -a
  # shellcheck disable=SC1090
  source "$LOCAL_ENV_FILE"
  set +a

  [[ -n "${GOOGLE_PLAY_JSON_KEY_PATH:-}" ]] || {
    printf '%s\n' "GOOGLE_PLAY_JSON_KEY_PATH is empty in $LOCAL_ENV_FILE."
    return 1
  }
}

require_local_android_signing_prereqs() {
  local issues=()
  local message

  if ! message="$(require_google_play_env 2>&1)"; then
    issues+=("$message")
  fi

  if [[ ! -f "$KEY_PROPERTIES_FILE" ]]; then
    issues+=("Missing $KEY_PROPERTIES_FILE. Create it locally with Android release signing values.")
  else
    local key_alias key_password store_file store_password
    key_alias="$(grep '^keyAlias=' "$KEY_PROPERTIES_FILE" | cut -d= -f2- || true)"
    key_password="$(grep '^keyPassword=' "$KEY_PROPERTIES_FILE" | cut -d= -f2- || true)"
    store_file="$(grep '^storeFile=' "$KEY_PROPERTIES_FILE" | cut -d= -f2- || true)"
    store_password="$(grep '^storePassword=' "$KEY_PROPERTIES_FILE" | cut -d= -f2- || true)"

    [[ -n "$key_alias" ]] || issues+=("keyAlias is empty in $KEY_PROPERTIES_FILE")
    [[ -n "$key_password" ]] || issues+=("keyPassword is empty in $KEY_PROPERTIES_FILE")
    [[ -n "$store_password" ]] || issues+=("storePassword is empty in $KEY_PROPERTIES_FILE")
    [[ -n "$store_file" ]] || issues+=("storeFile is empty in $KEY_PROPERTIES_FILE")

    if [[ -n "$store_file" && ! -f "$ANDROID_DIR/$store_file" ]]; then
      issues+=("Release keystore not found at $ANDROID_DIR/$store_file")
    fi
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    {
      echo "Local Android release prerequisites are incomplete:"
      printf ' - %s\n' "${issues[@]}"
      echo "Run ./scripts/android_release_local.sh verify_play_key to confirm Google Play auth, then rerun ./scripts/android_release_local.sh verify_local_release once signing is installed."
    } >&2
    exit 1
  fi
}

if [[ "$COMMAND" != "verify_local_release" ]]; then
  require_google_play_env || exit 1
fi

export ANDROID_APP_IDENTIFIER="${ANDROID_APP_IDENTIFIER:-com.scholesa.app}"
export PLAY_TRACK="${PLAY_TRACK:-internal}"
export FLUTTER_BIN="${FLUTTER_BIN:-$REPO_ROOT/apps/empire_flutter/app/.fvm/flutter_sdk/bin/flutter}"
export BUNDLE_PATH="${BUNDLE_PATH:-$BUNDLE_DIR}"
export BUNDLE_APP_CONFIG
export BUNDLE_USER_HOME="${BUNDLE_USER_HOME:-$BUNDLE_USER_HOME_DIR}"
export BUNDLE_CACHE_PATH="${BUNDLE_CACHE_PATH:-$BUNDLE_USER_HOME/cache}"

FASTLANE_LANE="$COMMAND"

case "$COMMAND" in
  verify_local_release)
    require_local_android_signing_prereqs
    FASTLANE_LANE="verify_play_key"
    ;;
  upload_internal)
    require_local_android_signing_prereqs
    ;;
esac

if [[ "$FASTLANE_LANE" != "verify_play_key" && "$FASTLANE_LANE" != "upload_internal" ]]; then
  fail "Unknown command: $COMMAND. Supported commands: verify_play_key, verify_local_release, upload_internal."
fi

cd "$ANDROID_DIR"
mkdir -p "$BUNDLE_PATH" "$BUNDLE_APP_CONFIG" "$BUNDLE_USER_HOME" "$BUNDLE_CACHE_PATH"
bundle config set --local path "$BUNDLE_PATH" >/dev/null
bundle config set --local cache_path "$BUNDLE_CACHE_PATH" >/dev/null
bundle install
bundle exec fastlane android "$FASTLANE_LANE"