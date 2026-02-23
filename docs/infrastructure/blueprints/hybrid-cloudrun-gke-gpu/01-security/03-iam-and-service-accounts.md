# IAM & Service Accounts (Least Privilege)

## Principles
- One service account per service
- Only grant minimum required roles
- Prefer Cloud Run IAM for service-to-service auth

## Recommended service accounts
- sa-scholesa-api
- sa-scholesa-ai
- sa-scholesa-guard
- sa-scholesa-stt
- sa-scholesa-tts
- sa-scholesa-content
- sa-scholesa-compliance

## Access guidelines
### Firestore
- Only scholesa-api and scholesa-content need write access to tenant content.
- scholesa-ai should not write student records directly (use scholesa-api tool bus).

### GCS buckets
- stt-uploads: write by scholesa-api (signed URL mint) and read by scholesa-stt
- tts-audio: write by scholesa-tts; read only via signed URLs
- audit-pack: write by scholesa-compliance; read by admins only

### Secret Manager
- no vendor keys stored
- internal model endpoints/config only
