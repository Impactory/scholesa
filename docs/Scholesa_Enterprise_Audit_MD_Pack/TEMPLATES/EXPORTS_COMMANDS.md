# Export Commands (Examples)

Cloud Run service:
gcloud run services describe SERVICE --region REGION --format=json > cloudrun-services.json

Cloud Run IAM policy:
gcloud run services get-iam-policy SERVICE --region REGION --format=json > cloudrun-iam-policy.json

Firebase hosting config:
cat firebase.json > firebase.json.snapshot

Firestore rules:
cat firestore.rules > firestore.rules.txt

NOTE: Redact secrets/PII before sharing externally.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_MD_Pack/TEMPLATES/EXPORTS_COMMANDS.md`
<!-- TELEMETRY_WIRING:END -->
