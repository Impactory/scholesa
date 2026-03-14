# REQ-043 Local CI Proof

Date: 2026-03-13

## Scope

Requirement: CI checks for lint, type, and test.

Updated workflow coverage:

- `.github/workflows/ci.yml`
- `.github/workflows/release-validation.yml`
- root `package.json` now includes an explicit `typecheck` script
- workflows now run root lint, root typecheck, and `npm --prefix functions run build` as first-class gates

## Local Proof

Commands run from repo root:

```bash
npm run typecheck
npm --prefix functions run build
npm run lint
npm run build
npm run test:e2e:web
```

Results:

- `npm run typecheck`: passed
- `npm --prefix functions run build`: passed
- `npm run lint`: passed cleanly after removing unused-symbol warnings in functions sources
- `npm run build`: passed
- `npm run test:e2e:web`: passed, 14/14 Playwright tests green

## Notes

- The web build and Playwright webServer build still emit the known non-blocking `next-pwa` / Workbox deprecation warnings already captured in `DEPENDENCY_BASELINE_SCHOLESA.md`.
- Those warnings did not fail the build and are package debt, not a current Scholesa config regression.