# District Sales Compliance Summary (Executive, 2 pages)

Date: 2026-02-23

## What Scholesa is
Scholesa is a multi-tenant K–12 learning platform (Firebase + Cloud Run) with AI coaching that is governed by safety policies, grade-band controls, and proof-of-learning workflows.

## What we protect
- Student personal information (PII) and education records
- Cross-school/district data separation (tenant isolation)
- AI interaction boundaries (minimization + redaction + policy enforcement)

## Procurement-ready controls (high-level)
### 1) Tenant Isolation (No cross-school access)
- siteId is enforced in auth claims, API middleware, Firestore rules, logs, and exports.
- Cross-tenant access is tested in regression (“deny by default”).

### 2) Access control & auditability
- Role-based access (student/teacher/admin)
- Admin protections (MFA recommended/required for privileged roles)
- Centralized logging with traceId correlation for investigations

### 3) Privacy operations: export & deletion
- Export and deletion workflows are documented and testable.
- Deletions are scoped to siteId + learnerId and verified post-run.

### 4) AI governance & student safety
- AI prompts/templates are versioned.
- Guardrails block prompt injection, unsafe content, and data exfiltration attempts.
- Grade-band feature gating (K–5 restricted, 6–8 guided, 9–12 expanded but bounded).
- Proof-of-learning: checkpoints, explain-back, reflection, portfolio artifacts bound to missionAttemptId.

### 5) Security posture (SOC2-style readiness)
- Secrets in Google Secret Manager
- Supply chain scanning + SBOM (recommended gate in CI)
- Change management: staged deploy, rollback, and release gating

## COPPA posture (under-13)
Scholesa supports COPPA operational requirements via the **School Consent model**:
- Educational use only
- No behavioral advertising, no sale of student data
- Parent requests handled through the school with export/delete workflows
- Parent notice template provided for school distribution

## What we provide to districts
- Audit Pack: architecture + controls + runbooks + evidence placeholders
- Control matrix mapping controls to evidence files
- Operational runbooks for export/delete and incident response
- Vendor register and AI vendor disclosure template

## What districts should confirm during onboarding
- School/district consent workflow (COPPA school-agent model)
- Data retention schedule (default periods, optional district overrides)
- Regional/data residency preferences (documented if US-hosted)
- Roster + identity integration choices

## Contact
Security/Privacy: security@scholesa.org | privacy@scholesa.org

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_Enterprise_Audit_Pack_PLUS/00-executive/DISTRICT_COMPLIANCE_SUMMARY.md`
<!-- TELEMETRY_WIRING:END -->
