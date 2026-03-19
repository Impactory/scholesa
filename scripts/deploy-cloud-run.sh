#!/usr/bin/env bash
# Usage: ./scripts/deploy-cloud-run.sh <GCP_PROJECT_ID> <GCP_REGION> <CLOUD_RUN_SERVICE> <IMAGE_TAG>
set -euo pipefail

GCP_PROJECT_ID=${1:-}
GCP_REGION=${2:-us-central1}
CLOUD_RUN_SERVICE=${3:-empire-web}
IMAGE_TAG=${4:-latest}
NO_TRAFFIC_DEPLOY="${CLOUD_RUN_NO_TRAFFIC:-0}"

if [ -z "$GCP_PROJECT_ID" ]; then
  echo "Usage: $0 <GCP_PROJECT_ID> [GCP_REGION] [CLOUD_RUN_SERVICE] [IMAGE_TAG]"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/empire_flutter/app"
IMAGE=gcr.io/${GCP_PROJECT_ID}/empire-web:${IMAGE_TAG}
STAGING_DIR="$(mktemp -d)"

# Avoid interactive prompts and macOS extended-attribute sidecars during staging/archive.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found on PATH"; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync not found on PATH"; exit 1; }

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

no_traffic_args=()
if [[ "$NO_TRAFFIC_DEPLOY" == "1" || "$NO_TRAFFIC_DEPLOY" == "true" ]]; then
  if ! gcloud run services describe "$CLOUD_RUN_SERVICE" \
    --project "$GCP_PROJECT_ID" \
    --region "$GCP_REGION" \
    --format='value(metadata.name)' >/dev/null 2>&1; then
    echo "Cloud Run service '$CLOUD_RUN_SERVICE' does not exist in project '$GCP_PROJECT_ID' region '$GCP_REGION'. Cloud Run does not support --no-traffic on first deploy; create the service once without CLOUD_RUN_NO_TRAFFIC=1, then rerun the rehearsal." >&2
    exit 1
  fi
  no_traffic_args+=(--no-traffic)
fi

mkdir -p "$STAGING_DIR/apps/empire_flutter"
cp "$REPO_ROOT/Dockerfile.flutter" "$STAGING_DIR/Dockerfile.flutter"
cp "$REPO_ROOT/cloudbuild.flutter.yaml" "$STAGING_DIR/cloudbuild.flutter.yaml"

echo "Staging minimal Cloud Build context"
rsync -a \
  --exclude build \
  --exclude .dart_tool \
  --exclude .firebase \
  --exclude .flutter-plugins-dependencies \
  --exclude .flutter-plugins \
  --exclude .pub-cache \
  --exclude .fvm \
  --exclude .git \
  --exclude .idea \
  --exclude .vscode \
  --exclude android \
  --exclude ios \
  --exclude linux \
  --exclude macos \
  --exclude windows \
  --exclude test \
  --exclude integration_test \
  "$FLUTTER_APP/" "$STAGING_DIR/apps/empire_flutter/app/"

echo "Submitting Docker build with Dockerfile.flutter for $IMAGE"
gcloud builds submit "$STAGING_DIR" --quiet --project "$GCP_PROJECT_ID" --config "$STAGING_DIR/cloudbuild.flutter.yaml" --substitutions "_TAG=${IMAGE_TAG}"

echo "Deploying to Cloud Run: service=$CLOUD_RUN_SERVICE region=$GCP_REGION"

gcloud run deploy "$CLOUD_RUN_SERVICE" \
  --image "$IMAGE" \
  --quiet \
  --project "$GCP_PROJECT_ID" \
  --region "$GCP_REGION" \
  --platform managed \
  "${no_traffic_args[@]}" \
  --allow-unauthenticated

echo "Deployment finished."
