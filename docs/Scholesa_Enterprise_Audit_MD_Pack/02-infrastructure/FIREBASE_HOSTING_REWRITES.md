# Firebase Hosting Rewrites

Required:
- /api/** -> Cloud Run scholesa-api
- /ai/**  -> Cloud Run scholesa-ai
- SPA fallback -> /index.html

Evidence:
- firebase.json snapshot
- Firebase Hosting release version
- Cloud Run service existence + region

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/02-infrastructure/FIREBASE_HOSTING_REWRITES.md`
<!-- TELEMETRY_WIRING:END -->
