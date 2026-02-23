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
