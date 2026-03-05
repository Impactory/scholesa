#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DEPLOY=1

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

ensure_node24() {
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    nvm use 24 >/dev/null || fail "Node 24 is required. Install/use with: nvm install 24 && nvm use 24"
  fi

  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  [[ "$node_major" == "24" ]] || fail "Node 24.x required (detected $(node -v))"
}

ensure_firebase_auth() {
  local auth_log
  auth_log="$(mktemp)"
  if ! (cd "$REPO_ROOT" && firebase projects:list --json >"$auth_log" 2>&1); then
    cat "$auth_log" >&2
    rm -f "$auth_log"
    fail "Firebase auth invalid. Run: firebase login --reauth"
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
  ensure_node24

  log "Running full Flutter suite..."
  (cd "$REPO_ROOT" && npm run test:flutter:full)

  log "Running web production build..."
  (cd "$REPO_ROOT" && npm run build)

  if [[ "$RUN_DEPLOY" -eq 0 ]]; then
    log "Flow gates completed (deploy skipped by --no-deploy)."
    return 0
  fi

  ensure_firebase_auth

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
