# 02 Service Map & Responsibilities

## Cloud Run services
### scholesa-api
- AuthN/AuthZ, tenant scoping, CRUD, mission runtime
- Canonical AI schema assembly
- Signed URL minting for voice objects
- Enforces tool allowlists by role/gradeBand

### scholesa-ai (orchestrator)
- BOS orchestration (hint ladder, explain-back, misconception targeting)
- Prompt module assembly by subject/grade/role
- Calls LLM inference via internal client
- Emits audit telemetry (no raw content)

### scholesa-guard
- Prompt injection defense
- Cross-tenant exfiltration detection
- PII redaction checks (K–5 strongest)
- Safety escalation triggers & templates

### scholesa-stt
- Audio ingestion + transcription via GKE endpoint
- Returns transcript + confidence

### scholesa-tts
- TTS rendering via GKE endpoint
- Stores output audio with short TTL and returns signed URL

### scholesa-content
- Validates subject packs and standards packs
- Serves scope/sequence/unit graphs
- Provides content payloads to BOS (retrieval)

### scholesa-compliance
- Runs policy-as-code checks, drift detection
- Generates `/audit-pack/reports/*.json`
- Provides evidence endpoints and run metadata

## GKE inference workloads (GPU)
- llm-inference
- stt-inference
- tts-inference

## Shared components
- Firestore
- GCS (voice TTL buckets + content artifacts + audit pack)
- Vector store (pgvector/Qdrant/etc.)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/02-service-map.md`
<!-- TELEMETRY_WIRING:END -->
