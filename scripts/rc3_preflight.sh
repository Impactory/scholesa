#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_NAME="${VIBE_ENV:-dev}"
SITE_ID="${TEST_SITE_ID:-site_001}"
FLUTTER_DIR="$ROOT_DIR/apps/empire_flutter/app"
cd "$ROOT_DIR"

resolve_local_gcloud_auth() {
  if ! command -v gcloud >/dev/null 2>&1; then
    return 0
  fi

  if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    local standard_adc="$HOME/.config/gcloud/application_default_credentials.json"
    if [[ -f "$standard_adc" ]]; then
      export GOOGLE_APPLICATION_CREDENTIALS="$standard_adc"
      echo "Using gcloud application-default ADC: $standard_adc"
    else
      local gcloud_account
      gcloud_account="$(gcloud config get-value account 2>/dev/null || true)"
      if [[ -n "$gcloud_account" ]]; then
        local legacy_adc="$HOME/.config/gcloud/legacy_credentials/${gcloud_account}/adc.json"
        if [[ -f "$legacy_adc" ]]; then
          export GOOGLE_APPLICATION_CREDENTIALS="$legacy_adc"
          echo "Using gcloud legacy ADC: $legacy_adc"
        fi
      fi
    fi
  fi

  if [[ -z "${FIREBASE_PROJECT_ID:-}" ]]; then
    local gcloud_project
    gcloud_project="$(gcloud config get-value project 2>/dev/null || true)"
    if [[ -n "$gcloud_project" && "$gcloud_project" != "(unset)" ]]; then
      export FIREBASE_PROJECT_ID="$gcloud_project"
      echo "Using gcloud project for FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID"
    fi
  fi
}

resolve_local_gcloud_auth

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
run_step "Identity artifact hygiene" node scripts/cleanup_identity_artifacts.js --strict
run_step "Login profile reconciliation" node scripts/reconcile_login_profiles.js --strict
run_step "Live Firebase role identity audit" node scripts/firebase_role_e2e_audit.js --strict
run_step "Firebase password login verification" node scripts/verify_login_profiles.js --strict
run_step "Role dashboard smoke checks" node scripts/role_dashboard_smoke.js --env="$ENV_NAME" --strict
run_step "Workflow no-mock/no-synthetic audit" npm run qa:workflow:no-mock
run_step "Web browser workflow E2E" npm run test:e2e:web
run_step "Web production build" npm run build
run_step "Flutter web wasm release build" bash -lc "cd '$FLUTTER_DIR' && flutter build web --release --wasm --no-tree-shake-icons"
run_step "Flutter CTA reflection regression" bash -lc "cd '$FLUTTER_DIR' && flutter test test/cta_reflection_test.dart"
run_step "Compliance runtime endpoint smoke" bash ./scripts/compliance_runtime_smoke.sh
run_step "COPPA regression guards" bash -lc "cd '$ROOT_DIR/functions' && npm run test:coppa"
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
