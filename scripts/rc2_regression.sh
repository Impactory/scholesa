#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/apps/empire_flutter/app"
FUNCTIONS_DIR="$ROOT_DIR/functions"

run_step() {
  local name="$1"
  shift
  echo ""
  echo "============================================================"
  echo "RC2 STEP: $name"
  echo "============================================================"
  "$@"
}

run_step "Web lint" npm --prefix "$ROOT_DIR" run lint
run_step "Web build" npm --prefix "$ROOT_DIR" run build
run_step "Jest rules integration" npm --prefix "$ROOT_DIR" run test:integration:rules
run_step "Jest analytics live integration" npm --prefix "$ROOT_DIR" run test:integration:analytics:live
run_step "Functions install" npm --prefix "$FUNCTIONS_DIR" ci
run_step "Functions build" npm --prefix "$FUNCTIONS_DIR" run build
run_step "Flutter analyze" bash -lc "cd '$FLUTTER_DIR' && flutter analyze"
run_step "Flutter test" bash -lc "cd '$FLUTTER_DIR' && flutter test"
run_step "Flutter web release build" bash -lc "cd '$FLUTTER_DIR' && flutter build web --release --wasm --no-tree-shake-icons"
run_step "VIBE telemetry audit master" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:audit
run_step "VIBE telemetry blocker gate" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:blockers

echo ""
echo "✅ RC2 regression chain completed successfully."
