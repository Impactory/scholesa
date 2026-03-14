# REQ-115 WCAG 2.2 AA Automation Proof

Date: 2026-03-14

Requirement: REQ-115 WCAG 2.2 AA automated checks in CI or audit automation

Files added or updated:
- `.github/workflows/ci.yml`
- `package.json`
- `test/e2e/accessibility.e2e.spec.ts`
- `app/layout.tsx`
- `app/globals.css`
- `src/components/layout/PageTransition.tsx`
- `src/lib/theme/ThemeModeToggle.tsx`
- `app/[locale]/page.tsx`
- `app/[locale]/(auth)/login/page.tsx`
- `app/[locale]/(auth)/register/page.tsx`

Local proof:
- `rm -rf .next && npm run test:e2e:web:wcag`
- `npm run build`

Observed result:
- `npm run test:e2e:web:wcag` passed with 2/2 Playwright accessibility audits green.
- `npm run build` passed after the WCAG automation and entry-surface accessibility fixes.

Coverage provided by the gate:
- Axe-core browser audit for the landing page.
- Axe-core browser audit for localized auth routes in `en`, `zh-CN`, and `zh-TW`.
- CI enforcement through the dedicated `WCAG 2.2 AA browser audit` workflow step.
- Reduced-motion-safe route transitions and deterministic theme initialization for accessibility audits.

Status:
- REQ-115 can be marked complete.