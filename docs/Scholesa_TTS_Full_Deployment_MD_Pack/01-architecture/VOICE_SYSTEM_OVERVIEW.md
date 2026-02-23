# Voice System Overview (Firebase + Cloud Run)

## Services
- Web App (Firebase Hosting): UI + audio capture/playback
- scholesa-api (Cloud Run): authz, policy, orchestration, signed URLs
- scholesa-ai (Cloud Run): BOS learning dialog + tool gating + safety
- scholesa-stt (Cloud Run): internal Speech-to-Text inference (no external)
- scholesa-tts (Cloud Run): internal Text-to-Speech inference (no external)
- Storage (GCS): short-lived audio blobs (TTL)
- Firestore: metadata and settings only (no raw audio storage)

## Voice-first flow (student)
Mic capture -> /voice/transcribe -> /copilot/message -> /tts/speak -> audio playback
All scoped by siteId/role/gradeBand derived from Firebase token claims.
