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
