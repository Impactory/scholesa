# Model Serving on GKE (GPU Inference Plane)

## Workloads
- llm-inference (GPU)
- stt-inference (GPU optional, CPU possible)
- tts-inference (GPU optional; depends on model)

## Recommended serving options
### LLM
- vLLM for high-throughput token streaming
- Text Generation Inference (TGI) for stable serving
- llama.cpp-server for quantized smaller models

### STT
- Whisper-like model server with batching
- Keep raw audio ephemeral

### TTS
- Internal TTS server with pre-approved voices
- No voice cloning endpoints

## Network model
- Inference services are **ClusterIP** internal
- Expose through an internal ingress (or private load balancer) reachable only from Cloud Run via VPC

## Autoscaling
- HPA based on GPU utilization / request queue depth
- Separate node pools per workload to avoid contention

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `infrastructure/blueprints/hybrid-cloudrun-gke-gpu/03-ai/02-model-serving-on-gke.md`
<!-- TELEMETRY_WIRING:END -->
