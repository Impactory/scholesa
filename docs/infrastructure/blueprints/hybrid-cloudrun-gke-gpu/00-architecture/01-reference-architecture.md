# 01 Reference Architecture (Hybrid Cloud Run + GKE GPU)

## Goals
- Run Scholesa with **internal-only AI** (LLM, STT, TTS, embeddings, guardrails)
- Keep core product services on **Cloud Run**
- Run heavy inference on **GKE GPU** behind private networking
- Enforce **COPPA-native** retention, logging, and tenant isolation

## Topology
### Client layer
- Firebase Hosting (web)
- Firebase Auth (claims: siteId, role, gradeBand, locale)
- Optional: mobile app (same API gateway)

### Cloud Run (control plane + product plane)
- `scholesa-api` (gateway + RBAC + tenant scope)
- `scholesa-content` (subject packs, standards packs)
- `scholesa-guard` (policy/PII/injection/exfiltration)
- `scholesa-compliance` (audit operator + CI artifact generator)
- Optional: `scholesa-embed` (CPU embeddings) if you choose CPU models

### GKE GPU (inference plane)
- `llm-inference` (vLLM / TGI / llama.cpp-server depending on model)
- `stt-inference` (Whisper-class model)
- `tts-inference` (internal neural TTS)

## Request flows
### A) Student Voice Chat (voice-first)
1. Client records audio → `scholesa-api` (signed upload URL to `stt-uploads` bucket or direct stream)
2. `scholesa-api` → `scholesa-stt` (internal) → transcript
3. `scholesa-api` → `scholesa-guard` (context gate + safety policy)
4. `scholesa-api` → `scholesa-ai` (BOS orchestration)
5. `scholesa-ai` → `llm-inference` (GKE GPU)
6. Response text → `scholesa-guard` (output checks/redaction)
7. `scholesa-api` → `scholesa-tts` → audio URL (TTL) → client plays audio

### B) Teacher Feedback
- `scholesa-api` → `scholesa-ai` (rubric feedback) → returns draft text (teacher review required)

## Key security stance
- No direct client access to inference plane.
- All inference endpoints are private, reachable only from Cloud Run through VPC connectors / private ingress.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/01-reference-architecture.md`
<!-- TELEMETRY_WIRING:END -->
