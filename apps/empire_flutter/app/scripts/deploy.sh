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

echo "[deploy] Flutter: $($FLUTTER_BIN --version | head -1)"

# Sync icons before build
echo "[deploy] Syncing platform icons..."
bash "$APP_ROOT/scripts/sync_platform_icons.sh"

# Build the production web bundle on the stable non-WASM path until
# flutter_tts and the rest of the voice stack are WebAssembly-clean.
echo "[deploy] Building Flutter web release..."
"$FLUTTER_BIN" build web --release --no-tree-shake-icons --no-wasm-dry-run

BUILD_DIR="$APP_ROOT/build/web"

if [ ! -d "$BUILD_DIR" ]; then
	echo "[deploy] ERROR: Build output not found at $BUILD_DIR"
	exit 1
fi

echo "[deploy] Build output at: $BUILD_DIR"
echo "[deploy] Asset manifest:"
ls -lh "$BUILD_DIR/assets/" 2>/dev/null | head -10
echo "[deploy] Icons:"
ls -lh "$BUILD_DIR/icons/" 2>/dev/null

# Docker + Cloud Run deploy (requires GCP_PROJECT_ID, GCP_REGION, CLOUD_RUN_FLUTTER_SERVICE)
if [[ -n "${GCP_PROJECT_ID:-}" && -n "${GCP_REGION:-}" && -n "${CLOUD_RUN_FLUTTER_SERVICE:-}" ]]; then
	GIT_SHA="${GIT_SHA:-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "local")}"
	FLUTTER_IMAGE="gcr.io/${GCP_PROJECT_ID}/empire-web:${GIT_SHA}"

	echo "[deploy] Building Flutter web Docker image: $FLUTTER_IMAGE"
	docker build -f "$REPO_ROOT/Dockerfile.flutter" -t "$FLUTTER_IMAGE" "$REPO_ROOT"
	docker push "$FLUTTER_IMAGE"

	NO_TRAFFIC_FLAG=""
	if [[ "${NO_TRAFFIC:-false}" == "true" ]]; then
		NO_TRAFFIC_FLAG="--no-traffic"
	fi

	echo "[deploy] Deploying Flutter web to Cloud Run: $CLOUD_RUN_FLUTTER_SERVICE"
	gcloud run deploy "$CLOUD_RUN_FLUTTER_SERVICE" \
		--image "$FLUTTER_IMAGE" \
		--region "$GCP_REGION" \
		--platform managed \
		${NO_TRAFFIC_FLAG} \
		--allow-unauthenticated

	echo "[deploy] Flutter web deployed: $CLOUD_RUN_FLUTTER_SERVICE (region $GCP_REGION)"
elif command -v docker >/dev/null 2>&1; then
	echo "[deploy] Building Docker image for Cloud Run..."
	docker build -f "$REPO_ROOT/Dockerfile.flutter" -t empire-web:local "$REPO_ROOT"
	echo "[deploy] Docker image built: empire-web:local"
	echo "[deploy] To push: docker tag empire-web:local gcr.io/PROJECT_ID/empire-web:TAG && docker push ..."
else
	echo "[deploy] Docker not available. Build artifacts ready at: $BUILD_DIR"
	echo "[deploy] To deploy manually:"
	echo "  1. docker build -f Dockerfile.flutter -t empire-web ."
	echo "  2. docker push gcr.io/PROJECT_ID/empire-web:TAG"
	echo "  3. gcloud run deploy SERVICE --image gcr.io/PROJECT_ID/empire-web:TAG"
fi

echo "[deploy] Done."
