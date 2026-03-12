#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/apps/empire_flutter/app"
FUNCTIONS_DIR="$ROOT_DIR/functions"

FLUTTER_TEST_SCRIPT="${FLUTTER_TEST_SCRIPT:-}"
if [[ -z "$FLUTTER_TEST_SCRIPT" ]]; then
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    FLUTTER_TEST_SCRIPT="test:flutter:ci"
  else
    FLUTTER_TEST_SCRIPT="test:flutter:full"
  fi
fi

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
run_step "Functions install" npm --prefix "$FUNCTIONS_DIR" ci --no-audit --no-fund --no-update-notifier --loglevel=error
run_step "Functions build" npm --prefix "$FUNCTIONS_DIR" run build
run_step "COPPA regression guards" npm --prefix "$ROOT_DIR" run qa:coppa:guards
run_step "Flutter analyze" bash -lc "cd '$FLUTTER_DIR' && flutter analyze"
run_step "Flutter test" npm --prefix "$ROOT_DIR" run "$FLUTTER_TEST_SCRIPT"
run_step "Flutter web release build" bash -lc "cd '$FLUTTER_DIR' && flutter build web --release --no-tree-shake-icons --no-wasm-dry-run"
run_step "VIBE telemetry audit master" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:audit
run_step "VIBE telemetry blocker gate" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:blockers

echo ""
echo "✅ RC2 regression chain completed successfully."
