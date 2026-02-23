# No Advertising & No Behavioral Profiling Policy

Date: 2026-02-23

Scholesa does not:
- Display third-party ads to students.
- Track students across unrelated services for marketing.
- Sell student data.
- Build marketing behavioral profiles for students.

Allowed analytics are limited to educational and operational metrics only.

## Enforcement
- Policy enforcement script: `scripts/coppa_no_ad_audit.sh`
- CI/local command: `npm run audit:coppa:no-ads`
- Audit scans:
  - Dependency graph for ad/tracker libraries
  - Source patterns for ad tags, pixels, and tracking snippets

## Release Requirement
- Run the no-ads audit on each release candidate.
- Release blocked if prohibited ad/behavioral tracking patterns are detected.
