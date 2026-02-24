# BOS Branch Map (Voice Input + Voice Output)

## Branch families
A) Voice Input Branches (STT)
- A1 Capture Hygiene: noise/volume checks, consent checks, mic availability
- A2 Chunking: segment audio into safe windows
- A3 STT Inference: internal model, locale aware
- A4 STT Cleanup: punctuation, disfluency handling, safe normalization
- A5 Safety Filter (input): detect disallowed content for minors
- A6 Audit Trace: traceId + metrics only

B) Dialogue & Learning Branches
- B1 Role Gate: student/teacher/admin capability gating
- B2 Context Assembly: minimal, permissioned context only
- B3 Safety Policy: prompt injection defense + refusal policy
- B4 Learning Integrity: explain-back + checkpoints + reflection
- B5 Response Formatting: locale + reading level + brevity controls
- B6 Audit Trace: metadata only

C) Voice Output Branches (TTS)
- C1 Text Normalization: numbers/units/dates/acronyms
- C2 Segmentation: clause chunking, locale-specific tokenization
- C3 Pronunciation: lexicon + phoneme overrides
- C4 Prosody Policy: grade-band safe profiles
- C5 TTS Synthesis: internal model
- C6 Redaction: remove identifiers before speaking if required
- C7 Audit Trace: metrics only
- C8 Cache: safe caching rules

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/01-architecture/BOS_BRANCH_MAP.md`
<!-- TELEMETRY_WIRING:END -->
