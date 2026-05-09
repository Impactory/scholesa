#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Scholesa – Full-stack deploy script
#
# Usage:
#   ./scripts/deploy.sh              # Deploy everything (functions + rules + primary web + Flutter web)
#   ./scripts/deploy.sh functions    # Deploy only Cloud Functions
#   ./scripts/deploy.sh rules        # Deploy Firestore + Storage rules
#   ./scripts/deploy.sh web          # Deploy both Cloud Run web surfaces (primary web + Flutter web)
#   ./scripts/deploy.sh web wasm      # Same as 'web' (WASM build is default for Flutter web)
#   ./scripts/deploy.sh cloudrun-web  # Alias of web
#   ./scripts/deploy.sh primary-web  # Build root web app & deploy to primary Cloud Run
#   ./scripts/deploy.sh compliance-operator # Deploy scholesa-compliance Cloud Run service
#   ./scripts/deploy.sh flutter-web  # Build Flutter web & deploy to Flutter Cloud Run
#   ./scripts/deploy.sh flutter-ios  # Build Flutter iOS (release)
#   ./scripts/deploy.sh flutter-macos # Build Flutter macOS app (release)
#   ./scripts/deploy.sh flutter-android # Build Flutter Android release bundle + APK
#   ./scripts/deploy.sh release-gate # Run non-deploying release reproducibility gates
# ──────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/empire_flutter/app"
FUNCTIONS_DIR="$REPO_ROOT/functions"
FVM_FLUTTER="$FLUTTER_APP/.fvm/flutter_sdk/bin/flutter"
TARGET="${1:-all}"
SHIFT_ARGS="${*:2}"
FLUTTER_GATE_DONE=0
TEMP_GCP_CREDENTIALS=""
NO_TRAFFIC_DEPLOY="${CLOUD_RUN_NO_TRAFFIC:-0}"

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

append_no_traffic_arg() {
  local array_name="$1"
  if [[ "$NO_TRAFFIC_DEPLOY" == "1" || "$NO_TRAFFIC_DEPLOY" == "true" ]]; then
    eval "$array_name+=(--no-traffic)"
  fi
}

ensure_no_traffic_service_exists() {
  local project_id="$1"
  local region="$2"
  local service="$3"

  if [[ "$NO_TRAFFIC_DEPLOY" != "1" && "$NO_TRAFFIC_DEPLOY" != "true" ]]; then
    return 0
  fi

  if gcloud run services describe "$service" \
    --project "$project_id" \
    --region "$region" \
    --format='value(metadata.name)' >/dev/null 2>&1; then
    return 0
  fi

  fail "Cloud Run service '$service' does not exist in project '$project_id' region '$region'. Cloud Run does not support --no-traffic on first deploy; create the service once without CLOUD_RUN_NO_TRAFFIC=1, then rerun the rehearsal."
}

tag_no_traffic_rehearsal_revision() {
  local project_id="$1"
  local region="$2"
  local service="$3"

  if [[ "$NO_TRAFFIC_DEPLOY" != "1" && "$NO_TRAFFIC_DEPLOY" != "true" ]]; then
    return 0
  fi

  local rehearsal_tag="${CLOUD_RUN_REHEARSAL_TAG-gold-rehearsal}"
  if [[ -z "$rehearsal_tag" ]]; then
    warn "Skipping rehearsal tag update because CLOUD_RUN_REHEARSAL_TAG is empty."
    return 0
  fi

  local latest_created_revision
  latest_created_revision="$(gcloud run services describe "$service" \
    --project "$project_id" \
    --region "$region" \
    --format='value(status.latestCreatedRevisionName)')" || fail "Unable to read latest Cloud Run revision for $service"

  [[ -n "$latest_created_revision" ]] || fail "Cloud Run service '$service' did not report a latest created revision."

  log "Tagging no-traffic revision $latest_created_revision as $rehearsal_tag for $service..."
  gcloud run services update-traffic "$service" \
    --quiet \
    --project "$project_id" \
    --region "$region" \
    --platform managed \
    --update-tags "$rehearsal_tag=$latest_created_revision" || fail "Unable to tag no-traffic rehearsal revision for $service"
}

flutter_cmd() {
  if [[ -x "$FVM_FLUTTER" ]]; then
    "$FVM_FLUTTER" "$@"
    return
  fi

  command -v flutter >/dev/null 2>&1 || fail "flutter not found on PATH and FVM SDK missing at $FVM_FLUTTER"
  flutter "$@"
}

require_android_sdk() {
  local sdk_dir="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"

  if [[ -z "$sdk_dir" && -d "$HOME/Library/Android/sdk" ]]; then
    sdk_dir="$HOME/Library/Android/sdk"
  elif [[ -z "$sdk_dir" && -d "/opt/homebrew/share/android-commandlinetools" ]]; then
    sdk_dir="/opt/homebrew/share/android-commandlinetools"
  elif [[ -z "$sdk_dir" && -d "/usr/local/share/android-commandlinetools" ]]; then
    sdk_dir="/usr/local/share/android-commandlinetools"
  fi

  if [[ -n "$sdk_dir" ]]; then
    export ANDROID_HOME="$sdk_dir"
    export ANDROID_SDK_ROOT="$sdk_dir"
  fi

  [[ -n "$sdk_dir" ]] || fail "Android SDK not found. Install Android Studio command-line tools or set ANDROID_HOME before running ./scripts/deploy.sh flutter-android."
  [[ -d "$sdk_dir" ]] || fail "Android SDK directory not found at $sdk_dir. Set ANDROID_HOME to a valid Android SDK path before running ./scripts/deploy.sh flutter-android."
}

cleanup() {
  if [[ -n "$TEMP_GCP_CREDENTIALS" && -f "$TEMP_GCP_CREDENTIALS" ]]; then
    rm -f "$TEMP_GCP_CREDENTIALS"
  fi
}
trap cleanup EXIT

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

ensure_gcloud_auth() {
  if gcloud auth print-access-token --quiet >/dev/null 2>&1; then
    return 0
  fi

  materialize_service_account_from_env || true

  if is_service_account_json_file "${GOOGLE_APPLICATION_CREDENTIALS:-}"; then
    gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" --quiet >/dev/null 2>&1 \
      || fail "Unable to activate service account from GOOGLE_APPLICATION_CREDENTIALS/GCP_SA_KEY_JSON."
    gcloud auth print-access-token --quiet >/dev/null 2>&1 \
      || fail "gcloud service-account auth is configured but access token minting still failed."
    return 0
  fi

  fail "gcloud auth invalid. Run: gcloud auth login, or set GOOGLE_APPLICATION_CREDENTIALS/GCP_SA_KEY_JSON."
}

firebase_cmd() {
  if [[ -n "${FIREBASE_TOKEN:-}" ]]; then
    firebase "$@" --token "$FIREBASE_TOKEN"
  else
    firebase "$@"
  fi
}

ensure_firebase_auth() {
  if firebase_cmd projects:list --json >/dev/null 2>&1; then
    return 0
  fi

  fail "Firebase auth invalid. Run: firebase login --reauth, or set FIREBASE_TOKEN."
}

# ── Pre-flight checks ──────────────────────────────────────────
preflight() {
  command -v firebase >/dev/null 2>&1 || fail "firebase CLI not found. Install: npm i -g firebase-tools"
  command -v node >/dev/null 2>&1 || fail "node not found on PATH"

  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if [[ "$node_major" != "24" ]]; then
    fail "Node 24.x is required for deploy reproducibility (detected $(node -v)). Run: nvm use 24"
  fi

  if [[ "$TARGET" == flutter-* || "$TARGET" == "web" || "$TARGET" == "cloudrun-web" || "$TARGET" == "all" || "$TARGET" == "release-gate" ]]; then
    if [[ ! -x "$FVM_FLUTTER" ]]; then
      command -v flutter >/dev/null 2>&1 || fail "flutter not found on PATH and FVM SDK missing at $FVM_FLUTTER"
    fi
  fi

  if [[ "$TARGET" == "release-gate" ]]; then
    command -v java >/dev/null 2>&1 || fail "java not found on PATH; Firestore emulator rules tests require a Java runtime"
  fi

  if [[ "$TARGET" == "primary-web" || "$TARGET" == "web" || "$TARGET" == "cloudrun-web" || "$TARGET" == "flutter-web" || "$TARGET" == "compliance-operator" || "$TARGET" == "all" ]]; then
    command -v gcloud >/dev/null 2>&1 || fail "gcloud not found on PATH"
    ensure_gcloud_auth
  fi

  if [[ "$TARGET" == "functions" || "$TARGET" == "rules" || "$TARGET" == "all" ]]; then
    ensure_firebase_auth
  fi
}

# ── Flutter analyze + test gate ────────────────────────────────
flutter_gate() {
  sync_platform_icons

  log "Running flutter analyze..."
  (cd "$FLUTTER_APP" && flutter_cmd analyze --no-pub --no-fatal-infos) || fail "flutter analyze failed — fix issues before deploying"

  log "Running flutter test..."
  (cd "$FLUTTER_APP" && flutter_cmd test) || fail "flutter tests failed — fix before deploying"

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

  log "Verifying Functions Gen 2 baseline..."
  (cd "$FUNCTIONS_DIR" && npm run verify:gen2) || fail "Functions Gen 2 verification failed"

  log "Functions build passed ✓"
}

functions_unit_tests() {
  local function_tests=()
  while IFS= read -r test_file; do
    function_tests+=("$test_file")
  done < <(cd "$FUNCTIONS_DIR" && find src -name '*.test.ts' ! -name 'evidenceChainEmulator.test.ts' | sort)

  if [[ ${#function_tests[@]} -eq 0 ]]; then
    fail "No non-emulator Functions test files found"
  fi

  log "Running Functions unit tests (${#function_tests[@]} files)..."
  (cd "$FUNCTIONS_DIR" && npm run test -- --runInBand "${function_tests[@]}") || fail "Functions unit tests failed"
  log "Functions unit tests passed ✓"
}

release_gate_emulator_tests() {
  log "Running Firestore rules and evidence-chain emulator tests..."
  (cd "$REPO_ROOT" && npx --yes firebase-tools emulators:exec --only firestore \
    "FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx jest --runInBand --config jest.rules.config.js && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm --prefix functions run test -- --runInBand src/evidenceChainEmulator.test.ts") \
    || fail "Firestore emulator release tests failed"
  log "Firestore emulator release tests passed ✓"
}

release_gate() {
  log "Running non-deploying release reproducibility gate..."

  log "Running root typecheck..."
  (cd "$REPO_ROOT" && npm run typecheck -- --pretty false) || fail "Root typecheck failed"

  log "Running root lint..."
  (cd "$REPO_ROOT" && npm run lint) || fail "Root lint failed"

  log "Running root Jest suite..."
  (cd "$REPO_ROOT" && npm test) || fail "Root Jest suite failed"

  release_gate_emulator_tests

  functions_build
  functions_unit_tests

  ensure_flutter_gate

  log "Running diff hygiene..."
  (cd "$REPO_ROOT" && git diff --check) || fail "Diff hygiene failed"

  log "Release reproducibility gate passed ✓"
}

resolve_project_id() {
  if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
    printf '%s' "$GCP_PROJECT_ID"
    return 0
  fi

  if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
    printf '%s' "$GOOGLE_CLOUD_PROJECT"
    return 0
  fi

  if [[ -n "${GCLOUD_PROJECT:-}" ]]; then
    printf '%s' "$GCLOUD_PROJECT"
    return 0
  fi

  if [[ -n "${FIREBASE_PROJECT_ID:-}" ]]; then
    printf '%s' "$FIREBASE_PROJECT_ID"
    return 0
  fi

  cd "$REPO_ROOT" && firebase_cmd use --json | node -e 'let data="";process.stdin.on("data",d=>data+=d).on("end",()=>{try{const j=JSON.parse(data);process.stdout.write(j.result || "");}catch{process.stdout.write("");}})'
}

# ── Deploy targets ─────────────────────────────────────────────

# Extract exported function names from compiled index.js without loading the module
get_function_names() {
  node -e '
    const fs = require("fs");
    const src = fs.readFileSync(process.argv[1], "utf8");
    const matches = src.match(/^exports\.(\w+)\s*=/gm) || [];
    const names = [...new Set(matches.map(m => m.match(/exports\.(\w+)/)[1]))];
    console.log(names.join(" "));
  ' "$REPO_ROOT/functions/lib/index.js"
}

deploy_functions() {
  functions_build

  local func_names
  func_names=$(get_function_names) || fail "Unable to read exported function names from functions/lib/index.js"

  local batch_size=30
  local batch=()
  local batch_num=1
  local total
  total=$(echo "$func_names" | wc -w | tr -d ' ')
  log "Deploying $total Cloud Functions in batches of $batch_size to stay within GCP quota..."

  export SCHOLESA_PREDEPLOY_DONE=1

  for fn in $func_names; do
    batch+=("$fn")
    if [[ ${#batch[@]} -eq $batch_size ]]; then
      local only_str
      only_str="functions:$(IFS=,; echo "${batch[*]}")"
      log "Deploying batch $batch_num (${#batch[@]} functions)..."
      (cd "$REPO_ROOT" && firebase_cmd deploy --only "$only_str") || fail "Batch $batch_num deploy failed"
      batch=()
      batch_num=$((batch_num + 1))
      if [[ -n "$func_names" ]]; then
        log "Batch complete. Waiting 90s before next batch to respect GCP quota..."
        sleep 90
      fi
    fi
  done

  if [[ ${#batch[@]} -gt 0 ]]; then
    local only_str
    only_str="functions:$(IFS=,; echo "${batch[*]}")"
    log "Deploying final batch $batch_num (${#batch[@]} functions)..."
    (cd "$REPO_ROOT" && firebase_cmd deploy --only "$only_str") || fail "Final batch deploy failed"
  fi

  unset SCHOLESA_PREDEPLOY_DONE
  log "Functions deployed ✓"
}

deploy_rules() {
  log "Deploying Firestore rules + indexes..."
  (cd "$REPO_ROOT" && firebase_cmd deploy --only firestore)

  log "Deploying Storage rules..."
  (cd "$REPO_ROOT" && firebase_cmd deploy --only storage)

  log "Rules deployed ✓"
}

deploy_primary_web() {
  local project_id
  project_id="$(resolve_project_id)"

  [[ -n "$project_id" ]] || fail "Unable to resolve GCP project ID. Set GCP_PROJECT_ID in env."

  local region service image_tag image
  region="${GCP_REGION:-us-central1}"
  service="${CLOUD_RUN_SERVICE:-scholesa-web}"
  image_tag="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
  image="gcr.io/${project_id}/scholesa:${image_tag}"

  ensure_no_traffic_service_exists "$project_id" "$region" "$service"

  local service_state_json
  service_state_json="$(gcloud run services describe "$service" \
    --project "$project_id" \
    --region "$region" \
    --format=json)" || fail "Unable to read primary web Cloud Run service state"

  resolve_primary_web_env_value() {
    local key="$1"
    local local_value="${!key:-}"
    if [[ -n "$local_value" ]]; then
      printf '%s' "$local_value"
      return 0
    fi

    SERVICE_STATE_JSON="$service_state_json" node -e '
      const key = process.argv[1];
      const data = JSON.parse(process.env.SERVICE_STATE_JSON || "{}");
      const env = data.spec?.template?.spec?.containers?.[0]?.env ?? data.spec?.containers?.[0]?.env ?? [];
      const found = env.find((entry) => entry.name === key);
      process.stdout.write(found?.value ?? "");
    ' "$key"
  }

  local -a env_keys resolved_env_values
  env_keys=(
    NEXT_PUBLIC_FIREBASE_API_KEY
    NEXT_PUBLIC_FIREBASE_PROJECT_ID
    NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN
    NEXT_PUBLIC_FIREBASE_APP_ID
    NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
    NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
    NEXT_PUBLIC_ENABLE_SW
  )

  local substitutions
  substitutions="_TAG=${image_tag}"
  for key in "${env_keys[@]}"; do
    local value
    value="$(resolve_primary_web_env_value "$key")"
    if [[ -z "$value" && "$key" == "NEXT_PUBLIC_ENABLE_SW" ]]; then
      value="false"
    fi
    if [[ -z "$value" ]]; then
      fail "Missing $key for primary web build. Set it locally or keep it on the existing Cloud Run service."
    fi
    resolved_env_values+=("$value")
    substitutions+=",_${key}=${value}"
  done

  log "Building primary web image with Cloud Build (project=$project_id service=$service region=$region tag=$image_tag)..."
  (cd "$REPO_ROOT" && gcloud builds submit --project "$project_id" --config cloudbuild.web.yaml --substitutions "$substitutions") || fail "Primary web Cloud Build failed"

  local -a deploy_args
  deploy_args=(
    gcloud run deploy "$service"
    --image "$image"
    --quiet
    --project "$project_id"
    --region "$region"
    --platform managed
    --allow-unauthenticated
  )
  append_no_traffic_arg deploy_args

  local env_arg=""
  for i in "${!env_keys[@]}"; do
    local key value
    key="${env_keys[$i]}"
    value="${resolved_env_values[$i]}"
    if [[ -n "$env_arg" ]]; then
      env_arg+=","
    fi
    env_arg+="${key}=${value}"
  done
  deploy_args+=(--set-env-vars "$env_arg")

  if [[ -n "${FIREBASE_SERVICE_ACCOUNT_SECRET:-}" ]]; then
    deploy_args+=(--update-secrets "FIREBASE_SERVICE_ACCOUNT=${FIREBASE_SERVICE_ACCOUNT_SECRET}:latest")
  fi

  log "Deploying primary web to Cloud Run..."
  "${deploy_args[@]}" || fail "Primary web Cloud Run deploy failed"

  if [[ "$NO_TRAFFIC_DEPLOY" == "1" || "$NO_TRAFFIC_DEPLOY" == "true" ]]; then
    tag_no_traffic_rehearsal_revision "$project_id" "$region" "$service"
  else
    log "Routing primary web traffic to latest revision..."
    gcloud run services update-traffic "$service" \
      --quiet \
      --project "$project_id" \
      --region "$region" \
      --platform managed \
      --to-latest || fail "Primary web traffic update failed"
  fi

  log "Primary web deployed ✓"
}

deploy_flutter_cloud_run() {
  ensure_flutter_gate

  local project_id
  project_id="$(resolve_project_id)"

  [[ -n "$project_id" ]] || fail "Unable to resolve GCP project ID. Set GCP_PROJECT_ID in env."

  local region service image_tag
  region="${GCP_REGION:-us-central1}"
  service="${CLOUD_RUN_FLUTTER_SERVICE:-empire-web}"
  image_tag="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"

  ensure_no_traffic_service_exists "$project_id" "$region" "$service"

  log "Deploying Flutter web to Cloud Run (project=$project_id service=$service region=$region tag=$image_tag)..."
  (cd "$REPO_ROOT" && bash ./scripts/deploy-cloud-run.sh "$project_id" "$region" "$service" "$image_tag")
  log "Flutter web deployed ✓"
}

deploy_cloud_run_web() {
  deploy_primary_web
  deploy_flutter_cloud_run
  log "Both Cloud Run web surfaces deployed ✓"
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

  ensure_no_traffic_service_exists "$project_id" "$region" "$service"

  log "Building compliance operator image with Cloud Build..."
  (cd "$REPO_ROOT" && gcloud builds submit --project "$project_id" --config cloudbuild.compliance.yaml --substitutions "_TAG=$image_tag")

  local -a compliance_deploy_args
  compliance_deploy_args=(
    gcloud run deploy "$service"
    --image "gcr.io/${project_id}/scholesa-compliance:${image_tag}"
    --project "$project_id"
    --region "$region"
    --platform managed
    --no-allow-unauthenticated
    --set-env-vars "COMPLIANCE_ALLOW_UNAUTH=0,COMPLIANCE_ROOT_REDIRECT_URL=${root_redirect_url}"
  )
  append_no_traffic_arg compliance_deploy_args

  log "Deploying compliance operator to Cloud Run (service=$service region=$region)..."
  (cd "$REPO_ROOT" && "${compliance_deploy_args[@]}")

  if [[ "$NO_TRAFFIC_DEPLOY" == "1" || "$NO_TRAFFIC_DEPLOY" == "true" ]]; then
    tag_no_traffic_rehearsal_revision "$project_id" "$region" "$service"
  else
    log "Routing compliance operator traffic to latest revision..."
    (cd "$REPO_ROOT" && gcloud run services update-traffic "$service" \
      --quiet \
      --project "$project_id" \
      --region "$region" \
      --platform managed \
      --to-latest) || fail "Compliance operator traffic update failed"
  fi

  log "Compliance operator deployed ✓"
}

deploy_flutter_web() {
  deploy_flutter_cloud_run
}

deploy_flutter_ios() {
  ensure_flutter_gate
  log "Building Flutter iOS (release)..."
  (cd "$FLUTTER_APP" && flutter_cmd build ios --release --no-codesign --no-tree-shake-icons)
  log "iOS build complete. Open Xcode to archive and distribute."
}

deploy_flutter_macos() {
  ensure_flutter_gate
  log "Building Flutter macOS (release)..."
  # Ad-hoc sign + disable ODR so local builds work without a Mac Development cert
  # for team CEUD8LB243. Distribution still requires a Developer ID cert + notarization.
  (
    cd "$FLUTTER_APP" && \
    FLUTTER_XCODE_CODE_SIGN_IDENTITY="${FLUTTER_XCODE_CODE_SIGN_IDENTITY:--}" \
    FLUTTER_XCODE_CODE_SIGNING_REQUIRED="${FLUTTER_XCODE_CODE_SIGNING_REQUIRED:-NO}" \
    FLUTTER_XCODE_CODE_SIGNING_ALLOWED="${FLUTTER_XCODE_CODE_SIGNING_ALLOWED:-NO}" \
    FLUTTER_XCODE_DEVELOPMENT_TEAM="${FLUTTER_XCODE_DEVELOPMENT_TEAM-}" \
    FLUTTER_XCODE_ENABLE_ON_DEMAND_RESOURCES="${FLUTTER_XCODE_ENABLE_ON_DEMAND_RESOURCES:-NO}" \
    flutter_cmd build macos --release --no-tree-shake-icons
  )
  log "macOS build complete. Sign + notarize before distribution."
}

deploy_flutter_android() {
  require_android_sdk
  ensure_flutter_gate
  log "Building Flutter Android App Bundle (release)..."
  (cd "$FLUTTER_APP" && flutter_cmd build appbundle --release)
  log "Android App Bundle: $FLUTTER_APP/build/app/outputs/bundle/release/app-release.aab"

  log "Building Flutter Android APK (release)..."
  (cd "$FLUTTER_APP" && flutter_cmd build apk --release)
  log "Android APK: $FLUTTER_APP/build/app/outputs/flutter-apk/app-release.apk"
}

deploy_all() {
  ensure_flutter_gate
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
  web)              deploy_cloud_run_web ;;
  cloudrun-web)     deploy_cloud_run_web ;;
  primary-web)      deploy_primary_web ;;
  compliance-operator) deploy_compliance_operator ;;
  flutter-web)      deploy_flutter_web ;;
  flutter-ios)      deploy_flutter_ios ;;
  flutter-macos)    deploy_flutter_macos ;;
  flutter-android)  deploy_flutter_android ;;
  release-gate)     release_gate ;;
  *)                fail "Unknown target: $TARGET. Use: all | functions | rules | web | cloudrun-web | primary-web | compliance-operator | flutter-web | flutter-ios | flutter-macos | flutter-android | release-gate" ;;
esac
