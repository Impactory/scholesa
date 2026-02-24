# 14_MARKETING_CMS_SPEC.md

Marketing CMS supports public pages and lead capture with governance.

## Objects
- CmsPage (slug, audience, bodyJson, status)
- Lead (source, email, status)

## Publishing workflow
draft → review → published → archived

## Permissions
- public: read published public pages
- authenticated audiences: read only if role matches
- write: HQ-only (recommended)

## MVP
- render by slug
- HQ editor + preview
- lead capture form

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `14_MARKETING_CMS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
