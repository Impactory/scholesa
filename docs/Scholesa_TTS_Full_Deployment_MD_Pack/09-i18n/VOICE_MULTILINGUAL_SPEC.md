# Voice Multilingual Spec (en, zh-CN, zh-TW, th)

## Requirements
- STT locale set from UI + user profile + Accept-Language
- TTS voice model selection by locale
- Tokenization/segmentation per locale:
  - Thai: segmentation required
  - Chinese: segmentation + polyphonic handling where needed

## Tests
- Smoke transcripts in each locale
- Pronunciation regression for STEM terms per locale
- UTF-8 integrity export/import tests

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/09-i18n/VOICE_MULTILINGUAL_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
