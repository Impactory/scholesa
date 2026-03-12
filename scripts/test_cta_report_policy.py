from __future__ import annotations

import tempfile
import unittest
import re
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if SCRIPTS_DIR.as_posix() not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR.as_posix())

from cta_report_policy import (
    NON_ACTIONABLE_BLOCKER_PATHS,
    NON_ACTIONABLE_WEB_PATHS,
    ROUTE_SURFACE_FILE_NAMES,
)
from generate_cta_report import (
    FLUTTER_WIDGET_MARKER_PATTERN,
    ROOT,
    WEB_EXTS,
    is_route_surface_file,
    scan_pattern,
)


class CtaReportPolicyTests(unittest.TestCase):
    def test_policy_contains_expected_non_actionable_entries(self) -> None:
        self.assertIn("src/components/ui/Button.tsx", NON_ACTIONABLE_WEB_PATHS)
        self.assertNotIn("src/types/FeedbackForm.tsx", NON_ACTIONABLE_WEB_PATHS)
        self.assertNotIn("src/types/SubmissionGrader.tsx", NON_ACTIONABLE_WEB_PATHS)

        blocker_key = "Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`)"
        self.assertIn(blocker_key, NON_ACTIONABLE_BLOCKER_PATHS)
        self.assertIn(
            "apps/empire_flutter/app/lib/firebase_options.dart",
            NON_ACTIONABLE_BLOCKER_PATHS[blocker_key],
        )

    def test_route_surface_file_name_set(self) -> None:
        self.assertIn("page.tsx", ROUTE_SURFACE_FILE_NAMES)
        self.assertIn("route.ts", ROUTE_SURFACE_FILE_NAMES)
        self.assertNotIn("widget.tsx", ROUTE_SURFACE_FILE_NAMES)

    def test_scan_pattern_respects_route_surface_filter(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT.as_posix()) as temp_dir:
            base = Path(temp_dir)
            app_dir = base / "app"
            app_dir.mkdir(parents=True, exist_ok=True)

            page_file = app_dir / "page.tsx"
            helper_file = app_dir / "helper.ts"

            page_file.write_text("// TODO: route-level follow-up\n")
            helper_file.write_text("// TODO: helper follow-up\n")

            findings = scan_pattern(
                app_dir,
                WEB_EXTS,
                pattern=re.compile(r"TODO|FIXME"),
                include_file=is_route_surface_file,
            )

            self.assertEqual(len(findings), 1)
            self.assertTrue(findings[0][0].endswith("app/page.tsx"))

    def test_flutter_widget_pattern_avoids_constructor_false_positives(self) -> None:
        self.assertIsNotNone(FLUTTER_WIDGET_MARKER_PATTERN.search("child: ListTile("))
        self.assertIsNone(FLUTTER_WIDGET_MARKER_PATTERN.search("const MissionListTile({"))
        self.assertIsNone(FLUTTER_WIDGET_MARKER_PATTERN.search("const ColorfulListTile({"))


if __name__ == "__main__":
    unittest.main()
