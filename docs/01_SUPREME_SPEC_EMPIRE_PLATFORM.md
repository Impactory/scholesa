# 01_SUPREME_SPEC_EMPIRE_PLATFORM.md

## What we are building
Scholesa’s Empire platform is a **school operating system** for Education 2.0:
- Learners build **habits** aligned to pillars.
- Educators run class operations with minimal friction and high clarity.
- Parents reinforce at home with simple, safe actions.
- Partners contribute programs and mission packs with governed workflows.
- HQ ensures quality, approvals, and analytics.

This is designed for **in-person physical classes** first.

---

## The 3 pillars (non-negotiable)
Every meaningful learning activity and evidence should map to one or more pillars:
1) **FUTURE_SKILLS**
2) **LEADERSHIP_AGENCY**
3) **IMPACT_INNOVATION**

---

## The Accountability Cycle (the engine)
**Plan → Do → Evidence → Reflect → Review → Improve**

This cycle must be supported end-to-end for:
- learners (commitments + attempts + evidence + reflection)
- educators (mission plans + review queue + interventions)
- parents (acknowledge + reinforce)
- admin/HQ/partners (governance + measurement)

---

## Stakeholder outcomes

### Learners (in-person)
- Enter class with clarity (mission plan + commitment)
- Capture evidence before leaving (photo/file/link)
- Reflect quickly (structured prompts)
- Receive review and choose next improvement step
- Experience growth as consistency and capability, not grades

### Educators (in-person)
- Open session occurrence fast
- Take attendance quickly
- Push mission plan and evidence expectations
- Review attempts in a manageable queue
- See “who needs support today” with explainable reasons
- Log support interventions and outcomes quickly

### Parents (home reinforcement)
- View weekly summary for linked learners (read-only linkage)
- Acknowledge + choose 1 support action
- Message educators within safe relationship constraints
- Never gain operational powers (no provisioning, no linking)

### Site Admin (school operations)
- Provision users and guardian links (admin-only)
- Maintain rosters/enrollments/schedules
- Ensure intake completeness (including admin-only “Kyle & Parrot” questions)
- Maintain audit readiness

### Partners
- Publish offerings with review/approval
- Track deliverables and payouts
- Operate within governance gates

### HQ
- Approve listings/contracts/payouts
- Tune popups and support strategies
- Monitor accountability adherence across sites
- Run audits and enforce policy

---

## Design language continuity (explicit)
The platform must maintain the **current design language**:
- Extend the existing design system rather than replacing it.
- New features must inherit navigation patterns, typography and spacing.
- A “new screen” is not permission to change styling system-wide.

---

## Non-functional requirements
- **Security:** deny-by-default rules, strict role/site scope, audit logs
- **Reliability:** deterministic IDs where needed, idempotent writes, safe retries
- **Offline-first:** attendance + attempts + interventions must function offline
- **Stability:** pinned versions, reproducible builds
- **Observability:** structured logs, telemetry events, error reporting

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `01_SUPREME_SPEC_EMPIRE_PLATFORM.md`
<!-- TELEMETRY_WIRING:END -->
