# Storage & Retention (COPPA)

## Buckets
1) `stt-uploads` (raw audio inputs)
- TTL: 15–60 minutes (recommend 30m)
- Not included in long-term backups

2) `tts-audio`
- TTL: 1 hour (recommend 1h)
- Signed URL access only

3) `audit-pack`
- Retain compliance artifacts (no raw student content)
- Retention per your audit policy

## Firestore retention
- Student transcripts: OFF by default for K–5; configurable by district
- If stored, treat as educational record with retention controls
- Logs must not contain transcripts

## Evidence
- `audit-pack/reports/voice-retention-ttl.json`
- `audit-pack/reports/logging-no-raw-content.json`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/02-data/01-storage-and-retention.md`
<!-- TELEMETRY_WIRING:END -->
