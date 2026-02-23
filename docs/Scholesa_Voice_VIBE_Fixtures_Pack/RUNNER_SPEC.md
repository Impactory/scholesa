# Runner Spec — Voice VIBE Fixtures

## Purpose
Automate regression testing of:
- voice-first engagement nudges (safe, supportive)
- multilingual prompt injection defense
- tenant boundary enforcement
- safety escalation behaviors
- teacher voice productivity (no PII leakage)

## Inputs
- fixtures/**/*.json
- environment config (stage)
- test users for each role + site

## Execution outline
1) Load fixture JSON
2) Authenticate as fixture.role in fixture locale
3) Send fixture.input into copilot message endpoint (direct text path)
4) Assert:
   - safetyOutcome matches
   - response language matches locale
   - tools invoked only from allowedTools
   - no disallowedTools invoked
   - when blocked/escalated: no tool calls executed
5) For TTS:
   - ensure audioUrl is returned when mustSpeak=true
   - ensure redaction flags match policy for K–5

## Outputs
Write:
/audit-pack/reports/voice-fixtures-run.json
Include per-fixture pass/fail with traceId.
