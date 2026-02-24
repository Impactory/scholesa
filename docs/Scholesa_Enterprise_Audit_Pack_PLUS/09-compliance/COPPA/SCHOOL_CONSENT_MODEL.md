# School Consent Model (COPPA Operational)

Scholesa is designed for school deployments where the school/district acts as the parent’s agent for consent under COPPA.

## Preconditions for using this model
- Scholesa is used solely for educational purposes authorized by the school/district.
- The school/district provides required notices to parents/guardians.
- The school/district maintains records of consent consistent with its policies and applicable law.
- Scholesa does not market directly to children and does not use student data for behavioral advertising.

## Operational controls
- Grade-band gating (K–5 safest defaults)
- Data minimization to AI providers
- Export/delete workflows administered via school channels

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/09-compliance/COPPA/SCHOOL_CONSENT_MODEL.md`
<!-- TELEMETRY_WIRING:END -->
