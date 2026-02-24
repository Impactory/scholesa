# Internal Ingress / Private Access Notes (GKE)

You have two common patterns to let Cloud Run reach ClusterIP inference services securely:

## Pattern A — Internal HTTP(S) Load Balancer (recommended)
- Deploy an Ingress controller configured for internal load balancing
- Create Ingress resources pointing to llm/stt/tts services
- Restrict source ranges to serverless connector/NAT IP ranges
- Use mTLS or signed JWT between Cloud Run and inference gateway

## Pattern B — Private Service Connect / service mesh (advanced)
- Use PSC endpoints to expose services privately to Cloud Run VPC
- Enforce identity at layer 7

In both patterns:
- Do not expose inference plane publicly
- Do not allow general internet egress from inference pods

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `k8s/50-internal-ingress-notes.md`
<!-- TELEMETRY_WIRING:END -->
