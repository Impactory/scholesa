# Parent Data Request Workflow (Access/Deletion)

Date: 2026-02-23

All parent requests are handled through school/district verification and then executed by Scholesa with traceable evidence.

## Step 1: School Verification
- Parent/guardian contacts school/district.
- School verifies identity and authority to act for learner.
- School records district ticket/reference ID.

## Step 2: Request Submission to Scholesa
- School submits request with:
  - `siteId`
  - `learnerId`
  - `requestType` (`export` or `delete`)
  - optional district ticket ID
- API: `submitParentDataRequest`
- Output includes `requestId` and `traceId`

## Step 3: Execute Request
- Scholesa site/hq operator runs `processParentDataRequest` with `requestId`.
- Execution is scoped to learner + site.
- Export result: structured collection summary report.
- Delete result: matched document deletion + user record detach/delete + storage prefix cleanup.

## Step 4: Completion Evidence
- Report location: `coppaParentRequestReports/{requestId}`
- Request lifecycle: `coppaParentRequests/{requestId}`
- Trace log stream: `coppaTraceLogs` (`traceId` correlated)

## Step 5: School Confirmation to Parent
- School receives completion evidence from Scholesa.
- School closes ticket with parent.

## Required Logging Fields
- `traceId`
- `requestId`
- `siteId`
- `learnerId`
- `requestType`
- `status`

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_COPPA_Operational_Pack/06_PARENT_REQUEST_WORKFLOW.md`
<!-- TELEMETRY_WIRING:END -->
