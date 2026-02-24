# Runbook — Export/Delete for Voice Data

## Default stance
No long-term raw audio storage. Exports focus on metadata only.

## If requested by district
- Export: list of voice feature usage events (counts, timestamps)
- No raw audio included unless explicitly contracted and consented

## Deletion
- Confirm no voice blobs persist beyond TTL
- Confirm any cached audio cleared
- Provide deletion verification report

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/07-ops/RUNBOOK_EXPORT_DELETE_VOICE.md`
<!-- TELEMETRY_WIRING:END -->
