#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Scholesa – Full-stack deploy script
#
# Usage:
#   ./scripts/deploy.sh              # Deploy everything (functions + rules + Cloud Run web)
#   ./scripts/deploy.sh functions    # Deploy only Cloud Functions
#   ./scripts/deploy.sh rules        # Deploy Firestore + Storage rules
#   ./scripts/deploy.sh cloudrun-web # Build Flutter web & deploy to Cloud Run
#   ./scripts/deploy.sh compliance-operator # Deploy scholesa-compliance Cloud Run service
#   ./scripts/deploy.sh flutter-web  # Alias of cloudrun-web
#   ./scripts/deploy.sh flutter-ios  # Build Flutter iOS (release)
#   ./scripts/deploy.sh flutter-macos # Build Flutter macOS app (release)
#   ./scripts/deploy.sh flutter-android # Build Flutter Android (release APK)
# ──────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/empire_flutter/app"
FUNCTIONS_DIR="$REPO_ROOT/functions"
TARGET="${1:-all}"
FLUTTER_GATE_DONE=0

export CLOUDSDK_CORE_DISABLE_PROMPTS="${CLOUDSDK_CORE_DISABLE_PROMPTS:-1}"
export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"
export COPY_EXTENDED_ATTRIBUTES_DISABLE="${COPY_EXTENDED_ATTRIBUTES_DISABLE:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $*"; }
fail() { echo -e "${RED}[deploy]${NC} $*"; exit 1; }

# ── Pre-flight checks ──────────────────────────────────────────
preflight() {
  command -v firebase >/dev/null 2>&1 || fail "firebase CLI not found. Install: npm i -g firebase-tools"
  command -v node >/dev/null 2>&1 || fail "node not found on PATH"

  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if [[ "$node_major" != "24" ]]; then
    fail "Node 24.x is required for deploy reproducibility (detected $(node -v)). Run: nvm use 24"
  fi

  if [[ "$TARGET" == flutter-* || "$TARGET" == "cloudrun-web" || "$TARGET" == "all" ]]; then
    command -v flutter >/dev/null 2>&1 || fail "flutter not found on PATH"
  fi

  if [[ "$TARGET" == "cloudrun-web" || "$TARGET" == "flutter-web" || "$TARGET" == "compliance-operator" || "$TARGET" == "all" ]]; then
    command -v gcloud >/dev/null 2>&1 || fail "gcloud not found on PATH"
  fi
}

# ── Flutter analyze + test gate ────────────────────────────────
flutter_gate() {
  sync_platform_icons

  log "Running flutter analyze..."
  (cd "$FLUTTER_APP" && flutter analyze --no-pub) || fail "flutter analyze failed — fix issues before deploying"

  log "Running flutter test..."
  (cd "$FLUTTER_APP" && flutter test) || fail "flutter tests failed — fix before deploying"

  log "Flutter gate passed ✓"
}

ensure_flutter_gate() {
  if [[ "$FLUTTER_GATE_DONE" == "1" ]]; then
    return 0
  fi

  flutter_gate
  FLUTTER_GATE_DONE=1
}

# ── Enforce platform icon sync before any Flutter build ─────────
sync_platform_icons() {
  local icon_sync_script
  icon_sync_script="$FLUTTER_APP/scripts/sync_platform_icons.sh"

  [[ -f "$icon_sync_script" ]] || fail "Icon sync script not found: $icon_sync_script"

  log "Syncing platform icons..."
  (cd "$FLUTTER_APP" && bash ./scripts/sync_platform_icons.sh) || fail "Platform icon sync failed"
  log "Platform icons synced ✓"
}

# ── Functions lint + build ─────────────────────────────────────
functions_build() {
  log "Installing functions dependencies..."
  (cd "$FUNCTIONS_DIR" && npm ci --no-audit --no-fund --no-update-notifier --loglevel=error)

  log "Building functions..."
  (cd "$FUNCTIONS_DIR" && npm run build) || fail "Functions build failed"

  log "Functions build passed ✓"
}

resolve_project_id() {
  if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
    printf '%s' "$GCP_PROJECT_ID"
    return 0
  fi

  cd "$REPO_ROOT" && firebase use --json | node -e 'let data="";process.stdin.on("data",d=>data+=d).on("end",()=>{try{const j=JSON.parse(data);process.stdout.write(j.result || "");}catch{process.stdout.write("");}})'
}

# ── Deploy targets ─────────────────────────────────────────────
deploy_functions() {
  functions_build
  log "Deploying Cloud Functions..."
  (cd "$REPO_ROOT" && firebase deploy --only functions)
  log "Functions deployed ✓"
}

deploy_rules() {
  log "Deploying Firestore rules + indexes..."
  (cd "$REPO_ROOT" && firebase deploy --only firestore)

  log "Deploying Storage rules..."
  (cd "$REPO_ROOT" && firebase deploy --only storage)

  log "Rules deployed ✓"
}

deploy_cloud_run_web() {
  ensure_flutter_gate

  local project_id
  project_id="$(resolve_project_id)"

  [[ -n "$project_id" ]] || fail "Unable to resolve GCP project ID. Set GCP_PROJECT_ID in env."

  local region service image_tag
  region="${GCP_REGION:-us-central1}"
  service="${CLOUD_RUN_SERVICE:-empire-web}"
  image_tag="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"

  log "Deploying Flutter web to Cloud Run (project=$project_id service=$service region=$region tag=$image_tag)..."
  (cd "$REPO_ROOT" && bash ./scripts/deploy-cloud-run.sh "$project_id" "$region" "$service" "$image_tag")
  log "Cloud Run web deployed ✓"
}

deploy_compliance_operator() {
  local project_id
  project_id="$(resolve_project_id)"
  [[ -n "$project_id" ]] || fail "Unable to resolve GCP project ID. Set GCP_PROJECT_ID in env."

  local region service image_tag
  region="${GCP_REGION:-us-central1}"
  service="${COMPLIANCE_RUN_SERVICE:-scholesa-compliance}"
  local root_redirect_url
  root_redirect_url="${COMPLIANCE_ROOT_REDIRECT_URL:-https://www.scholesa.com/en}"
  image_tag="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"

  log "Building compliance operator image with Cloud Build..."
  (cd "$REPO_ROOT" && gcloud builds submit --project "$project_id" --config cloudbuild.compliance.yaml --substitutions "_TAG=$image_tag")

  log "Deploying compliance operator to Cloud Run (service=$service region=$region)..."
  (cd "$REPO_ROOT" && gcloud run deploy "$service" \
    --image "gcr.io/${project_id}/scholesa-compliance:${image_tag}" \
    --project "$project_id" \
    --region "$region" \
    --platform managed \
    --no-allow-unauthenticated \
    --set-env-vars "COMPLIANCE_ALLOW_UNAUTH=0,COMPLIANCE_ROOT_REDIRECT_URL=${root_redirect_url}")

  log "Compliance operator deployed ✓"
}

deploy_flutter_web() {
  deploy_cloud_run_web
}

deploy_flutter_ios() {
  ensure_flutter_gate
  log "Building Flutter iOS (release)..."
  (cd "$FLUTTER_APP" && flutter build ios --release --no-codesign --no-tree-shake-icons)
  log "iOS build complete. Open Xcode to archive and distribute."
}

deploy_flutter_macos() {
  ensure_flutter_gate
  log "Building Flutter macOS (release)..."
  (cd "$FLUTTER_APP" && flutter build macos --release --no-tree-shake-icons)
  log "macOS build complete. Sign + notarize before distribution."
}

deploy_flutter_android() {
  ensure_flutter_gate
  log "Building Flutter Android APK (release)..."
  (cd "$FLUTTER_APP" && flutter build apk --release)
  log "Android APK: $FLUTTER_APP/build/app/outputs/flutter-apk/app-release.apk"
}

deploy_all() {
  deploy_functions
  deploy_rules
  deploy_cloud_run_web
  deploy_compliance_operator
  log "Full deploy complete ✓"
}

# ── Main ───────────────────────────────────────────────────────
preflight

case "$TARGET" in
  all)              deploy_all ;;
  functions)        deploy_functions ;;
  rules)            deploy_rules ;;
  cloudrun-web)     deploy_cloud_run_web ;;
  compliance-operator) deploy_compliance_operator ;;
  flutter-web)      deploy_flutter_web ;;
  flutter-ios)      deploy_flutter_ios ;;
  flutter-macos)    deploy_flutter_macos ;;
  flutter-android)  deploy_flutter_android ;;
  *)                fail "Unknown target: $TARGET. Use: all | functions | rules | cloudrun-web | compliance-operator | flutter-web | flutter-ios | flutter-macos | flutter-android" ;;
esac
