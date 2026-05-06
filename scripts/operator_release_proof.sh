#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "Operator release proof failed: $*" >&2
  exit 1
}

require_file_contains() {
  local file="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$file" || fail "$file is missing required release proof text: $needle"
}

require_output_contains() {
  local output="$1"
  local needle="$2"

  grep -Fq -- "$needle" <<<"$output" || fail "cutover guide output is missing: $needle"
}

cutover_output="$(bash ./scripts/rc3_big_bang_cutover_entrypoint.sh --print-only)"

require_output_contains "$cutover_output" "Required command sequence:"
require_output_contains "$cutover_output" "npm run rc3:preflight"
require_output_contains "$cutover_output" "Execute the six-role browser sweep"
require_output_contains "$cutover_output" "Rollback rule:"
require_output_contains "$cutover_output" "declare NO-GO and rollback the full release"

require_file_contains scripts/deploy.sh "append_no_traffic_arg"
require_file_contains scripts/deploy.sh "ensure_no_traffic_service_exists"
require_file_contains scripts/deploy.sh "Cloud Run does not support --no-traffic on first deploy"
require_file_contains scripts/deploy.sh "deploy_compliance_operator"
require_file_contains scripts/deploy.sh "--no-allow-unauthenticated"
require_file_contains scripts/deploy.sh "COMPLIANCE_ALLOW_UNAUTH=0"
require_file_contains scripts/deploy.sh "gcloud run services update-traffic"
require_file_contains scripts/deploy.sh "Routing compliance operator traffic to latest revision"

require_file_contains scripts/deploy-cloud-run.sh "no_traffic_args+=(--no-traffic)"
require_file_contains scripts/deploy-cloud-run.sh "gcloud run services update-traffic"
require_file_contains scripts/deploy-cloud-run.sh "Routing traffic to latest revision"

require_file_contains scripts/compliance_runtime_smoke.sh "expected 401 without auth"

echo "Operator release proof passed (cutover guide, no-traffic guards, compliance auth, rollback rule)."
