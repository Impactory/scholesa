#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DEPLOY=1
TEMP_GCP_CREDENTIALS=""

if [[ "${1:-}" == "--no-deploy" ]]; then
  RUN_DEPLOY=0
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[flow]${NC} $*"; }
warn() { echo -e "${YELLOW}[flow]${NC} $*"; }
fail() { echo -e "${RED}[flow]${NC} $*"; exit 1; }

cleanup() {
  if [[ -n "$TEMP_GCP_CREDENTIALS" && -f "$TEMP_GCP_CREDENTIALS" ]]; then
    rm -f "$TEMP_GCP_CREDENTIALS"
  fi
}
trap cleanup EXIT

firebase_cmd() {
  if [[ -n "${FIREBASE_TOKEN:-}" ]]; then
    firebase "$@" --token "$FIREBASE_TOKEN"
  else
    firebase "$@"
  fi
}

is_service_account_json_file() {
  local candidate="${1:-}"
  [[ -n "$candidate" && -f "$candidate" ]] || return 1
  node -e '
    const fs = require("fs");
    try {
      const payload = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      process.exit(payload && payload.type === "service_account" ? 0 : 1);
    } catch {
      process.exit(1);
    }
  ' "$candidate"
}

materialize_service_account_from_env() {
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    return 0
  fi

  local raw_json="${GCP_SA_KEY_JSON:-${GOOGLE_CREDENTIALS:-}}"
  if [[ -z "$raw_json" ]]; then
    return 1
  fi

  TEMP_GCP_CREDENTIALS="$(mktemp)"
  printf '%s' "$raw_json" > "$TEMP_GCP_CREDENTIALS"
  export GOOGLE_APPLICATION_CREDENTIALS="$TEMP_GCP_CREDENTIALS"
  return 0
}

ensure_node24() {
  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if [[ "$node_major" == "24" ]]; then
    return 0
  fi

  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    nvm use 24 >/dev/null || fail "Node 24 is required. Install/use with: nvm install 24 && nvm use 24"
    node_major="$(node -p "process.versions.node.split('.')[0]")"
  fi

  [[ "$node_major" == "24" ]] || fail "Node 24.x required (detected $(node -v))"
}

ensure_firebase_auth() {
  local auth_log
  auth_log="$(mktemp)"
  if ! (cd "$REPO_ROOT" && firebase_cmd projects:list --json >"$auth_log" 2>&1); then
    cat "$auth_log" >&2
    rm -f "$auth_log"
    fail "Firebase auth invalid. Run: firebase login --reauth, or set FIREBASE_TOKEN"
  fi
  rm -f "$auth_log"
}

ensure_gcloud_auth() {
  local auth_log
  auth_log="$(mktemp)"
  materialize_service_account_from_env || true

  if ! gcloud auth print-access-token --quiet >"$auth_log" 2>&1; then
    if is_service_account_json_file "${GOOGLE_APPLICATION_CREDENTIALS:-}"; then
      if ! gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" --quiet >"$auth_log" 2>&1; then
        cat "$auth_log" >&2
        rm -f "$auth_log"
        fail "Unable to activate service account from GOOGLE_APPLICATION_CREDENTIALS/GCP_SA_KEY_JSON"
      fi
      if gcloud auth print-access-token --quiet >"$auth_log" 2>&1; then
        rm -f "$auth_log"
        return 0
      fi
    fi
  fi

  if ! gcloud auth print-access-token --quiet >"$auth_log" 2>&1; then
    cat "$auth_log" >&2
    rm -f "$auth_log"
    fail "gcloud auth invalid. Run: gcloud auth login, or set GOOGLE_APPLICATION_CREDENTIALS/GCP_SA_KEY_JSON"
  fi
  rm -f "$auth_log"
}

retry_functions_deploy() {
  local max_attempts=4
  local attempt=1

  while (( attempt <= max_attempts )); do
    local deploy_log
    deploy_log="$(mktemp)"
    log "Deploying Firebase Functions (attempt ${attempt}/${max_attempts})..."

    if (cd "$REPO_ROOT" && bash ./scripts/deploy.sh functions 2>&1 | tee "$deploy_log"); then
      rm -f "$deploy_log"
      return 0
    fi

    if grep -qi "credentials are no longer valid" "$deploy_log"; then
      cat "$deploy_log" >&2
      rm -f "$deploy_log"
      fail "Firebase auth expired mid-deploy. Run: firebase login --reauth"
    fi

    if grep -qi "quota exceeded" "$deploy_log"; then
      warn "Cloud Functions mutation quota hit; waiting 90s before retry..."
      rm -f "$deploy_log"
      sleep 90
      attempt=$((attempt + 1))
      continue
    fi

    cat "$deploy_log" >&2
    rm -f "$deploy_log"
    fail "Functions deploy failed due to non-retryable error"
  done

  fail "Functions deploy failed after ${max_attempts} attempts"
}

main() {
  local flutter_test_script="${FLUTTER_TEST_SCRIPT:-}"

  if [[ -z "$flutter_test_script" ]]; then
    if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
      flutter_test_script="test:flutter:ci"
    else
      flutter_test_script="test:flutter:full"
    fi
  fi

  ensure_node24

  log "Running Flutter suite via ${flutter_test_script}..."
  (cd "$REPO_ROOT" && npm run "$flutter_test_script")

  log "Running web production build..."
  (cd "$REPO_ROOT" && npm run build)

  if [[ "$RUN_DEPLOY" -eq 0 ]]; then
    log "Flow gates completed (deploy skipped by --no-deploy)."
    return 0
  fi

  ensure_firebase_auth
  ensure_gcloud_auth

  log "Deploying web service to Cloud Run..."
  (cd "$REPO_ROOT" && bash ./scripts/deploy.sh cloudrun-web)

  log "Deploying compliance operator to Cloud Run..."
  (cd "$REPO_ROOT" && bash ./scripts/deploy.sh compliance-operator)

  retry_functions_deploy

  log "Deploying Firestore/Storage rules..."
  (cd "$REPO_ROOT" && bash ./scripts/deploy.sh rules)

  log "Full platform flow completed successfully."
}

main "$@"
