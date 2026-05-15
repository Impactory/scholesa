# Scholesa Public Site Design Language Plan

## Source

The Summer Camp 2026 source file defines the public-facing design language for Scholesa marketing and legal surfaces:

- Deep navy editorial hero backgrounds with teal and gold light fields
- Warm cream/off-white page sections
- Gold primary CTAs, teal capability accents, coral/purple as secondary accents
- Serif display headlines paired with the existing Scholesa sans stack
- Rounded pill badges, glass hero panels, compact evidence cards, and clear stats bands
- Public copy that stays capability-first: what learners build, explain, improve, and show

## Where It Applies

Apply this language to unauthenticated/public Scholesa routes only:

- Locale landing pages: `/{locale}`
- Public program pages such as `/{locale}/summer-camp-2026`
- Public legal/trust routes such as `/{locale}/privacy`
- Future public evidence explainers, program pages, and family-facing marketing entrypoints

Do not apply this editorial language to protected classroom workflows. Educator, learner, HQ, site, partner, and guardian dashboards should keep the denser operational UI unless a public-facing route is being built.

## Shared Implementation

The shared public layer lives in `app/globals.css` as `public-*` utilities:

- `public-site`
- `public-header`
- `public-hero`
- `public-display-title`
- `public-kicker`
- `public-chip`
- `public-panel`
- `public-card`
- `public-button-primary`
- `public-button-secondary`
- `public-stat-band`
- `public-section-cream`
- `public-section-offwhite`
- `public-section-dark`

These utilities intentionally avoid external font/CDN dependencies and reuse local assets only.

## Security And Stability Rules

- Do not paste standalone HTML/CSS directly into Next routes.
- Do not load external fonts, trackers, or third-party scripts for public marketing polish.
- Keep CTAs explicit and safe: `mailto:`, `tel:`, or internal locale-aware `Link` routes.
- Keep generated service-worker behavior minimal; avoid stale Workbox precaching unless there is a verified PWA strategy.
- Route public pages through the Next app consistently from the Flutter/nginx edge.

## Path To Gold

This public design pass supports gold readiness only for the public-site layer. Blanket Gold still requires:

1. Automated checks green: lint, typecheck, build, tests, secret scan, AI internal-only guardrails, runtime smoke.
2. Dependency audit with no high or critical findings.
3. Live `scholesa.com` probes for landing, legal, program, app shell, and health routes.
4. Six-role production cutover verification with real or canonical production-like data.
5. Evidence-chain verification from setup to session runtime to evidence, proof, rubric, growth, portfolio, and reporting.

## Current Status

Applied to:

- `app/[locale]/page.tsx`
- `app/[locale]/summer-camp-2026/page.tsx`
- `Dockerfile.flutter` route bridge for public Next routes

Next recommended public-site pass:

- Move the header shell into a shared public component once one more public route needs it.
- Add a program index if more than one public program exists.
- Add screenshot checks for desktop and mobile public routes before calling the public layer complete.
