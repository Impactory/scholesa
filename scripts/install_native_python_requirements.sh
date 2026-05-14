#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUIREMENTS_FILE="$REPO_ROOT/requirements-native.txt"

if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_BIN="$PYTHON"
elif [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
  PYTHON_BIN="$REPO_ROOT/.venv/bin/python"
else
  PYTHON_BIN="python3"
fi

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "Missing native Python requirements file: $REQUIREMENTS_FILE" >&2
  exit 1
fi

"$PYTHON_BIN" -m pip install -r "$REQUIREMENTS_FILE"
"$PYTHON_BIN" -c 'import PIL'
