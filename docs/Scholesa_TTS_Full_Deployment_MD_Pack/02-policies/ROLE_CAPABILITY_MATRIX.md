# Role Capability Matrix — Voice Copilot

## Student
Allowed:
- Voice input (STT) for questions, reasoning, reflections
- Voice output (TTS) for hints, instructions, read-aloud
- Translation (if enabled)
Forbidden:
- Access other learners
- Teacher notes
- Admin configs
- Raw logs

## Teacher
Allowed:
- Voice summaries of class progress (aggregated)
- Draft feedback (teacher reviews before sending)
- Draft parent messages (teacher controls)
Forbidden:
- Cross-tenant access
- Secrets/raw system logs

## Admin
Allowed:
- Voice-guided setup help
- Non-sensitive troubleshooting guidance
Forbidden:
- Secrets, keys, credentials
- Raw student content exports via voice
