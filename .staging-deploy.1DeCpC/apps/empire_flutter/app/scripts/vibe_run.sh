#!/usr/bin/env bash
# ──────────────────────────────────────────────────────
# vibe_run.sh — Vibe Master Regression Test Runner
# Runs all Scholesa regression suites and generates report.
# ──────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="$APP_DIR/docs/vibe"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/regression_report_${TIMESTAMP}.txt"

cd "$APP_DIR"

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Scholesa Vibe Master Regression Test Runner        ║"
echo "║   $(date)                                            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. Static Analysis ──
echo "▸ [1/4] Running flutter analyze..."
flutter analyze 2>&1 | tee -a "$REPORT_FILE"
echo ""

# ── 2. Unit Tests ──
echo "▸ [2/4] Running unit tests..."
flutter test --reporter compact 2>&1 | tee -a "$REPORT_FILE"
echo ""

# ── 3. Event Schema Audit ──
echo "▸ [3/4] Auditing BOS event envelope..."
echo "--- BOS Event Schema Audit ---" >> "$REPORT_FILE"
# Check BosEvent has required fields
grep -c 'eventId' lib/runtime/bos_models.dart >> "$REPORT_FILE" 2>&1 || echo "MISSING: eventId" >> "$REPORT_FILE"
grep -c 'schemaVersion' lib/runtime/bos_models.dart >> "$REPORT_FILE" 2>&1 || echo "MISSING: schemaVersion" >> "$REPORT_FILE"
grep -c 'contextMode' lib/runtime/bos_models.dart >> "$REPORT_FILE" 2>&1 || echo "MISSING: contextMode" >> "$REPORT_FILE"
grep -c 'actorIdPseudo' lib/runtime/bos_models.dart >> "$REPORT_FILE" 2>&1 || echo "MISSING: actorIdPseudo" >> "$REPORT_FILE"
grep -c 'ClientInfo' lib/runtime/bos_models.dart >> "$REPORT_FILE" 2>&1 || echo "MISSING: ClientInfo" >> "$REPORT_FILE"
echo "Event schema audit complete." | tee -a "$REPORT_FILE"
echo ""

# ── 4. Model Coverage ──
echo "▸ [4/4] Checking model coverage..."
echo "--- Model Coverage ---" >> "$REPORT_FILE"
for model in ResearchConsentModel StudentAssentModel AssessmentInstrumentModel AssessmentItem ItemResponseModel; do
  if grep -q "class $model" lib/domain/models.dart 2>/dev/null; then
    echo "  ✓ $model present" | tee -a "$REPORT_FILE"
  else
    echo "  ✗ $model MISSING" | tee -a "$REPORT_FILE"
  fi
done
echo ""

echo "══════════════════════════════════════════════════════"
echo "Report written to: $REPORT_FILE"
echo "══════════════════════════════════════════════════════"
