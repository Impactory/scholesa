# Infrastructure as Code Overview

Preferred:
- Terraform modules for Cloud Run, IAM, Secret Manager, Artifact Registry
- CI-applied Firebase rules and indexes

Minimum expectation:
- Every Cloud Run service is reproducible (config documented)
- IAM policy is exported and reviewed quarterly
- Secrets live only in Secret Manager (not repo)
