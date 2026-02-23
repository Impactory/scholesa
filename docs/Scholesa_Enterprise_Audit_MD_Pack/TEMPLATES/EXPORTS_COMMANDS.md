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
