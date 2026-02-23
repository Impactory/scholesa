# VC Technical Risk Mitigation Brief (Executive, 2 pages)

Date: 2026-02-23

## Core thesis
Scholesa is positioned as TrustTech + EdTech: a governed AI learning system with enforceable tenant isolation, auditable learning integrity, and compliance-ready operational controls.

## Biggest risks in K–12 AI — and Scholesa mitigations
### 1) Cross-tenant data leakage (existential procurement risk)
Mitigations:
- siteId enforced via auth claims + Firestore rules + API middleware
- Cross-tenant denial tests as release gate
Evidence:
- SECURITY/TENANT_ISOLATION.md
- reports/tenant-isolation-test.json (to be generated)

### 2) AI prompt injection and data exfiltration
Mitigations:
- Policy-gated AI orchestration; tool registry scoped per siteId/role/gradeBand
- Guardrail regression suite blocks injection/exfil
Evidence:
- AI/GUARDRAILS_AND_SAFETY.md
- ai-guardrails-report.json (to be generated)

### 3) Learning integrity (product credibility + outcomes)
Mitigations:
- Proof-of-learning workflow: checkpoint + explain-back + reflection + portfolio artifact
- MissionAttempt binding prevents “AI does it all” usage
Evidence:
- LEARNING_INTEGRITY_PROOF.md
- 06-quality/GOLDEN_FLOWS.md

### 4) Compliance & reputational risk (COPPA/FERPA + Canada)
Mitigations:
- COPPA School Consent operational pack: parent notice, workflows, retention schedule, no-ads policy
- Practical alignment docs for FERPA/COPPA and BC/Canada privacy
Evidence:
- 09-compliance/COPPA/*
- 09-compliance/CANADA_BC_PRIVACY_OPERATIONAL_ADDON.md

### 5) Operational reliability (enterprise scaling)
Mitigations:
- Cloud Run baselines, SLOs, dashboards, alerting, IR/DR runbooks
- Release gates requiring safety + isolation tests on same SHA
Evidence:
- 02-infrastructure/CLOUD_RUN_BASELINE.md
- 07-observability/*
- 08-operations/RELEASE_GATE.md

## Why this is defensible
- Governance is productized (policies, tests, evidence pack)
- Multi-tenant isolation is built-in, not bolted on
- AI is orchestrated with audited metadata and bounded tool use

## Near-term roadmap (de-risking milestones)
- Automate audit-pack generation in CI with evidence exports
- Add tamper-evident log sink for AI safety outcomes (optional)
- Complete vendor DPAs and publish parent notice/versioning page
- Run quarterly red-team scripts and publish summarized results

## Investor takeaway
Scholesa reduces the highest failure modes of K–12 AI platforms (privacy, safety, integrity) while preserving iteration speed via serverless infrastructure.
