# Model Provenance & Training (Internal Voice Models)

## Requirements
- Training data must be properly licensed
- No child voice data used for model training
- No student audio used for training by default
- Model versioning required (modelVersion in metadata)

## Documentation
For each model:
- name + version
- architecture family (internal)
- training dataset sources + licenses (high level)
- intended languages
- limitations
- safety constraints (K–12)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/11-models/MODEL_PROVENANCE_AND_TRAINING.md`
<!-- TELEMETRY_WIRING:END -->
