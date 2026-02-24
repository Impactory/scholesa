# Voice-First Product Principles (Student Engagement + Focus)

## Goal
Increase engagement and focus by making the primary interaction mode VOICE (input + output) for students, without creating manipulation risk.

## Principles
1) Voice-first, not voice-only by force:
   - Students can still use typing for accessibility, privacy, or noise constraints.
   - The system nudges voice when appropriate, but never blocks learning.

2) Short, structured, supportive prompts:
   - Use brief spoken prompts to keep students on task.
   - Avoid emotional dependency, flattery loops, or coercive language.

3) Focus scaffolds:
   - "Next step" prompts
   - timed check-ins ("Ready for the next question?")
   - reflection cues ("Say your reasoning out loud.")

4) Teacher override:
   - Teachers can disable voice nudges per class/session.
   - Teachers can set quiet mode windows.

5) COPPA-safe engagement:
   - No persuasive prosody for under-13 beyond clarity emphasis.
   - No individualized emotional profiling.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/00-executive/VOICE_FIRST_PRODUCT_PRINCIPLES.md`
<!-- TELEMETRY_WIRING:END -->
