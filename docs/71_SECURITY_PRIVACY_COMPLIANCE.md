# 71_SECURITY_PRIVACY_COMPLIANCE.md
Security, Privacy, and Compliance Requirements (Production)

Generated: 2026-01-09

**Design language lock (non-negotiable):**
- Keep the existing Scholesa visual language and component patterns.
- Do not redesign themes, typography systems, spacing scales, icon families, or card layouts.
- New screens must look like they belong to the current app (same Card/ListTile patterns, paddings, empty states).


## Purpose
Ensure the platform is safe for schools: least privilege, privacy boundaries, auditability, operational controls.

---

## 1) Identity and access control
- Role is server-authoritative (never client-trusted).
- Active site context server-authoritative.
- Admin-only provisioning enforced in rules + API.

Break-glass:
- HQ-only emergency admin path (documented, audited).

---

## 2) Parent-safe boundary (critical)
Parents can only see:
- their linked learners
- parent-safe summaries and artifacts allowed by consent

Parents must never see:
- educator internal notes
- AI “supports needed” flags intended for teachers
- other learners’ data

Enforce:
- explicit parent-safe projection endpoints
- do not expose raw educator collections to parent clients

---

## 3) Consent gating
- Consent flags govern portfolio visibility, media sharing, marketing usage.
- Consent changes only by admin; always audited.

---

## 4) Data minimization and privacy
- Telemetry must not include PII.
- Logs must not include tokens or student details.
- Store only necessary attributes.

---

## 5) Secrets and tokens
- Secrets in Secret Manager only.
- Refresh tokens never stored in Firestore.
- No secrets in client builds.

---

## 6) Web security
- CORS locked down to allowed origins.
- Protect OAuth redirects; validate state/nonce.
- Use secure cookies only if you introduce server sessions (otherwise rely on Firebase tokens).

---

## 7) Rate limiting and abuse controls
- rate limit auth-sensitive endpoints
- protect webhook endpoints
- account lockouts handled via Firebase and server rules where possible

---

## 8) Audit logs
- Privileged actions generate AuditLog with complete context.
- Audit views are read-only and scoped.

---

## 9) Go-live security gates
Must pass:
- rules emulator tests
- authZ tests (wrong role/site denial)
- parent boundary tests
- webhook verification tests (Stripe/GitHub/Classroom)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `71_SECURITY_PRIVACY_COMPLIANCE.md`
<!-- TELEMETRY_WIRING:END -->
