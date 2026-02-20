from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "CTA_REGRESSION_REPORT.md"
MISSING_PATTERN = re.compile(r"^\s*-\s+`[^`]+`:\s+\*\*missing\*\*\s*$")


def main() -> int:
    report_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_REPORT

    if not report_path.exists():
        print(f"ERROR: report file not found: {report_path}")
        return 2

    lines = report_path.read_text(errors="ignore").splitlines()
    missing_lines: list[tuple[int, str]] = []

    for line_number, line in enumerate(lines, 1):
        if MISSING_PATTERN.search(line):
            missing_lines.append((line_number, line.strip()))

    if missing_lines:
        print("CTA report gate FAILED: actionable missing telemetry entries found.")
        for line_number, text in missing_lines:
            print(f"- L{line_number}: {text}")
        return 1

    print("CTA report gate PASSED: no actionable missing telemetry entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
