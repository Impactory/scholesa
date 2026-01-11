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
