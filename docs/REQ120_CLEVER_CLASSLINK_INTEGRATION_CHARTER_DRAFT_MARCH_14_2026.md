# REQ-120 Draft Integration Charter: Clever and ClassLink

Date: 2026-03-14
Status: Draft for approval

## Purpose

This draft defines the minimum approved scope needed to begin real REQ-120 implementation without overcommitting to both district providers at once.

Recommendation:
- Fund one provider first.
- Default recommendation: approve Clever first for roster and SSO parity, then evaluate ClassLink after the first district pilot.

This recommendation keeps rollout disciplined because the repo already supports:
- CSV SIS import
- Google Classroom integration
- LTI 1.3 and grade passback
- Enterprise SSO via SAML and OIDC

What is missing is a district-grade provider charter, not just code.

## 1) Proposed approval decision

Approve one of the following:

1. Clever Phase 1 only
2. ClassLink Phase 1 only
3. Clever first, ClassLink second after pilot review
4. Hold REQ-120

Recommended draft decision:
- Approve Clever first, then evaluate ClassLink after pilot completion.

## 2) Stakeholder experience

### Site admin
1. Connect district provider from site or HQ integrations.
2. Review district or school mapping.
3. Preview roster changes before apply.
4. Run sync manually or enable scheduled sync.
5. View unmatched users, paused users, and error state.

### Educator
- See roster provenance and last sync status.
- Request remediation for unmatched learners.
- Keep Scholesa as the operational source of truth for attendance, missions, and evidence.

### Learner
- Sign in through the approved district identity path when enabled.
- Appear in the correct site roster without manual CSV fallback once matched.

### HQ
- Approve provider enablement.
- See integration health, failure counts, last successful sync, and audit logs.

## 3) Approved scope proposal

### Phase 1: roster + identity only

Approved flows:
- district or school connection setup
- school or section discovery
- roster import and reconciliation into site-scoped Scholesa users and enrolments
- identity link creation for approved provider user identifiers
- optional SSO bootstrap where provider and district contract permit it
- admin review queue for unmatched or ambiguous records

Explicitly out of scope for Phase 1:
- grade passback
- assignment publish
- teacher content distribution
- parent account auto-linking
- automatic destructive deletes of learners or educators

### Phase 2: optional provisioning hardening

Only after pilot review:
- scheduled sync jobs
- section-to-session mapping improvements
- district-wide provisioning automation
- provider-driven deprovision signals with reversible hold states

## 4) Provider comparison

### Clever

Best fit for first approval if the target districts already use Clever rostering and identity.

Draft approved scope:
- roster sync
- school and section discovery
- user identity linking
- optional district login handoff if approved by security and product

### ClassLink

Keep as second-wave integration unless a committed district requires it first.

Draft approved scope:
- OneRoster-style roster ingestion or equivalent provider contract
- school and class mapping
- identity link creation
- optional launch or SSO parity after pilot proof

## 5) Data contract requirements

Required canonical entities:
- IntegrationConnection
- ExternalIdentityLink
- ExternalRosterSyncJob
- ExternalRosterMatchReview

Required minimum fields:
- provider
- siteId
- districtId or tenantId where applicable
- externalSchoolId
- externalSectionId
- externalUserId
- scholesaUserId when matched
- sync status
- error code
- lastSyncedAt
- traceId

Non-negotiables:
- site-scoped writes only
- no automatic parent linking
- no destructive delete on first implementation
- audit log for every privileged connect, sync, resolve, and disconnect action

## 6) Security and compliance constraints

- Provider auth and tokens must be server-managed only.
- No provider secrets in client code.
- No cross-site roster joins.
- No raw PII in telemetry events.
- Student identifiers from providers must be retained only as needed for sync and reconciliation.
- District disable and rollback path must exist before broad rollout.

## 7) Internal API shape to approve

Draft internal endpoints or callables:
- `POST /api/integrations/{provider}/auth-url`
- `GET /api/integrations/{provider}/callback`
- `POST /api/integrations/{provider}/schools/{schoolId}/sync-roster`
- `POST /api/integrations/{provider}/sections/{sectionId}/sync-roster`
- `POST /api/integrations/{provider}/identity-links/{id}:resolve`
- `POST /api/integrations/{provider}/disconnect`

Required audit actions:
- `{provider}.connect`
- `{provider}.roster.sync`
- `{provider}.identity.resolve`
- `{provider}.disconnect`

Required telemetry:
- `integration.sync.started`
- `integration.sync.completed`
- `external_identity_link.resolved`
- `external_identity_link.blocked`

## 8) Pilot gate

Pilot must be limited to:
- 1 district or network
- up to 2 sites
- manual review required for unmatched roster records

Pilot exit criteria:
- sync success rate and error taxonomy documented
- no cross-tenant data leakage
- rollback tested
- admin review queue usable without engineer intervention
- traceability row can name code, tests, and proof docs

## 9) Approval block

- Selected provider:
- Selected phase:
- Product approval:
- Compliance approval:
- Security approval:
- Release approval:
- Target pilot district:
- Reference ticket:
- Decision date:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ120_CLEVER_CLASSLINK_INTEGRATION_CHARTER_DRAFT_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->