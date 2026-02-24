# Scholesa Infrastructure Blueprint — Hybrid Cloud Run + GKE GPU (COPPA-native)
Generated: 2026-02-23T16:27:48Z

This docs pack is designed to be copied into your repo under:

`docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/`

## What’s inside
- Reference architecture for Firebase + Cloud Run + GKE GPU inference
- Service contracts for internal AI (LLM/STT/TTS/Embeddings/Guardrails/Compliance)
- Network & IAM model (tenant isolation, egress restrictions, service-to-service auth)
- Data/retention model (voice TTL, logs hygiene, COPPA evidence)
- IaC scaffolding (Terraform layout blueprint + required resources list)
- CI/CD release gates and audit artifact requirements
- Runbooks for operations and incident response
- K–12 content modularization layout (subject packs, standards packs, prompt modules)
- Master audit enforcement contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`

## Hard constraints
- No external AI vendors (Gemini/OpenAI/Anthropic/etc.)
- COPPA-safe defaults (no training on student data, no raw audio retention, no raw logs)
- Tenant isolation absolute (siteId from verified claims only)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/README.md`
<!-- TELEMETRY_WIRING:END -->
