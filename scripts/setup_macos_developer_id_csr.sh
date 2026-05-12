#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET_DIR="$REPO_ROOT/.secrets/apple_signing/macos_developer_id"
DEFAULT_TEAM_ID="CEUD8LB243"
COMMAND="${1:-generate_csr}"
KEY_PATH="$SECRET_DIR/Scholesa_Developer_ID_Application.key"
CSR_PATH="$SECRET_DIR/Scholesa_Developer_ID_Application.csr"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$SECRET_DIR/scholesa-release.keychain-db}"
KEYCHAIN_PASSWORD_FILE="${KEYCHAIN_PASSWORD_FILE:-$SECRET_DIR/scholesa-release.keychain.pass}"
INTERMEDIATE_DIR="$SECRET_DIR/intermediates"

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

prepare_keychain() {
  mkdir -p "$(dirname "$KEYCHAIN_PATH")"

  if [[ "$KEYCHAIN_PATH" == "$SECRET_DIR"/* ]]; then
    if [[ ! -f "$KEYCHAIN_PASSWORD_FILE" ]]; then
      openssl rand -hex 24 > "$KEYCHAIN_PASSWORD_FILE"
      chmod 600 "$KEYCHAIN_PASSWORD_FILE"
    fi

    local keychain_password
    keychain_password="$(cat "$KEYCHAIN_PASSWORD_FILE")"

    if [[ ! -f "$KEYCHAIN_PATH" ]]; then
      security create-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
    fi

    security unlock-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  fi
}

add_keychain_to_search_list() {
  local existing_keychains=()
  local found="false"
  local keychain

  while IFS= read -r keychain; do
    keychain="${keychain//\"/}"
    keychain="${keychain#${keychain%%[![:space:]]*}}"
    [[ -n "$keychain" ]] || continue
    existing_keychains+=("$keychain")
    [[ "$keychain" == "$KEYCHAIN_PATH" ]] && found="true"
  done < <(security list-keychains -d user)

  if [[ "$found" != "true" ]]; then
    security list-keychains -d user -s "$KEYCHAIN_PATH" "${existing_keychains[@]}"
  fi
}

install_developer_id_intermediates() {
  mkdir -p "$INTERMEDIATE_DIR"
  local url file
  for url in \
    "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer" \
    "https://www.apple.com/certificateauthority/DeveloperIDCA.cer"; do
    file="$INTERMEDIATE_DIR/$(basename "$url")"
    curl -fsSL "$url" -o "$file"
    security add-certificates -k "$KEYCHAIN_PATH" "$file" >/dev/null 2>&1 || true
  done
}

import_with_temporary_pkcs12() {
  local cert_path="$1"
  local cert_pem="$SECRET_DIR/Developer_ID_Application.pem"
  local tmp_p12="$SECRET_DIR/.tmp-developer-id-import.p12"
  local p12_password
  p12_password="$(openssl rand -hex 16)"

  rm -f "$tmp_p12"
  trap 'rm -f "$tmp_p12"' RETURN

  openssl x509 -in "$cert_path" -inform DER -out "$cert_pem" 2>/dev/null || \
    openssl x509 -in "$cert_path" -out "$cert_pem"
  chmod 600 "$cert_pem"

  openssl pkcs12 -legacy \
    -export \
    -inkey "$KEY_PATH" \
    -in "$cert_pem" \
    -name "Developer ID Application: Simon Luke ($DEFAULT_TEAM_ID)" \
    -out "$tmp_p12" \
    -passout "pass:$p12_password" >/dev/null

  security import "$tmp_p12" \
    -k "$KEYCHAIN_PATH" \
    -P "$p12_password" \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null 2>&1 || true

  if [[ "$KEYCHAIN_PATH" == "$SECRET_DIR"/* ]]; then
    local keychain_password
    keychain_password="$(cat "$KEYCHAIN_PASSWORD_FILE")"
    security set-key-partition-list \
      -S apple-tool:,apple: \
      -s \
      -k "$keychain_password" \
      "$KEYCHAIN_PATH" >/dev/null
  fi
}

import_cer() {
  local cert_path="${1:-}"
  [[ -n "$cert_path" ]] || fail "Missing certificate path. Usage: ./scripts/setup_macos_developer_id_csr.sh import_cer /path/to/developer_id.cer"
  [[ -f "$cert_path" ]] || fail "Certificate file not found: $cert_path"
  [[ -f "$KEY_PATH" ]] || fail "Private key not found at $KEY_PATH. Generate the CSR on this machine first with ./scripts/setup_macos_developer_id_csr.sh generate_csr."

  prepare_keychain
  import_with_temporary_pkcs12 "$cert_path"
  install_developer_id_intermediates
  add_keychain_to_search_list

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