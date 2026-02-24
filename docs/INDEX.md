# INDEX.md

## Engineering playbooks
- 48_FEATURE_MODULE_BUILD_PLAYBOOK.md
- 49_ROUTE_FLIP_TRACKER.md
- 50_PROVIDER_WIRING_PATTERNS.md

## Launch and compliance
- 51_IMPLEMENTATION_AUDIT_GO_LIVE.md
- Scholesa_Go_Live_Readiness_Checklist.docx

## Infrastructure telemetry
- infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `INDEX.md`
<!-- TELEMETRY_WIRING:END -->
