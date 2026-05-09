#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/scholesa-native-distribution-readiness"
mkdir -p "$TMP_DIR"

failures=0

run_check() {
  local label="$1"
  local command="$2"
  local log_file="$TMP_DIR/${label// /_}.log"

  echo "[native-readiness] Checking $label..."
  if (cd "$REPO_ROOT" && eval "$command") > "$log_file" 2>&1; then
    echo "[native-readiness] PASS $label"
  else
    failures=$((failures + 1))
    echo "[native-readiness] BLOCKED $label"
    sed 's/^/  /' "$log_file"
  fi
}

run_check "iOS TestFlight local distribution" "./scripts/apple_release_local.sh verify_local_release"
run_check "Android Play local distribution" "./scripts/android_release_local.sh verify_local_release"
run_check "macOS Developer ID notarization" "./scripts/macos_release_local.sh verify_local_release"

if [[ "$failures" -gt 0 ]]; then
  cat <<EOF
[native-readiness] Native-channel distribution is not gold-ready.
[native-readiness] Blocked checks: $failures
[native-readiness] Install the missing external signing/store assets, rerun this script, then capture live TestFlight, Google Play internal, and macOS notarization proof before claiming native-channel Gold.
EOF
  exit 1
fi

cat <<EOF
[native-readiness] Native-channel local distribution prerequisites are installed.
[native-readiness] Next required proof: live TestFlight upload, Google Play internal upload, and macOS notarization/stapling.
EOF
