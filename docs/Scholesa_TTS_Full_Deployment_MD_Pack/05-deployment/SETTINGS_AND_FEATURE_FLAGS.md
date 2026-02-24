# Settings & Feature Flags (Tenant + Grade Band)

Store settings in Firestore under /sites/{siteId}/settings/voice

## Tenant flags
- voiceEnabled: boolean
- studentVoiceDefaultOn: boolean
- teacherVoiceEnabled: boolean
- adminVoiceEnabled: boolean
- allowedLocales: [en, zh-CN, zh-TW, th]
- quietHours: schedule rules (optional)

## Grade band policy
- K–5: voice nudges ON, safe prosody profile enforced
- 6–8: voice nudges ON, normal prosody profile
- 9–12: voice nudges optional, normal prosody

## Enforcement
Settings are enforced server-side in scholesa-api.
Client UI must reflect server response, not local assumptions.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/05-deployment/SETTINGS_AND_FEATURE_FLAGS.md`
<!-- TELEMETRY_WIRING:END -->
