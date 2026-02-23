# Canada / BC Privacy Operational Alignment Add-on

Date: 2026-02-23

This add-on provides a practical operational and technical alignment framework for Canadian/BC deployments.
This is not legal advice.

## 1) Data residency and cross-border processing
- Document where data is stored/processed (regions used by Firebase/Cloud Run/Firestore).
- If any data is stored or processed outside Canada, document:
  - contractual safeguards
  - access controls
  - encryption and key management
  - incident notification plan

## 2) School authority and purpose limitation
- Data collected and processed strictly for educational purposes authorized by the school/district.
- No secondary marketing use, no behavioral advertising.

## 3) Access controls and audit logs
- Least privilege IAM for staff and service accounts
- Tenant isolation controls prevent cross-school access
- Audit-ready logs with traceId + siteId (redacted where needed)

## 4) Retention and deletion
- Default retention schedule + tenant overrides
- Verified deletion workflows for learner records and artifacts
- Backup retention stated and documented

## 5) Vendor transparency
- Maintain vendor register and data-sharing descriptions
- Provide AI vendor disclosure to districts
- Track subprocessors

## 6) Incident response and notifications
- Incident response plan includes district communication procedures
- Evidence preservation steps for investigations

## Evidence pointers
- 04-privacy/DATA_CLASSIFICATION.md
- 04-privacy/RETENTION_DELETION.md
- 08-operations/INCIDENT_RESPONSE_PLAN.md
- 10-vendors/VENDOR_REGISTER.md
