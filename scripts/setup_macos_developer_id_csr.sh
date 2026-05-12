#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET_DIR="$REPO_ROOT/.secrets/apple_signing/macos_developer_id"
DEFAULT_TEAM_ID="CEUD8LB243"
COMMAND="${1:-generate_csr}"
KEY_PATH="$SECRET_DIR/Scholesa_Developer_ID_Application.key"
CSR_PATH="$SECRET_DIR/Scholesa_Developer_ID_Application.csr"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

fail() {
  echo "[macos-developer-id] $*" >&2
  exit 1
}

load_local_apple_env() {
  local env_file="$REPO_ROOT/.env.app_store_connect.local"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

generate_csr() {
  load_local_apple_env
  local team_id="${APPLE_DEVELOPER_TEAM_ID:-$DEFAULT_TEAM_ID}"
  mkdir -p "$SECRET_DIR"
  chmod 700 "$SECRET_DIR"

  if [[ ! -f "$KEY_PATH" ]]; then
    openssl genrsa -out "$KEY_PATH" 2048 >/dev/null 2>&1
    chmod 600 "$KEY_PATH"
  fi

  openssl req -new \
    -key "$KEY_PATH" \
    -out "$CSR_PATH" \
    -subj "/CN=Scholesa Developer ID Application/OU=$team_id/O=Scholesa"

  echo "[macos-developer-id] CSR written to $CSR_PATH"
  echo "[macos-developer-id] Account Holder action required: Apple Developer -> Certificates -> Developer ID Application -> upload this CSR."
  echo "[macos-developer-id] After downloading the .cer, run: ./scripts/setup_macos_developer_id_csr.sh import_cer /path/to/developer_id.cer"
}

import_cer() {
  local cert_path="${1:-}"
  [[ -n "$cert_path" ]] || fail "Missing certificate path. Usage: ./scripts/setup_macos_developer_id_csr.sh import_cer /path/to/developer_id.cer"
  [[ -f "$cert_path" ]] || fail "Certificate file not found: $cert_path"
  [[ -f "$KEY_PATH" ]] || fail "Private key not found at $KEY_PATH. Generate the CSR on this machine first with ./scripts/setup_macos_developer_id_csr.sh generate_csr."

  security import "$KEY_PATH" -k "$KEYCHAIN_PATH" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
  security import "$cert_path" -k "$KEYCHAIN_PATH" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
  echo "[macos-developer-id] Imported Developer ID key and certificate into $KEYCHAIN_PATH."
  echo "[macos-developer-id] Verify with: security find-identity -v -p codesigning"
}

case "$COMMAND" in
  generate_csr)
    generate_csr
    ;;
  import_cer)
    import_cer "${2:-}"
    ;;
  *)
    fail "Unknown command: $COMMAND. Supported commands: generate_csr, import_cer."
    ;;
esac