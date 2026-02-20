from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

WEB_EXTS = {".tsx", ".ts", ".jsx", ".js"}
DART_EXTS = {".dart"}


def collect_entries(base: Path, exts: set[str], pattern: re.Pattern[str]) -> list[tuple[str, list[tuple[int, str]]]]:
    entries: list[tuple[str, list[tuple[int, str]]]] = []
    if not base.exists():
        return entries

    for file_path in base.rglob("*"):
        if file_path.suffix.lower() not in exts:
            continue
        try:
            text = file_path.read_text(errors="ignore")
        except Exception:
            continue
        hits: list[tuple[int, str]] = []
        for index, line in enumerate(text.splitlines(), 1):
            if pattern.search(line):
                snippet = line.strip()
                if len(snippet) > 140:
                    snippet = f"{snippet[:137]}..."
                hits.append((index, snippet))
        if hits:
            entries.append((file_path.relative_to(ROOT).as_posix(), hits))
    return entries


def scan_pattern(base: Path, exts: set[str], pattern: re.Pattern[str]) -> list[tuple[str, int, str]]:
    findings: list[tuple[str, int, str]] = []
    if not base.exists():
        return findings

    for file_path in base.rglob("*"):
        if file_path.suffix.lower() not in exts:
            continue
        try:
            lines = file_path.read_text(errors="ignore").splitlines()
        except Exception:
            continue
        for index, line in enumerate(lines, 1):
            if pattern.search(line):
                snippet = line.strip()
                if len(snippet) > 140:
                    snippet = f"{snippet[:137]}..."
                findings.append((file_path.relative_to(ROOT).as_posix(), index, snippet))
    return findings


def main() -> None:
    web_pattern = re.compile(r"(onClick=|<button|<a href=|Link href=)")
    flutter_pattern = re.compile(
        r"(ElevatedButton\(|TextButton\(|OutlinedButton\(|FilledButton\(|IconButton\(|FloatingActionButton\(|InkWell\(|GestureDetector\(|ListTile\()"
    )

    web_entries = []
    for folder in ("app", "src"):
        web_entries.extend(collect_entries(ROOT / folder, WEB_EXTS, web_pattern))

    flutter_entries = collect_entries(ROOT / "apps/empire_flutter/app/lib", DART_EXTS, flutter_pattern)

    web_telemetry_patterns = [
        re.compile(r"useTelemetry|usePageViewTracking|useAutonomyTracking|useCompetenceTracking|useBelongingTracking|useAITracking"),
        re.compile(r"TelemetryService\.track\(|trackClick\(|trackPageView\(|trackAutonomy\(|trackCompetence\(|trackBelonging\(|trackAI\("),
    ]
    flutter_telemetry_patterns = [
        re.compile(r"TelemetryService\.instance\.logEvent\("),
        re.compile(r"import\s+['\"].*telemetry_service\.dart['\"]"),
    ]

    def file_has_any_pattern(path: Path, patterns: list[re.Pattern[str]]) -> bool:
        try:
            content = path.read_text(errors="ignore")
        except Exception:
            return False
        return any(pattern.search(content) for pattern in patterns)

    web_coverage: list[tuple[str, bool]] = []
    for relative_path, _ in sorted(web_entries):
        absolute_path = ROOT / relative_path
        has_telemetry = file_has_any_pattern(absolute_path, web_telemetry_patterns)
        web_coverage.append((relative_path, has_telemetry))

    flutter_coverage: list[tuple[str, bool]] = []
    for relative_path, _ in sorted(flutter_entries):
        absolute_path = ROOT / relative_path
        has_telemetry = file_has_any_pattern(absolute_path, flutter_telemetry_patterns)
        flutter_coverage.append((relative_path, has_telemetry))

    blocker_scans = {
        "Placeholder links (`href=\"#\"`)": scan_pattern(ROOT / "app", WEB_EXTS, re.compile(r'href="#"')),
        "Dead registration path (`/learner-registration`)": scan_pattern(
            ROOT / "app", WEB_EXTS, re.compile(r"/learner-registration")
        ),
        "Web TODO/FIXME in routes": scan_pattern(ROOT / "app", WEB_EXTS, re.compile(r"TODO|FIXME")),
        "Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`)": scan_pattern(
            ROOT / "apps/empire_flutter/app/lib", DART_EXTS, re.compile(r"UnimplementedError|throw UnsupportedError")
        ),
    }

    lines: list[str] = []
    lines.append("# CTA Regression Inventory")
    lines.append("")
    lines.append("Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Web files with CTA markers: **{len(web_entries)}**")
    lines.append(f"- Flutter files with CTA markers: **{len(flutter_entries)}**")
    lines.append(f"- Web CTA marker instances: **{sum(len(h) for _, h in web_entries)}**")
    lines.append(f"- Flutter CTA marker instances: **{sum(len(h) for _, h in flutter_entries)}**")
    lines.append("")
    lines.append("## Blocker Scan")
    lines.append("")
    for label, findings in blocker_scans.items():
        lines.append(f"- {label}: **{len(findings)}**")
    lines.append("")

    web_with_telemetry = sum(1 for _, has in web_coverage if has)
    flutter_with_telemetry = sum(1 for _, has in flutter_coverage if has)
    lines.append("## CTA Telemetry Coverage")
    lines.append("")
    lines.append(
        f"- Web CTA files with direct telemetry hooks/calls: **{web_with_telemetry}/{len(web_coverage)}**"
    )
    lines.append(
        f"- Flutter CTA files with direct telemetry import/calls: **{flutter_with_telemetry}/{len(flutter_coverage)}**"
    )
    lines.append("")

    lines.append("### Web Coverage Matrix")
    lines.append("")
    for path, has in web_coverage:
        status = "covered" if has else "missing"
        lines.append(f"- `{path}`: **{status}**")
    lines.append("")

    lines.append("### Flutter Coverage Matrix")
    lines.append("")
    for path, has in flutter_coverage:
        status = "covered" if has else "missing"
        lines.append(f"- `{path}`: **{status}**")
    lines.append("")

    for label, findings in blocker_scans.items():
        if not findings:
            continue
        lines.append(f"## {label} Findings")
        lines.append("")
        for path, line_number, snippet in findings[:80]:
            lines.append(f"- `{path}:L{line_number}` `{snippet}`")
        if len(findings) > 80:
            lines.append(f"- ... {len(findings) - 80} more")
        lines.append("")

    lines.append("## Web CTA Files")
    lines.append("")
    for path, hits in sorted(web_entries):
        lines.append(f"### `{path}` ({len(hits)})")
        for line_number, snippet in hits[:20]:
            lines.append(f"- L{line_number}: `{snippet}`")
        if len(hits) > 20:
            lines.append(f"- ... {len(hits) - 20} more")
        lines.append("")

    lines.append("## Flutter CTA Files")
    lines.append("")
    for path, hits in sorted(flutter_entries):
        lines.append(f"### `{path}` ({len(hits)})")
        for line_number, snippet in hits[:20]:
            lines.append(f"- L{line_number}: `{snippet}`")
        if len(hits) > 20:
            lines.append(f"- ... {len(hits) - 20} more")
        lines.append("")

    out_path = ROOT / "CTA_REGRESSION_REPORT.md"
    out_path.write_text("\n".join(lines) + "\n")
    print(out_path.as_posix())


if __name__ == "__main__":
    main()
