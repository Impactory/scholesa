# 30_GOOGLE_CLASSROOM_OAUTH_SECURITY.md
OAuth + token security for Scholesa ↔ Classroom

OAuth and tokens must be handled by the **Dart API on Cloud Run**.
Do not implement “client-only” OAuth.

---

## 1) OAuth architecture

### Components
- Flutter client: starts connect, receives success/fail
- Cloud Run API:
  - initiates OAuth
  - receives callback
  - exchanges code for tokens
  - stores token material securely
- Secure storage:
  - preferred: Secret Manager + KMS envelope encryption
  - fallback: encrypted token blobs in a dedicated store (still encrypted)

### Redirect pattern
- user clicks connect → API returns auth URL
- browser navigates to Google consent
- Google redirects to API callback
- API stores tokens, returns success page that redirects back to the app

---

## 2) Scope strategy (least privilege)
Define 2 scope bundles:

### Bundle A — Phase 1
- list courses
- list rosters
- create coursework (publish links)

### Bundle B — Phase 2 (additional)
- read student submissions state
- set grades / return state and/or post private comments (as policy allows)

Only request Bundle B when the teacher enables “grade sync”.

---

## 3) Token handling rules
- store refresh tokens securely
- rotate/refresh access tokens server-side
- never log tokens
- do not send refresh tokens to clients
- store token metadata in Firestore only (tokenRef, scopesGranted, status)

---

## 4) Revocation + error handling
- “Disconnect Classroom”:
  - mark IntegrationConnection.status=revoked
  - delete/disable secrets
- on 401/invalid_grant:
  - set status=error
  - prompt user to reconnect

---

## 5) Audit logs (required)
Write AuditLog entries for:
- connect success/fail
- course link/unlink
- roster sync runs
- publish coursework
- grade sync actions

---

## 6) Admin/domain considerations (for districts)
If deploying at scale:
- publish the app to Workspace Marketplace as appropriate
- domain admin may need to whitelist/enable add-ons/integration features

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `30_GOOGLE_CLASSROOM_OAUTH_SECURITY.md`
<!-- TELEMETRY_WIRING:END -->
