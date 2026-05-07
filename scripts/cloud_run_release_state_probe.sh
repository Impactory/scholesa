#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-studio-3328096157-e3f79}"
REGION="${GCP_REGION:-us-central1}"

WEB_SERVICE="${CLOUD_RUN_SERVICE:-scholesa-web}"
FLUTTER_SERVICE="${CLOUD_RUN_FLUTTER_SERVICE:-empire-web}"
COMPLIANCE_SERVICE="${COMPLIANCE_RUN_SERVICE:-scholesa-compliance}"

EXPECTED_WEB_REHEARSAL_REVISION="${EXPECTED_WEB_REHEARSAL_REVISION:-}"
EXPECTED_WEB_READY_REVISION="${EXPECTED_WEB_READY_REVISION:-}"
EXPECTED_WEB_TRAFFIC_REVISION="${EXPECTED_WEB_TRAFFIC_REVISION:-}"
EXPECTED_FLUTTER_REHEARSAL_REVISION="${EXPECTED_FLUTTER_REHEARSAL_REVISION:-}"
EXPECTED_FLUTTER_READY_REVISION="${EXPECTED_FLUTTER_READY_REVISION:-}"
EXPECTED_FLUTTER_TRAFFIC_REVISION="${EXPECTED_FLUTTER_TRAFFIC_REVISION:-}"
EXPECTED_COMPLIANCE_REHEARSAL_REVISION="${EXPECTED_COMPLIANCE_REHEARSAL_REVISION:-${EXPECTED_COMPLIANCE_REVISION:-}}"
EXPECTED_COMPLIANCE_READY_REVISION="${EXPECTED_COMPLIANCE_READY_REVISION:-}"
EXPECTED_COMPLIANCE_TRAFFIC_REVISION="${EXPECTED_COMPLIANCE_TRAFFIC_REVISION:-${EXPECTED_COMPLIANCE_REVISION:-}}"

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

fail() {
  echo "Cloud Run release state probe failed: $*" >&2
  exit 1
}

command -v gcloud >/dev/null 2>&1 || fail "gcloud not found on PATH"
command -v curl >/dev/null 2>&1 || fail "curl not found on PATH"

describe_service() {
  local service="$1"

  gcloud run services describe "$service" \
    --project "$PROJECT_ID" \
    --region "$REGION" \
    --format='json(metadata.name,status.url,status.traffic,status.latestCreatedRevisionName,status.latestReadyRevisionName)'
}

assert_service_state() {
  local payload="$1"
  local service="$2"
  local expected_created="$3"
  local expected_ready="$4"
  local expected_traffic="$5"

  node -e '
    const [service, expectedCreated, expectedReady, expectedTraffic] = process.argv.slice(1);
    const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const traffic = data.status?.traffic || [];
    const required = (value) => typeof value === "string" && value.length > 0;
    const servingTraffic = traffic.filter((entry) => entry.percent === 100);
    const hasExpectedTraffic = required(expectedTraffic)
      ? traffic.some((entry) => entry.revisionName === expectedTraffic && entry.percent === 100)
      : servingTraffic.length > 0;

    if (data.metadata?.name !== service) {
      throw new Error(`${service}: expected service name ${service}, got ${data.metadata?.name}`);
    }
    if (required(expectedCreated) && data.status?.latestCreatedRevisionName !== expectedCreated) {
      throw new Error(`${service}: expected latest created ${expectedCreated}, got ${data.status?.latestCreatedRevisionName}`);
    }
    if (required(expectedReady) && data.status?.latestReadyRevisionName !== expectedReady) {
      throw new Error(`${service}: expected latest ready ${expectedReady}, got ${data.status?.latestReadyRevisionName}`);
    }
    if (!data.status?.latestCreatedRevisionName) {
      throw new Error(`${service}: missing latest created revision`);
    }
    if (!data.status?.latestReadyRevisionName) {
      throw new Error(`${service}: missing latest ready revision`);
    }
    if (!hasExpectedTraffic) {
      throw new Error(required(expectedTraffic)
        ? `${service}: expected 100% traffic on ${expectedTraffic}`
        : `${service}: expected at least one revision with 100% traffic`);
    }
  ' "$service" "$expected_created" "$expected_ready" "$expected_traffic" <<<"$payload"
}

assert_compliance_edge_auth() {
  local compliance_url="$1"
  local root_code health_code status_code

  root_code="$(curl -sS -o /tmp/scholesa-live-compliance-root.txt -w '%{http_code}' "$compliance_url/")"
  health_code="$(curl -sS -o /tmp/scholesa-live-compliance-health.txt -w '%{http_code}' "$compliance_url/health")"
  status_code="$(curl -sS -o /tmp/scholesa-live-compliance-status.txt -w '%{http_code}' "$compliance_url/compliance/status")"

  [[ "$root_code" == "403" ]] || fail "expected unauthenticated compliance root to return 403, got $root_code"
  [[ "$health_code" == "403" ]] || fail "expected unauthenticated compliance health to return 403, got $health_code"
  [[ "$status_code" == "403" ]] || fail "expected unauthenticated compliance status to return 403, got $status_code"
}

web_state="$(describe_service "$WEB_SERVICE")"
flutter_state="$(describe_service "$FLUTTER_SERVICE")"
compliance_state="$(describe_service "$COMPLIANCE_SERVICE")"

assert_service_state "$web_state" "$WEB_SERVICE" "$EXPECTED_WEB_REHEARSAL_REVISION" "$EXPECTED_WEB_READY_REVISION" "$EXPECTED_WEB_TRAFFIC_REVISION"
assert_service_state "$flutter_state" "$FLUTTER_SERVICE" "$EXPECTED_FLUTTER_REHEARSAL_REVISION" "$EXPECTED_FLUTTER_READY_REVISION" "$EXPECTED_FLUTTER_TRAFFIC_REVISION"
assert_service_state "$compliance_state" "$COMPLIANCE_SERVICE" "$EXPECTED_COMPLIANCE_REHEARSAL_REVISION" "$EXPECTED_COMPLIANCE_READY_REVISION" "$EXPECTED_COMPLIANCE_TRAFFIC_REVISION"

compliance_url="$(node -e 'const data = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(data.status.url);' <<<"$compliance_state")"
assert_compliance_edge_auth "$compliance_url"

echo "Cloud Run release state probe passed (Cloud Run traffic has a 100% serving revision, optional revision expectations matched, unauth compliance edge 403)."