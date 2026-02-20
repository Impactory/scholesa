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

command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found on PATH"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not found on PATH"; exit 1; }

echo "Building Flutter web release bundle"
(cd "$FLUTTER_APP" && flutter build web --release)

echo "Submitting Docker build with Dockerfile.flutter for $IMAGE"
gcloud builds submit "$REPO_ROOT" --project "$GCP_PROJECT_ID" --config "$REPO_ROOT/cloudbuild.flutter.yaml" --substitutions "_TAG=${IMAGE_TAG}"

echo "Deploying to Cloud Run: service=$CLOUD_RUN_SERVICE region=$GCP_REGION"

gcloud run deploy "$CLOUD_RUN_SERVICE" \
  --image "$IMAGE" \
  --project "$GCP_PROJECT_ID" \
  --region "$GCP_REGION" \
  --platform managed \
  --allow-unauthenticated

echo "Deployment finished."
