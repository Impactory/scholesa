#!/usr/bin/env bash
# Usage: ./scripts/deploy-cloud-run.sh <GCP_PROJECT_ID> <GCP_REGION> <CLOUD_RUN_SERVICE> <IMAGE_TAG>
set -euo pipefail

GCP_PROJECT_ID=${1:-}
GCP_REGION=${2:-us-central1}
CLOUD_RUN_SERVICE=${3:-scholesa-web}
IMAGE_TAG=${4:-latest}

if [ -z "$GCP_PROJECT_ID" ]; then
  echo "Usage: $0 <GCP_PROJECT_ID> [GCP_REGION] [CLOUD_RUN_SERVICE] [IMAGE_TAG]"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/empire_flutter/app"
IMAGE=gcr.io/${GCP_PROJECT_ID}/empire-web:${IMAGE_TAG}
STAGING_DIR="$(mktemp -d)"

command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found on PATH"; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync not found on PATH"; exit 1; }

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

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
  "$FLUTTER_APP/" "$STAGING_DIR/apps/empire_flutter/app/"

echo "Submitting Docker build with Dockerfile.flutter for $IMAGE"
gcloud builds submit "$STAGING_DIR" --project "$GCP_PROJECT_ID" --config "$STAGING_DIR/cloudbuild.flutter.yaml" --substitutions "_TAG=${IMAGE_TAG}"

echo "Deploying to Cloud Run: service=$CLOUD_RUN_SERVICE region=$GCP_REGION"

gcloud run deploy "$CLOUD_RUN_SERVICE" \
  --image "$IMAGE" \
  --project "$GCP_PROJECT_ID" \
  --region "$GCP_REGION" \
  --platform managed \
  --allow-unauthenticated

echo "Deployment finished."
