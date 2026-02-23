# Data Stores

## Firestore
- Collections grouped under /sites/{siteId}/... recommended.
- Security rules enforce siteId == auth claim.

## Cloud Storage
- Portfolio artifacts and uploads.
- Signed URL flows must validate siteId ownership.

## BigQuery (optional)
- Event warehouse with partitioning and siteId in every row.

## Secrets
- Secret Manager with least-privilege access by service account.
