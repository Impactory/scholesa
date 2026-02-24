# Scholesa Inference Plane (Kubernetes) — Manifests Blueprint
Generated: 2026-02-23T16:43:27Z

These manifests are **blueprints** for deploying GPU inference workloads on GKE:

- `llm-inference` (vLLM/TGI)
- `stt-inference` (Whisper-class)
- `tts-inference` (internal neural TTS)

## Security model
- Namespace isolated (`scholesa-inference`)
- ClusterIP services only
- Internal Ingress / Internal Load Balancer only
- NetworkPolicies recommended
- No external internet egress required for inference pods

## Deployment notes
- Use Workload Identity where possible
- Store model artifacts in a private bucket or persistent volume
- Do NOT store any student audio beyond processing; enforce TTL at storage layer

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `k8s/README.md`
<!-- TELEMETRY_WIRING:END -->
