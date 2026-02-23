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
