# Egress Restrictions (No External AI)

## Objective
Prevent accidental or malicious outbound calls to external AI vendors (Gemini/OpenAI/etc.)

## Strategy (defense-in-depth)
1) Code-level denylist interceptor (shared HTTP client)
- hard-block requests to banned domains
- emit security event `SECURITY_EGRESS_BLOCKED`

2) Network-level restrictions
- Cloud Run services use VPC connector + egress settings to route through controlled NAT
- Firewall denylist (or allowlist) at VPC level for outbound traffic
- Prefer allowlisting only required Google APIs + internal endpoints

3) CI gates
- dependency ban (vendor SDKs)
- domain ban (vendor endpoints)
- secret ban (vendor keys)
- runtime egress proof test

## Evidence
`audit-pack/reports/vendor-egress-proof.json`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/01-security/02-egress-restrictions.md`
<!-- TELEMETRY_WIRING:END -->
