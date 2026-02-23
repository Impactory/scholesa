# Deferment Log

These requirements are deferred while the web stack (Next.js/PWA/Cloud Run) remains paused. Flutter equivalents for data models/repos are implemented; revisit when re-enabling web.

| Req ID | Reason | Notes |
| --- | --- | --- |
| REQ-024 to REQ-027 | Web dashboards (parent/site/partner/HQ) paused | Flutter equivalents pending; resume with web stack. |
| REQ-031 | Web invariants + tests paused | Flutter client-side validation added; formal web tests remain deferred. |
| REQ-033 | Web unit tests suite | Run/extend when web stack resumes. |
| REQ-034 | Web smoke/QA scripts | Execute after web reactivation. |
| REQ-035 | Web build/PWA readiness | Hold until web stack re-enabled. |
| REQ-036 | Cloud Run/API build | Hold until web/API resumed. |
| REQ-039 | Web offline fallback page | PWA stack paused. |
| REQ-040 | Web i18n coverage | Web paused; translations on hold. |
| REQ-043 | CI checks (web) | Pipeline paused; re-enable with web. |
| REQ-045 | PWA cache strategy | Paused with web. |

## Re-enable Checklist
1) Unpause web stack; set env vars.
2) Run `npm install` and `npm test`.
3) Run `npm run build` and address PWA/runtimeCaching.
4) Resume repos/tests for remaining deferred items (REQ-024–027, 031, 033–036, 039–040, 043, 045).
