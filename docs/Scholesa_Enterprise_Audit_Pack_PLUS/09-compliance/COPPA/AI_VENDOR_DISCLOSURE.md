# AI Vendor Disclosure (Template)

Scholesa may use third-party AI services to provide instructional support.

## Data shared with AI services
- Only the minimum context required to deliver the educational feature.
- Student direct identifiers are avoided where possible.
- Sensitive information is redacted or excluded by policy.

## Prohibited data
- Credentials, secrets, payment info
- Cross-tenant information
- Unnecessary PII

## Retention & training
Document for each AI vendor:
- Whether prompts/responses are retained, and for how long
- Whether data is used for model training
- How deletion requests are handled

Reference:
- 10-vendors/VENDOR_REGISTER.md
- 04-privacy/AI_DATA_MINIMIZATION.md

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/09-compliance/COPPA/AI_VENDOR_DISCLOSURE.md`
<!-- TELEMETRY_WIRING:END -->
