#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"

fail() {
  echo "[apple-signing] $*" >&2
  exit 1
}

case "$MODE" in
  ios)
    "$REPO_ROOT/scripts/apple_release_local.sh" prepare_signing
    echo "[apple-signing] Prepared iOS App Store signing with the App Store Connect .p8 key."
    ;;
  macos)
    "$REPO_ROOT/scripts/apple_release_local.sh" prepare_macos_developer_id
    echo "[apple-signing] Prepared macOS Developer ID signing with the App Store Connect .p8 key."
    ;;
  *)
    fail "Unknown mode: ${MODE:-missing}. Supported modes: ios, macos. Install .p8 auth first with ./scripts/setup_app_store_connect_key.sh."
    ;;
esac
