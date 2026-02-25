#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_NAME="${VIBE_ENV:-dev}"
SITE_ID="${TEST_SITE_ID:-site_001}"

run_step() {
  local name="$1"
  shift
  echo ""
  echo "============================================================"
  echo "RC3 STEP: $name"
  echo "============================================================"
  "$@"
}

run_step "Role cross-link verification" node "$ROOT_DIR/scripts/verify_role_cross_links.js" --env="$ENV_NAME" --site-id="$SITE_ID" --strict
run_step "Role dashboard smoke checks" node "$ROOT_DIR/scripts/role_dashboard_smoke.js" --env="$ENV_NAME" --strict
run_step "Voice fixtures coverage" npm --prefix "$ROOT_DIR" run vibe:voice:fixtures
run_step "Voice STT smoke" npm --prefix "$ROOT_DIR" run vibe:voice:stt-smoke
run_step "Voice TTS pronunciation" npm --prefix "$ROOT_DIR" run vibe:voice:tts-pronunciation
run_step "Voice TTS prosody policy" npm --prefix "$ROOT_DIR" run vibe:voice:tts-prosody-policy
run_step "i18n API locale enforcement" npm --prefix "$ROOT_DIR" run vibe:api:locale
run_step "i18n key parity" npm --prefix "$ROOT_DIR" run vibe:i18n:keys
run_step "VIBE telemetry master audit" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:audit
run_step "VIBE telemetry blocker gate" npm --prefix "$ROOT_DIR" run qa:vibe-telemetry:blockers

echo ""
echo "✅ RC3 preflight completed successfully."
