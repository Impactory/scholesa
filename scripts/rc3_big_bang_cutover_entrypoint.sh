#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

print_usage() {
  cat <<'EOF'
RC3 big-bang cutover entry point

Usage:
  bash ./scripts/rc3_big_bang_cutover_entrypoint.sh [--verify-artifacts] [--print-only]

Options:
  --verify-artifacts  Run the big-bang release artifact verification gate first.
  --print-only        Print the cutover sequence only.

This script does not mutate production by itself. It prints the exact operator flow,
the required commands, and the canonical evidence files for the current release policy.
EOF
}

VERIFY_ARTIFACTS=0
PRINT_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --verify-artifacts)
      VERIFY_ARTIFACTS=1
      ;;
    --print-only)
      PRINT_ONLY=1
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

if [[ "$VERIFY_ARTIFACTS" -eq 1 ]]; then
  echo "[cutover] Verifying big-bang release artifacts..."
  (cd "$ROOT_DIR" && npm run qa:release:big-bang-docs)
fi

cat <<EOF

============================================================
RC3 BIG-BANG CUTOVER ENTRY POINT
============================================================

Current production release-control artifacts:
1. RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md
2. RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md
3. RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md
4. RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md
5. RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md

Required command sequence:
1. npm run qa:release:big-bang-docs
2. npm run rc3:preflight
3. npm run qa:bos:mia:signoff
4. Execute the six-role browser sweep in RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md
5. Record outcomes in RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md
6. Copy final GO / NO-GO evidence into RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md and RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md

Learner AI hard gate:
- learner-facing BOS/MIA help is internal-inference only
- autonomous learner help requires certified confidence >= 0.97
- low-confidence, unavailable, or consent-blocked inference must escalate safely

Rollback rule:
- if any role fails, or learner-facing AI violates the guardrail, declare NO-GO and rollback the full release

Authoritative files:
- $ROOT_DIR/RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md
- $ROOT_DIR/RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md
- $ROOT_DIR/RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md
- $ROOT_DIR/RC3_PRODUCTION_READINESS_FINAL_SIGN_OFF.md
- $ROOT_DIR/RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md

EOF

if [[ "$PRINT_ONLY" -eq 0 ]]; then
  echo "[cutover] Entry point prepared. Follow the sequence above."
fi