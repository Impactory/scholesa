#!/bin/bash
# .git/hooks/pre-commit
#
# Enforces SCHOLESA Protocol:
# If source code (.dart) is modified, AUDIT_REPORT.md must also be updated.

AUDIT_REPORT="AUDIT_REPORT.md"

# 0. Check for bypass flag
if [ "$SKIP_AUDIT" = "1" ]; then
  exit 0
fi

# 1. Check if AUDIT_REPORT.md is already staged for commit
# We use grep to check if the file appears in the staged file list
if git diff --cached --name-only | grep -q "^$AUDIT_REPORT$"; then
  exit 0
fi

# 2. Check if any Dart source files are staged
if git diff --cached --name-only | grep -q "\.dart$"; then
  echo "------------------------------------------------------------------------"
  echo "⛔  COMMIT BLOCKED: Audit Report not updated."
  echo "------------------------------------------------------------------------"
  echo "You have modified Dart source files but 'AUDIT_REPORT.md' is untouched."
  echo "Per SCHOLESA_AUDIT_FIX_AND_REMEDIATION_VIBE.md, you must:"
  echo "  1. Run the Phase 1 checks (use: ./scripts/run_phase1_checks.sh)"
  echo "     (This script will automatically update $AUDIT_REPORT)"
  echo "  2. git add $AUDIT_REPORT"
  echo ""
  echo "To bypass for trivial changes: SKIP_AUDIT=1 git commit ..."
  exit 1
fi

exit 0