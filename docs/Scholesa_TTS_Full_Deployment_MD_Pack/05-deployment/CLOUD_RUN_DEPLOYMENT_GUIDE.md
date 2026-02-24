# Cloud Run Deployment Guide (scholesa-stt + scholesa-tts)

## Services
- scholesa-stt: CPU/GPU as needed, ingress internal+LB preferred
- scholesa-tts: GPU optional for premium voice, ingress internal+LB preferred

## Required configurations per service
- Dedicated service account (least privilege)
- Explicit concurrency/timeouts
- Min instances for prod if latency critical
- Structured JSON logging enabled

## Storage
- GCS bucket: scholesa-voice-audio
- Lifecycle: delete objects after short TTL (e.g., 1 hour)
- Signed URL issuance via scholesa-api only

## Egress
- Restrict outbound network to prevent vendor calls (policy + tests)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/05-deployment/CLOUD_RUN_DEPLOYMENT_GUIDE.md`
<!-- TELEMETRY_WIRING:END -->
