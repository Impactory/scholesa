# Terraform Layout Blueprint (Hybrid)

## Recommended repository structure
/infra/
  /envs/
    /dev/
    /staging/
    /prod/
  /modules/
    /network/
    /cloudrun/
    /gke/
    /firestore/
    /storage/
    /secrets/
    /scheduler/
    /artifact-registry/

## Required resources
### Projects
- scholesa-dev, scholesa-staging, scholesa-prod (recommended separate projects)

### Network
- VPC + subnets
- Serverless VPC Access connector(s)
- NAT gateway
- Firewall rules (egress restrictions)

### Cloud Run
- services for: api, ai(orchestrator), guard, stt, tts, content, compliance
- per-service SA + IAM bindings

### GKE
- private cluster
- GPU node pool(s)
- workload identity
- internal ingress

### Storage
- buckets with lifecycle rules for voice TTL
- audit pack bucket

### Scheduler
- Cloud Scheduler job → compliance run endpoint with OIDC

### Artifact Registry
- container images for Cloud Run and GKE deployments

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/04-iac/01-terraform-layout.md`
<!-- TELEMETRY_WIRING:END -->
