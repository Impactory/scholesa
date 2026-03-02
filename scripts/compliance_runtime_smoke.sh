#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

node services/scholesa-compliance/src/server.js >/tmp/scholesa-compliance-smoke.log 2>&1 &
SERVER_PID=$!
sleep 1

root_code="$(curl -s -o /tmp/scholesa-root-smoke.json -w "%{http_code}" http://127.0.0.1:8080/)"
health_code="$(curl -s -o /tmp/scholesa-healthz-smoke.json -w "%{http_code}" http://127.0.0.1:8080/healthz)"
status_code="$(curl -s -o /tmp/scholesa-status-smoke.json -w "%{http_code}" http://127.0.0.1:8080/compliance/status)"

if [[ "$root_code" != "200" ]]; then
  echo "Compliance runtime smoke failed: GET / returned $root_code"
  cat /tmp/scholesa-root-smoke.json || true
  exit 1
fi

if [[ "$health_code" != "200" ]]; then
  echo "Compliance runtime smoke failed: GET /healthz returned $health_code"
  cat /tmp/scholesa-healthz-smoke.json || true
  exit 1
fi

if [[ "$status_code" != "401" ]]; then
  echo "Compliance runtime smoke failed: GET /compliance/status expected 401 without auth, got $status_code"
  cat /tmp/scholesa-status-smoke.json || true
  exit 1
fi

echo "Compliance runtime smoke passed (/, /healthz, auth gate)."
