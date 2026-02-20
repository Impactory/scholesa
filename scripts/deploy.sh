#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Scholesa – Full-stack deploy script
#
# Usage:
#   ./scripts/deploy.sh              # Deploy everything (functions + rules + hosting)
#   ./scripts/deploy.sh functions    # Deploy only Cloud Functions
#   ./scripts/deploy.sh rules        # Deploy Firestore + Storage rules
#   ./scripts/deploy.sh hosting      # Deploy Firebase Hosting only
#   ./scripts/deploy.sh flutter-web  # Build Flutter web & deploy to Hosting
#   ./scripts/deploy.sh flutter-ios  # Build Flutter iOS (release)
#   ./scripts/deploy.sh flutter-android # Build Flutter Android (release APK)
# ──────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/empire_flutter/app"
FUNCTIONS_DIR="$REPO_ROOT/functions"
TARGET="${1:-all}"

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
  if [[ "$node_major" != "22" ]]; then
    fail "Node 22.x is required for deploy reproducibility (detected $(node -v)). Run: nvm use 22"
  fi

  if [[ "$TARGET" == flutter-* ]]; then
    command -v flutter >/dev/null 2>&1 || fail "flutter not found on PATH"
  fi
}

# ── Flutter analyze + test gate ────────────────────────────────
flutter_gate() {
  log "Running flutter analyze..."
  (cd "$FLUTTER_APP" && flutter analyze --no-pub) || fail "flutter analyze failed — fix issues before deploying"

  log "Running flutter test..."
  (cd "$FLUTTER_APP" && flutter test) || fail "flutter tests failed — fix before deploying"

  log "Flutter gate passed ✓"
}

# ── Functions lint + build ─────────────────────────────────────
functions_build() {
  log "Installing functions dependencies..."
  (cd "$FUNCTIONS_DIR" && npm ci)

  log "Building functions..."
  (cd "$FUNCTIONS_DIR" && npm run build) || fail "Functions build failed"

  log "Functions build passed ✓"
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

deploy_hosting() {
  log "Building Flutter web (release)..."
  (cd "$FLUTTER_APP" && flutter build web --release)

  log "Deploying Firebase Hosting..."
  (cd "$REPO_ROOT" && firebase deploy --only hosting)
  log "Hosting deployed ✓"
}

deploy_flutter_web() {
  flutter_gate
  log "Building Flutter web (release)..."
  (cd "$FLUTTER_APP" && flutter build web --release)
  log "Flutter web build complete. Output: $FLUTTER_APP/build/web"
  log "Deploying Firebase Hosting..."
  (cd "$REPO_ROOT" && firebase deploy --only hosting)
  log "Hosting deployed ✓"
}

deploy_flutter_ios() {
  flutter_gate
  log "Building Flutter iOS (release)..."
  (cd "$FLUTTER_APP" && flutter build ios --release --no-codesign)
  log "iOS build complete. Open Xcode to archive and distribute."
}

deploy_flutter_android() {
  flutter_gate
  log "Building Flutter Android APK (release)..."
  (cd "$FLUTTER_APP" && flutter build apk --release)
  log "Android APK: $FLUTTER_APP/build/app/outputs/flutter-apk/app-release.apk"
}

deploy_all() {
  flutter_gate
  deploy_functions
  deploy_rules
  deploy_hosting
  log "Full deploy complete ✓"
}

# ── Main ───────────────────────────────────────────────────────
preflight

case "$TARGET" in
  all)              deploy_all ;;
  functions)        deploy_functions ;;
  rules)            deploy_rules ;;
  hosting)          deploy_hosting ;;
  flutter-web)      deploy_flutter_web ;;
  flutter-ios)      deploy_flutter_ios ;;
  flutter-android)  deploy_flutter_android ;;
  *)                fail "Unknown target: $TARGET. Use: all | functions | rules | hosting | flutter-web | flutter-ios | flutter-android" ;;
esac
