#!/usr/bin/env bash
set -euo pipefail

TRACKED_ENV_FILES="$(git ls-files '.env*' ':!:*.example' || true)"

EXPOSABLE_ENV_FILES=""
if [[ -n "${TRACKED_ENV_FILES}" ]]; then
  while IFS= read -r env_file; do
    [[ -z "$env_file" ]] && continue
    if [[ -e "$env_file" ]]; then
      EXPOSABLE_ENV_FILES+="$env_file"$'\n'
    fi
  done <<< "$TRACKED_ENV_FILES"
fi

if [[ -n "${EXPOSABLE_ENV_FILES}" ]]; then
  echo "------------------------------------------------------------------------"
  echo "⛔  COMMIT BLOCKED: Tracked environment file(s) detected"
  echo "------------------------------------------------------------------------"
  echo "The following files match '.env*' and are tracked in git:"
  echo "${EXPOSABLE_ENV_FILES}" | sed '/^$/d' | sed 's/^/  - /'
  echo ""
  echo "Only example templates (for example '.env.example') are allowed in git."
  echo "Move secrets to your secret manager and untrack these files."
  echo ""
  echo "Suggested remediation:"
  echo "  git rm --cached <file>"
  echo "  git commit"
  exit 1
fi

exit 0