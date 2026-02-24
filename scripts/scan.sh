#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

OUT_DIR="audit-pack/reports"
mkdir -p "$OUT_DIR"

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SHA="$(git rev-parse HEAD)"

echo "Scanning repo at: $ROOT"
echo "Commit: $SHA"
echo "Time: $TS"

# 1) Repo structure snapshot
{
  echo "{"
  echo "  \"timestamp\": \"${TS}\","
  echo "  \"gitSha\": \"${SHA}\","
  echo "  \"root\": \"${ROOT}\","
  echo "  \"topLevel\": ["
  ls -1 | sed 's/^/    "/; s/$/",/' | sed '$ s/,$//'
  echo "  ]"
  echo "}"
} > "${OUT_DIR}/repo-structure-scan.json"

# 2) Find likely infra + CI
find . -maxdepth 7 \
  \( -name "firebase.json" -o -name "firestore.rules" -o -name "storage.rules" -o -name "*.tf" -o -name "cloudbuild.yaml" -o -name "Dockerfile" -o -name ".github" -o -name "skaffold.yaml" -o -name "pnpm-lock.yaml" -o -name "yarn.lock" -o -name "package-lock.json" -o -name "requirements.txt" -o -name "poetry.lock" -o -name "go.mod" \) \
  -print > "${OUT_DIR}/repo-key-files.txt"

# 3) Gemini usage grep (deps/imports/domains/env)
GEMINI_PATTERNS='gemini|generativelanguage|@google/generative-ai|google-genai|GenerativeModel|vertexai|aiplatform|texttospeech|speech-to-text|tts|stt'
grep -RIn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=build --exclude-dir=dist -E "$GEMINI_PATTERNS" . \
  > "${OUT_DIR}/gemini-grep.txt" || [[ $? -eq 1 ]]

# 4) Likely secrets/env references
KEY_PATTERNS='GEMINI|GENERATIVE|GOOGLE_API_KEY|VERTEX|AIPLATFORM|GENAI|OPENAI|API_KEY'
grep -RIn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=build --exclude-dir=dist -E "$KEY_PATTERNS" . \
  > "${OUT_DIR}/vendor-key-grep.txt" || [[ $? -eq 1 ]]

# 5) Create a structured Gemini usage inventory JSON
python3 scripts/compliance/make_gemini_inventory.py \
  --repo-root "$ROOT" \
  --git-sha "$SHA" \
  --timestamp "$TS" \
  --gemini-grep "${OUT_DIR}/gemini-grep.txt" \
  --key-grep "${OUT_DIR}/vendor-key-grep.txt" \
  --out "${OUT_DIR}/gemini-usage-inventory.json"

echo "Done. Reports written to ${OUT_DIR}/"
echo "Key outputs:"
echo " - ${OUT_DIR}/repo-structure-scan.json"
echo " - ${OUT_DIR}/repo-key-files.txt"
echo " - ${OUT_DIR}/gemini-usage-inventory.json"
echo " - ${OUT_DIR}/gemini-grep.txt"
echo " - ${OUT_DIR}/vendor-key-grep.txt"
