from __future__ import annotations

import re
from pathlib import Path
from typing import Callable
from cta_report_policy import (
    NON_ACTIONABLE_BLOCKER_PATHS,
    NON_ACTIONABLE_WEB_PATHS,
    ROUTE_SURFACE_FILE_NAMES,
)

ROOT = Path(__file__).resolve().parents[1]

WEB_EXTS = {".tsx", ".ts", ".jsx", ".js"}
DART_EXTS = {".dart"}
OUTPUT_REPORT = "CTA_FULL_INVENTORY.md"

FLUTTER_WIDGET_MARKER_PATTERN = re.compile(
    r"(\bElevatedButton\(|\bTextButton\(|\bOutlinedButton\(|\bFilledButton\(|\bIconButton\(|\bFloatingActionButton\(|\bInkWell\(|\bGestureDetector\(|\bListTile\(|\bRefreshIndicator\()"
)


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


def scan_pattern(
    base: Path,
    exts: set[str],
    pattern: re.Pattern[str],
    include_file: Callable[[Path], bool] | None = None,
) -> list[tuple[str, int, str]]:
    findings: list[tuple[str, int, str]] = []
    if not base.exists():
        return findings

    for file_path in base.rglob("*"):
        if file_path.suffix.lower() not in exts:
            continue
        if include_file and not include_file(file_path):
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


def is_route_surface_file(path: Path) -> bool:
    return path.name in ROUTE_SURFACE_FILE_NAMES


def main() -> None:
    web_pattern = re.compile(r"(onClick=|<button|<a href=|Link href=)")
    web_quick_action_pattern = re.compile(r"Quick Action|Quick Actions|quick[_\s-]?action")
    flutter_pattern = FLUTTER_WIDGET_MARKER_PATTERN
    flutter_quick_action_pattern = re.compile(r"Quick Action|Quick Actions|quick[_\s-]?action")

    web_entries = []
    for folder in ("app", "src"):
        web_entries.extend(collect_entries(ROOT / folder, WEB_EXTS, web_pattern))

    web_quick_action_entries = []
    for folder in ("app", "src"):
        web_quick_action_entries.extend(
            collect_entries(ROOT / folder, WEB_EXTS, web_quick_action_pattern)
        )

    excluded_web_entries = [
        entry for entry in web_entries if entry[0] in NON_ACTIONABLE_WEB_PATHS
    ]
    web_entries = [entry for entry in web_entries if entry[0] not in NON_ACTIONABLE_WEB_PATHS]
    web_quick_action_entries = [
        entry for entry in web_quick_action_entries if entry[0] not in NON_ACTIONABLE_WEB_PATHS
    ]

    flutter_entries = collect_entries(ROOT / "apps/empire_flutter/app/lib", DART_EXTS, flutter_pattern)
    flutter_quick_action_entries = collect_entries(
        ROOT / "apps/empire_flutter/app/lib", DART_EXTS, flutter_quick_action_pattern
    )

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

    web_quick_action_paths = {path for path, _ in web_quick_action_entries}
    web_quick_action_coverage: list[tuple[str, bool]] = []
    for relative_path in sorted(web_quick_action_paths):
        absolute_path = ROOT / relative_path
        has_telemetry = file_has_any_pattern(absolute_path, web_telemetry_patterns)
        web_quick_action_coverage.append((relative_path, has_telemetry))

    flutter_coverage: list[tuple[str, bool]] = []
    for relative_path, _ in sorted(flutter_entries):
        absolute_path = ROOT / relative_path
        has_telemetry = file_has_any_pattern(absolute_path, flutter_telemetry_patterns)
        flutter_coverage.append((relative_path, has_telemetry))

    flutter_quick_action_paths = {path for path, _ in flutter_quick_action_entries}
    flutter_quick_action_coverage: list[tuple[str, bool]] = []
    for relative_path in sorted(flutter_quick_action_paths):
        absolute_path = ROOT / relative_path
        has_telemetry = file_has_any_pattern(absolute_path, flutter_telemetry_patterns)
        flutter_quick_action_coverage.append((relative_path, has_telemetry))

    blocker_scans = {
        "Placeholder links (`href=\"#\"`)": scan_pattern(ROOT / "app", WEB_EXTS, re.compile(r'href="#"')),
        "Dead registration path (`/learner-registration`)": scan_pattern(
            ROOT / "app", WEB_EXTS, re.compile(r"/learner-registration")
        ),
        "Web TODO/FIXME in routes": scan_pattern(
            ROOT / "app",
            WEB_EXTS,
            re.compile(r"TODO|FIXME"),
            include_file=is_route_surface_file,
        ),
        "Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`)": scan_pattern(
            ROOT / "apps/empire_flutter/app/lib", DART_EXTS, re.compile(r"UnimplementedError|throw UnsupportedError")
        ),
    }

    excluded_blocker_scans: dict[str, list[tuple[str, int, str]]] = {}
    for label, findings in blocker_scans.items():
        excluded_paths = NON_ACTIONABLE_BLOCKER_PATHS.get(label, set())
        excluded_findings = [item for item in findings if item[0] in excluded_paths]
        filtered_findings = [item for item in findings if item[0] not in excluded_paths]
        blocker_scans[label] = filtered_findings
        if excluded_findings:
            excluded_blocker_scans[label] = excluded_findings

    lines: list[str] = []
    lines.append("# CTA Full Inventory & Regression Source")
    lines.append("")
    lines.append("Generated from first-party source in `app/`, `src/`, and `apps/empire_flutter/app/lib/`.")
    lines.append("")
    lines.append("## Scan Policy")
    lines.append("")
    lines.append("- Actionable CTA coverage includes UI files with direct user-interaction markers and expected telemetry hooks/calls.")
    lines.append("- Excluded non-actionable web files are utility/type-only paths listed in `NON_ACTIONABLE_WEB_PATHS`.")
    lines.append("- Blocker findings exclude known generated/framework stubs listed in `NON_ACTIONABLE_BLOCKER_PATHS`.")
    lines.append("- Route TODO/FIXME blocker scan is restricted to route surfaces (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `route.ts`).")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Web files with CTA markers: **{len(web_entries)}**")
    lines.append(f"- Flutter files with CTA markers: **{len(flutter_entries)}**")
    lines.append(f"- Web CTA marker instances: **{sum(len(h) for _, h in web_entries)}**")
    lines.append(f"- Flutter CTA marker instances: **{sum(len(h) for _, h in flutter_entries)}**")
    lines.append(f"- Web files with quick-action markers: **{len(web_quick_action_entries)}**")
    lines.append(f"- Flutter files with quick-action markers: **{len(flutter_quick_action_entries)}**")
    lines.append(
        f"- Web quick-action marker instances: **{sum(len(h) for _, h in web_quick_action_entries)}**"
    )
    lines.append(
        f"- Flutter quick-action marker instances: **{sum(len(h) for _, h in flutter_quick_action_entries)}**"
    )
    lines.append("")
    lines.append("## Blocker Scan")
    lines.append("")
    for label, findings in blocker_scans.items():
        lines.append(f"- {label}: **{len(findings)}**")
    if excluded_blocker_scans:
        excluded_total = sum(len(items) for items in excluded_blocker_scans.values())
        lines.append(f"- Excluded non-actionable blocker findings: **{excluded_total}**")
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

    web_quick_action_with_telemetry = sum(1 for _, has in web_quick_action_coverage if has)
    flutter_quick_action_with_telemetry = sum(
        1 for _, has in flutter_quick_action_coverage if has
    )
    lines.append("## Quick Actions Coverage")
    lines.append("")
    lines.append(
        "- Web quick-action files with direct telemetry hooks/calls: "
        f"**{web_quick_action_with_telemetry}/{len(web_quick_action_coverage)}**"
    )
    lines.append(
        "- Flutter quick-action files with direct telemetry import/calls: "
        f"**{flutter_quick_action_with_telemetry}/{len(flutter_quick_action_coverage)}**"
    )
    lines.append("")

    lines.append("### Web Quick Actions Coverage Matrix")
    lines.append("")
    if web_quick_action_coverage:
        for path, has in web_quick_action_coverage:
            status = "covered" if has else "missing"
            lines.append(f"- `{path}`: **{status}**")
    else:
        lines.append("- _none detected_")
    lines.append("")

    lines.append("### Flutter Quick Actions Coverage Matrix")
    lines.append("")
    if flutter_quick_action_coverage:
        for path, has in flutter_quick_action_coverage:
            status = "covered" if has else "missing"
            lines.append(f"- `{path}`: **{status}**")
    else:
        lines.append("- _none detected_")
    lines.append("")

    lines.append("### Web Coverage Matrix")
    lines.append("")
    for path, has in web_coverage:
        status = "covered" if has else "missing"
        lines.append(f"- `{path}`: **{status}**")
    lines.append("")

    if excluded_web_entries:
        lines.append("### Excluded Web Utility/Type Files")
        lines.append("")
        for path, _ in sorted(excluded_web_entries):
            lines.append(f"- `{path}`: **excluded_non_actionable**")
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

    if excluded_blocker_scans:
        lines.append("## Excluded Blocker Findings")
        lines.append("")
        for label, findings in excluded_blocker_scans.items():
            lines.append(f"### {label}")
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

    lines.append("## Web Quick Actions Files")
    lines.append("")
    for path, hits in sorted(web_quick_action_entries):
        lines.append(f"### `{path}` ({len(hits)})")
        for line_number, snippet in hits[:20]:
            lines.append(f"- L{line_number}: `{snippet}`")
        if len(hits) > 20:
            lines.append(f"- ... {len(hits) - 20} more")
        lines.append("")

    lines.append("## Flutter Quick Actions Files")
    lines.append("")
    for path, hits in sorted(flutter_quick_action_entries):
        lines.append(f"### `{path}` ({len(hits)})")
        for line_number, snippet in hits[:20]:
            lines.append(f"- L{line_number}: `{snippet}`")
        if len(hits) > 20:
            lines.append(f"- ... {len(hits) - 20} more")
        lines.append("")

    out_path = ROOT / OUTPUT_REPORT
    legacy_path = ROOT / "CTA_REGRESSION_REPORT.md"

    rendered = "\n".join(lines) + "\n"
    out_path.write_text(rendered)
    legacy_path.write_text(rendered)
    print(out_path.as_posix())


if __name__ == "__main__":
    main()
