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

IMAGE=gcr.io/${GCP_PROJECT_ID}/scholesa:${IMAGE_TAG}

echo "Building image $IMAGE"
docker build -t "$IMAGE" .

echo "Pushing image"
docker push "$IMAGE"

echo "Deploying to Cloud Run: service=$CLOUD_RUN_SERVICE region=$GCP_REGION"

gcloud run deploy "$CLOUD_RUN_SERVICE" \
  --image "$IMAGE" \
  --region "$GCP_REGION" \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars "NEXT_PUBLIC_FIREBASE_API_KEY=${NEXT_PUBLIC_FIREBASE_API_KEY:-}","NEXT_PUBLIC_FIREBASE_PROJECT_ID=${NEXT_PUBLIC_FIREBASE_PROJECT_ID:-}" \
  --update-secrets "FIREBASE_SERVICE_ACCOUNT=firebase-service-account:latest"

echo "Deployment finished."
