#!/bin/bash
set -e

# Sync icons before build
bash ./scripts/sync_platform_icons.sh

# Build web with WASM
flutter build web --wasm

# Add other build/deploy steps as needed
