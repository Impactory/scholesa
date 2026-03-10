from __future__ import annotations

NON_ACTIONABLE_WEB_PATHS = {
    "src/components/ui/Button.tsx",
    "src/types/FeedbackForm-impactory.tsx",
    "src/types/FeedbackForm.tsx",
    "src/types/SubmissionGrader.tsx",
}

NON_ACTIONABLE_FLUTTER_PATHS = {
    "apps/empire_flutter/app/lib/i18n/site_surface_i18n.dart",
}

NON_ACTIONABLE_BLOCKER_PATHS: dict[str, set[str]] = {
    "Flutter unimplemented handlers (`UnimplementedError`/`UnsupportedError`)": {
        "apps/empire_flutter/app/lib/firebase_options.dart",
    },
}

ROUTE_SURFACE_FILE_NAMES = {
    "page.tsx",
    "layout.tsx",
    "loading.tsx",
    "error.tsx",
    "not-found.tsx",
    "route.ts",
}
