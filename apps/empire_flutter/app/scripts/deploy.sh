#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_ROOT/../../.." && pwd)"
FVM_FLUTTER="$APP_ROOT/.fvm/flutter_sdk/bin/flutter"

if [ -x "$FVM_FLUTTER" ]; then
	FLUTTER_BIN="$FVM_FLUTTER"
else
	FLUTTER_BIN="flutter"
fi

# Sync icons before build
bash "$APP_ROOT/scripts/sync_platform_icons.sh"

# Build the production web bundle on the stable non-WASM path until
# flutter_tts and the rest of the voice stack are WebAssembly-clean.
"$FLUTTER_BIN" build web --release --no-tree-shake-icons --no-wasm-dry-run

# Docker + Cloud Run deploy (requires GCP_PROJECT_ID, GCP_REGION, CLOUD_RUN_FLUTTER_SERVICE)
if [[ -n "${GCP_PROJECT_ID:-}" && -n "${GCP_REGION:-}" && -n "${CLOUD_RUN_FLUTTER_SERVICE:-}" ]]; then
	GIT_SHA="${GIT_SHA:-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "local")}"
	FLUTTER_IMAGE="gcr.io/${GCP_PROJECT_ID}/empire-web:${GIT_SHA}"

	echo "Building Flutter web Docker image: $FLUTTER_IMAGE"
	docker build -f "$REPO_ROOT/Dockerfile.flutter" -t "$FLUTTER_IMAGE" "$REPO_ROOT"
	docker push "$FLUTTER_IMAGE"

	NO_TRAFFIC_FLAG=""
	if [[ "${NO_TRAFFIC:-false}" == "true" ]]; then
		NO_TRAFFIC_FLAG="--no-traffic"
	fi

	echo "Deploying Flutter web to Cloud Run: $CLOUD_RUN_FLUTTER_SERVICE"
	gcloud run deploy "$CLOUD_RUN_FLUTTER_SERVICE" \
		--image "$FLUTTER_IMAGE" \
		--region "$GCP_REGION" \
		--platform managed \
		${NO_TRAFFIC_FLAG} \
		--allow-unauthenticated

	echo "Flutter web deployed: $CLOUD_RUN_FLUTTER_SERVICE (region $GCP_REGION)"
else
	echo "Skipping Docker/Cloud Run deploy: GCP_PROJECT_ID, GCP_REGION, or CLOUD_RUN_FLUTTER_SERVICE not set."
fi
