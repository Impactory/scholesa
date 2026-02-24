# Scholesa Infrastructure (Terraform) — Hybrid Cloud Run + GKE GPU
Generated: 2026-02-23T16:43:27Z

This folder provides **Terraform module stubs** (skeletons) to implement the blueprint in:
`docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/04-iac/01-terraform-layout.md`

## Structure
- `infra/envs/dev|staging|prod` — environment compositions (wire modules + set vars)
- `infra/modules/*` — reusable building blocks

## Usage (typical)
1) Copy/merge into your repo root (or `dev/scholesa/infra`)
2) Configure backend (state) per environment (GCS recommended)
3) Fill in variables in `envs/*/terraform.tfvars`
4) `terraform init && terraform plan && terraform apply`

## Notes
- These are stubs: placeholders marked `TODO:` must be completed for your org/regions/projects.
- Ensure voice buckets have lifecycle rules and are excluded from long-term backups.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infra/README.md`
<!-- TELEMETRY_WIRING:END -->
