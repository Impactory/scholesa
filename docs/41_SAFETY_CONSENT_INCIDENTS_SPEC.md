# 41_SAFETY_CONSENT_INCIDENTS_SPEC.md
Safety, consent, and incident workflows (Physical school must-have)

This spec adds the minimum operational safety layer for in-person schools, without storing sensitive medical diagnoses.

**Design language lock:** UI must use existing design system and patterns. No reskin.

---

## 1) Media + artifact consent
Schools must control whether learner media can be:
- captured at all
- stored in Scholesa
- shared with parents
- used in marketing

### Required fields (per learner, admin-managed)
- photoCaptureAllowed: boolean
- shareWithLinkedParents: boolean
- marketingUseAllowed: boolean
- consentStartDate / consentEndDate
- consentDocumentUrl (optional)

Rules:
- if photoCaptureAllowed = false, evidence uploads must prevent media capture for that learner and offer alternate evidence types (text, teacher note).
- marketingUseAllowed must default to false until explicitly granted.

---

## 2) Pickup authorization + emergency contacts
Schools need:
- emergency contacts (already in LearnerProfile)
- pickup authorization list (who can pick up)

### Required behaviors
- admin adds authorizedPickup list with:
  - full name
  - relationship
  - phone
  - ID check notes (optional)
- educator can view pickup list for their session learners
- parent can request change, but admin approves

---

## 3) Incident reporting
Incidents may include:
- injury
- behavioral conflict
- bullying concerns
- safety issue (facility)
- repeated late pickup

### Workflow
- educator creates incident report (draft → submitted)
- site admin reviews (reviewed → closed)
- HQ visibility: optional for severe categories

### Severity
- minor / major / critical

### Notifications
- major/critical triggers immediate admin notification
- parent notification is policy-driven (never automatic for all incidents)

---

## 4) Messaging safety basics (minimum viable moderation)
Even with role boundaries, schools want:
- report a message
- block a user (admin-only)
- content flags (profanity/harassment heuristics)

Implementation approach:
- client-side “report” button creates a moderation ticket
- API can run lightweight checks to flag message metadata (do not store message content in telemetry)

---

## 5) Audit requirements
AuditLog entries for:
- consent changes
- pickup list changes
- incident created/submitted/reviewed/closed
- blocks/restrictions applied

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `41_SAFETY_CONSENT_INCIDENTS_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
