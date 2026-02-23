# CI/CD Release Gates (Audit-Grade)

## Blocker gates (must pass to merge/deploy)
1) vendor dependency ban (no external AI SDKs)
2) vendor domain ban (no external AI endpoints)
3) vendor secret ban (no vendor keys)
4) runtime egress proof (no outbound to banned domains)
5) tenant isolation integration tests
6) voice retention TTL checks
7) logging no-raw-content checks
8) i18n coverage checks (en, zh-CN, zh-TW, th)

## Required artifacts
Upload as build artifacts:
- `audit-pack/reports/*.json`
- `audit-pack/reports/coppa-controls-summary.json`

## Enforcement
- `scholesa-compliance` can generate reports, but CI must fail on blocker failures.
