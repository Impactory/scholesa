# Grade-Band Feature Policy (Enforcement)

Date: 2026-02-23

All enforcement is driven by Firebase auth context (`gradeBand` custom claim, with payload consistency checks).

## K–5 (`K_5`)
- Allowed AI modes: `hint`, `verify`
- Block open-ended free chat patterns
- Enhanced input limits (shorter text, link blocking)
- Restricted attachment types:
  - `text/plain`
  - `application/pdf`
  - `image/png`
  - `image/jpeg`
- Attachment count and size limits tightened

## 6–8 (`G6_8`)
- Allowed AI modes: `hint`, `verify`, `explain`
- Guided interactions with checkpoint linkage prompts
- Moderate attachment limits

## 9–12 (`G9_12`)
- Allowed AI modes: `hint`, `verify`, `explain`, `debug`
- Expanded tutoring support
- Explain-back required

## Runtime Controls
- Claim/payload consistency check rejects mismatched grade band inputs.
- Consent gate enforced before AI access.
- Enforcement points in `functions/src/index.ts` (`genAiCoach`):
  - `resolveGradeBandFromClaims`
  - `validateCoppaMode`
  - `validateCoppaAttachments`
  - `validateCoppaInputText`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_COPPA_Operational_Pack/05_GRADE_BAND_FEATURE_POLICY.md`
<!-- TELEMETRY_WIRING:END -->
