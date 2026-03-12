#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# Add other build/deploy steps as needed
