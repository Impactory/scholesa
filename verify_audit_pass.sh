#!/bin/bash
# scripts/verify_audit_pass.sh

# Path to the audit report
AUDIT_REPORT="AUDIT_REPORT.md"

# Check if report exists
if [ ! -f "$AUDIT_REPORT" ]; then
  echo "❌ Error: $AUDIT_REPORT file not found!"
  exit 1
fi

echo "🔍 Parsing $AUDIT_REPORT for failed checks..."

# Search for the specific failure pattern used in run_phase1_checks.sh
# The pattern is "| FAIL |" inside the table.
if grep -Fq "| FAIL |" "$AUDIT_REPORT"; then
  echo "⛔  BUILD FAILED: Found failed checks in Audit Report."
  echo "-----------------------------------------------------"
  grep -F "| FAIL |" "$AUDIT_REPORT"
  echo "-----------------------------------------------------"
  echo "Please fix the issues listed above and update the report."
  exit 1
fi

echo "✅ Audit Report verification passed (No 'FAIL' statuses found)."
exit 0