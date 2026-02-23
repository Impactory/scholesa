# Scholesa COPPA Master Alignment

Date: 2026-02-23
Owner: Privacy + Platform Engineering

This file is the COPPA control index for Scholesa’s school-agent model.

## Scope
- Educational deployments where school/district acts as parent agent.
- Under-13 protections enforced through grade-band policy controls.
- No behavioral advertising and no student data sale.

## Control-to-Implementation Mapping

| COPPA Control Area | Scholesa Control | Implementation Surface | Evidence |
|---|---|---|---|
| School consent / school-as-agent | Site consent record required before learner AI use | `upsertSchoolConsentRecord`, `getSchoolConsentRecord`, `genAiCoach` school-consent gate | `coppaSchoolConsents/{siteId}`, `coppaTraceLogs` |
| Parent notice | Parent notice template and district delivery model | `02_PARENT_PRIVACY_NOTICE.md` | District onboarding artifacts |
| Parent rights (access/delete) | Request submission + processing workflow with trace IDs | `submitParentDataRequest`, `processParentDataRequest` | `coppaParentRequests`, `coppaParentRequestReports`, `coppaTraceLogs` |
| Data minimization | Claim-based grade-band enforcement + input/attachment constraints | `genAiCoach` policy gates | `interactionEvents` payload (`coppaBand`, `gradeBandSource`) |
| Vendor transparency | AI data boundary + prohibited data list | `04_AI_VENDOR_DISCLOSURE.md`, redaction in `src/lib/ai/redactionService.ts` | Vendor register + DPA records |
| Retention/deletion | Default schedule + site override + scheduled sweeps | `upsertCoppaRetentionOverride`, `runCoppaRetentionSweep`, `scheduledCoppaRetentionSweep` | `coppaRetentionRuns`, trace logs |
| No advertising/profiling | Policy + repo-level audit gate | `scripts/coppa_no_ad_audit.sh` + `npm run audit:coppa:no-ads` | CI logs + policy docs |

## Operational Cadence
- Daily: `scheduledCoppaRetentionSweep` executes retention cleanup.
- On demand: site/hq executes `processParentDataRequest` for verified parent requests.
- Release gate: run `npm run audit:coppa:no-ads` before cutover.
- Quarterly: review school consent records and retention overrides.

## Linked Pack Files
- `02_PARENT_PRIVACY_NOTICE.md`
- `03_SCHOOL_CONSENT_MODEL.md`
- `04_AI_VENDOR_DISCLOSURE.md`
- `05_GRADE_BAND_FEATURE_POLICY.md`
- `06_PARENT_REQUEST_WORKFLOW.md`
- `07_DATA_RETENTION_SCHEDULE.md`
- `08_NO_ADVERTISING_POLICY.md`
