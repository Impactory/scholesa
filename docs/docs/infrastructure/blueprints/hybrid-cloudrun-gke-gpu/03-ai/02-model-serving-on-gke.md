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
