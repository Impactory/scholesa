# Export & Delete Runbook

## Export request
Input: learnerId + siteId
Outputs:
- JSON/CSV export of learning records
- Artifact links (time-limited)
- AI interaction log excerpt (if policy allows)

## Delete request
Steps:
- Verify requester authority
- Execute deletion jobs
- Verify Firestore docs removed
- Verify storage objects removed
- Record completion evidence

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/04-privacy/EXPORT_DELETE_RUNBOOK.md`
<!-- TELEMETRY_WIRING:END -->
