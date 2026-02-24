# Scholesa Voice VIBE Fixtures Pack (COPPA-safe)
Generated: 2026-02-23T04:48:30Z

This pack contains:
- Multilingual voice prompt fixtures (en, zh-CN, zh-TW, th)
- Off-task focus nudges (non-manipulative, supportive)
- Voice prompt-injection attempts (safe testing)
- Data exfiltration attempts (tenant boundary)
- Safety escalation scenarios (high-level, non-graphic)
- Expected outcomes schema for automated testing

Use with the Voice system VIBE gates:
- voice:abuse-and-safety-refusals
- copilot:ai-guardrails:i18n
- voice:role-policy
- voice:tenant-isolation

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Voice_VIBE_Fixtures_Pack/README.md`
<!-- TELEMETRY_WIRING:END -->
