#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_NAME="${VIBE_ENV:-dev}"
SITE_ID="${TEST_SITE_ID:-site_001}"
FLUTTER_DIR="$ROOT_DIR/apps/empire_flutter/app"
cd "$ROOT_DIR"

run_step() {
  local name="$1"
  shift
  echo ""
  echo "============================================================"
  echo "RC3 STEP: $name"
  echo "============================================================"
  "$@"
}

run_step "Role cross-link verification" node scripts/verify_role_cross_links.js --env="$ENV_NAME" --site-id="$SITE_ID" --strict
run_step "Role dashboard smoke checks" node scripts/role_dashboard_smoke.js --env="$ENV_NAME" --strict
run_step "Web production build" npm run build
run_step "Flutter web wasm release build" bash -lc "cd '$FLUTTER_DIR' && flutter build web --release --wasm --no-tree-shake-icons"
run_step "Compliance runtime endpoint smoke" bash ./scripts/compliance_runtime_smoke.sh
run_step "Voice fixtures coverage" npm run vibe:voice:fixtures
run_step "Voice STT smoke" npm run vibe:voice:stt-smoke
run_step "Voice trace continuity" npm run vibe:voice:trace-continuity
run_step "Voice TTS pronunciation" npm run vibe:voice:tts-pronunciation
run_step "Voice TTS prosody policy" npm run vibe:voice:tts-prosody-policy
run_step "i18n API locale enforcement" npm run vibe:api:locale
run_step "i18n key parity" npm run vibe:i18n:keys
run_step "VIBE telemetry master audit" npm run qa:vibe-telemetry:audit
run_step "VIBE telemetry blocker gate" npm run qa:vibe-telemetry:blockers

echo ""
echo "✅ RC3 preflight completed successfully."
