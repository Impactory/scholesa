# School Consent Model (COPPA School-as-Agent)

Date: 2026-02-23

Scholesa relies on the school/district to obtain and document verifiable parental consent for educational use.

## Preconditions
- Signed school/district agreement.
- Educational-use-only confirmation.
- Parent notice provided by school/district.
- No direct student marketing and no behavioral advertising.

## Required System Record
Each site must have `coppaSchoolConsents/{siteId}` with:
- `agreementSigned: true`
- `educationalUseOnly: true`
- `parentNoticeProvided: true`
- `noStudentMarketing: true`
- `active: true`

## Operational API
- Upsert/maintain: `upsertSchoolConsentRecord` (role: `site` or `hq`)
- Read/check: `getSchoolConsentRecord` (role: `educator`, `site`, `hq`)

## Runtime Enforcement
- `genAiCoach` checks active school consent before serving learner AI responses.
- If record is missing or inactive, request fails with `failed-precondition`.

## School Responsibilities
- Notify parents of Scholesa usage and purpose.
- Retain local consent documentation per district policy.
- Route parent access/deletion requests through official school channel.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_COPPA_Operational_Pack/03_SCHOOL_CONSENT_MODEL.md`
<!-- TELEMETRY_WIRING:END -->
