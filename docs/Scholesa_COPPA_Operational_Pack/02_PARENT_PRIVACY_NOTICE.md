# Scholesa Parent Privacy Notice (School Distribution Template)

Date: 2026-02-23

Scholesa provides educational services on behalf of schools/districts.
This template is for school distribution to parents/guardians.

## Information We Collect (Educational Use Only)
- Student identifiers provided by school (name, grade/class, school email if used).
- Learning progress/work artifacts (missions, checkpoints, reflections, portfolios).
- Operational/security logs (authentication, service health, audit events).
- AI interaction logs for instructional support and safety review.

## Why We Use It
- Deliver instruction and feedback.
- Support teacher oversight and learner progress reporting.
- Maintain platform security, reliability, and abuse prevention.

## What We Do Not Do
- No behavioral advertising.
- No sale of student data.
- No cross-service marketing tracking.

## Data Sharing
- Data is shared with vetted processors only to operate the education service.
- AI provider usage follows the constraints in `04_AI_VENDOR_DISCLOSURE.md`.
- Sensitive identifiers are minimized/redacted where feasible.

## Parent/Guardian Rights
Parents may request, through the school/district:
- Access to student records.
- Correction of inaccurate records.
- Deletion of student data (subject to school/legal requirements).

Operational workflow reference: `06_PARENT_REQUEST_WORKFLOW.md`.

## Contact
- Privacy: privacy@scholesa.org
- School-admin request channel: district submits to Scholesa support with `siteId + learnerId + requestType`.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_COPPA_Operational_Pack/02_PARENT_PRIVACY_NOTICE.md`
<!-- TELEMETRY_WIRING:END -->
