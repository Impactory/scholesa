# Cloud Run ↔ GKE Inference Auth Pattern (JWT + Optional mTLS)
Generated: 2026-02-23T16:48:32Z

This document describes **two safe patterns** to allow Cloud Run services (scholesa-ai/stt/tts) to call **internal-only** inference services on GKE (llm/stt/tts), without exposing inference publicly.

## Requirements
- Inference plane is private (ClusterIP + internal ingress / ILB).
- Cloud Run reaches inference via Serverless VPC connector.
- Requests are authenticated and authorized.
- No external AI egress.

---

## Pattern A (Recommended): Internal HTTPS Gateway + JWT Audience Verification
### Overview
1) Deploy an **internal gateway** in GKE (e.g., Envoy/Nginx) behind an **internal HTTP(S) Load Balancer**.
2) Cloud Run calls the gateway using **ID tokens** (OIDC) minted by its service account.
3) Gateway validates:
- token signature
- `aud` (audience)
- `iss`
- service account identity (`email` claim)
4) Gateway routes to ClusterIP services: llm-inference, stt-inference, tts-inference.

### Benefits
- Simple to operate
- Clear audit trail
- Strong identity boundary (service account → workload)

### Steps
**1. Create dedicated Cloud Run service accounts**
- sa-scholesa-ai, sa-scholesa-stt, sa-scholesa-tts

**2. Gateway audience**
Set an audience like:
- `https://inference.prod.internal.scholesa`

**3. Cloud Run: mint ID token**
- Use Google auth libraries to mint an ID token for the audience.
- Send: `Authorization: Bearer <id_token>`

**4. Gateway: validate token**
- Validate OIDC via Google public keys
- Verify `aud` matches expected
- Enforce allowlist of caller service account emails

**5. Gateway → services**
- Route to `llm-inference.svc.cluster.local:8000`, etc.

### Minimal gateway allowlist
- sa-scholesa-ai@PROJECT.iam.gserviceaccount.com
- sa-scholesa-stt@PROJECT.iam.gserviceaccount.com
- sa-scholesa-tts@PROJECT.iam.gserviceaccount.com

---

## Pattern B (Stronger): JWT + mTLS (Service Mesh Optional)
### Overview
Same as Pattern A, plus:
- Cloud Run → Gateway uses TLS
- Gateway → Inference services use **mTLS**
- Certificates rotated automatically (service mesh) or via cert-manager

### Benefits
- Adds cryptographic identity at transport layer
- Reduces lateral movement risk

### Notes
Cloud Run cannot natively participate in most mesh sidecars.
So mTLS is most useful **within the GKE cluster** (gateway → inference pods).

---

## Authorization rules (required)
- Only `scholesa-ai` may call llm-inference.
- Only `scholesa-stt` may call stt-inference.
- Only `scholesa-tts` may call tts-inference.
- Requests must include `X-Trace-Id` and are logged **without content**.

---

## Evidence artifacts
- `audit-pack/reports/inference-authz.json` (caller allowlist + tests)
- `audit-pack/reports/inference-ingress-private.json` (no public endpoint proof)
