# COPPA Voice Policy (Always-On)

## Scope
Applies to all student voice features (STT + TTS), especially under age 13 (K–5 defaults).

## Hard rules
1) No external vendors for voice processing (STT or TTS).
2) No child voice cloning. No training on child recordings.
3) Minimal retention:
   - Raw audio is ephemeral (minutes/hours), auto-deleted.
   - No raw audio stored in Firestore.
4) No individualized emotional profiling from voice.
5) No persuasive or manipulative voice styles for minors:
   - Use calm, neutral, supportive prosody.
6) Parent/school disclosure:
   - Voice features described in school notice and parent notice templates.

## Controls
- Tenant setting: voice_enabled
- Grade-band setting: voice_student_default_on (K–5 = ON with safe-mode, but allow opt-out)
- Quiet hours: teacher-configurable
- Audit logs: no raw content
