# Grade-Band Feature Policy (Enforcement Spec)

## K–5 (Under-13 emphasis)
- No open-ended free chat by default (guided interactions only)
- Stronger moderation thresholds
- Limited external link generation
- Limited uploads (type and size)
- Teacher-visible logs by default

## 6–8
- Guided tutoring with checkpoints
- More autonomy but bounded tool use
- Reflection required for mission completion

## 9–12
- Expanded coaching support
- Explain-back and citation/verification prompts
- Portfolio artifact + rubric alignment

## Enforcement mechanism
- Firebase custom claims: gradeBand, role, siteId
- API middleware + AI policy engine enforce feature gating

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/09-compliance/COPPA/GRADE_BAND_FEATURE_POLICY.md`
<!-- TELEMETRY_WIRING:END -->
