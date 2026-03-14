# REQ-120 Draft Internal API Contract: Clever

Date: 2026-03-14
Status: Draft for approval

This contract narrows REQ-120 to a single provider-first execution path.

Scope assumed by this draft:
- Clever Phase 1 only
- roster sync
- school and section discovery
- external identity linking and review
- optional SSO bootstrap only if separately approved

All endpoints below are Scholesa-owned APIs or callable boundaries, not Clever APIs.

## Principles

- Firebase Auth JWT required for all interactive admin operations.
- HQ or site admin role required.
- Site scoping enforced server-side.
- AuditLog required for connect, sync, resolve, disconnect, and destructive review actions.
- No Clever tokens or secrets in client code.
- No automatic parent linking.
- No destructive user deletes in Phase 1.

## 1) OAuth or district connect bootstrap

### `POST /api/integrations/clever/auth-url`

Body:
```json
{ "returnUrl": "https://app.scholesa.com/en/site/identity", "siteId": "site-123" }
```

Returns:
```json
{ "url": "https://clever.example/auth?...", "correlationId": "trace_123" }
```

Does:
- validates actor role and site access
- creates a signed state payload
- records pending connect intent

Audit action:
- `clever.connect.started`

### `GET /api/integrations/clever/callback`

Query:
- `code`
- `state`

Does:
- validates state and nonce
- exchanges authorization code server-side
- stores token material in secure server-managed storage
- creates or updates `integrationConnections/{id}`
- redirects back to requested Scholesa return URL

Audit actions:
- `clever.connect.succeeded`
- `clever.connect.failed`

## 2) School and section discovery

### `GET /api/integrations/clever/schools`

Query:
- `siteId`

Returns:
```json
{
  "schools": [
    { "id": "school_1", "name": "Scholesa Pilot School", "districtId": "district_1" }
  ],
  "correlationId": "trace_123"
}
```

Does:
- resolves the active Clever connection for the allowed site
- returns normalized school metadata for admin mapping

### `GET /api/integrations/clever/schools/{schoolId}/sections`

Query:
- `siteId`

Returns normalized section metadata for preview and mapping.

Audit action:
- `clever.discovery.viewed`

## 3) Roster sync

### `POST /api/integrations/clever/schools/{schoolId}/sync-roster`

Body:
```json
{
  "siteId": "site-123",
  "defaultSessionId": "session-456",
  "mode": "preview"
}
```

Allowed `mode` values:
- `preview`
- `apply`

Returns:
```json
{
  "added": 12,
  "updated": 20,
  "paused": 2,
  "unmatched": 3,
  "reviewQueueId": "clever_review_123",
  "correlationId": "trace_123"
}
```

Does:
- fetches approved school roster and sections
- maps records into Scholesa learners and educators by safe matching rules
- creates or updates enrolments only within authorized site scope
- writes unmatched or ambiguous records into review queue collections
- never auto-creates guardian links

Audit action:
- `clever.roster.sync`

Telemetry:
- `integration.sync.started`
- `integration.sync.completed`

### `POST /api/integrations/clever/sections/{sectionId}/sync-roster`

Same semantics as school sync, but narrowed to one section for controlled pilots.

## 4) Identity review and resolution

### `GET /api/integrations/clever/identity-links`

Query:
- `siteId`
- `status=pending|resolved|ignored`

Returns pending external-user matches and suggested Scholesa users.

### `POST /api/integrations/clever/identity-links/{id}:resolve`

Body:
```json
{
  "siteId": "site-123",
  "scholesaUserId": "user_789",
  "decision": "link"
}
```

Allowed `decision` values:
- `link`
- `ignore`
- `hold`

Does:
- records approved mapping change
- updates `externalIdentityLinks`
- preserves previous mapping in audit details

Audit action:
- `clever.identity.resolve`

Telemetry:
- `external_identity_link.resolved`
- `external_identity_link.blocked`

## 5) Disconnect

### `POST /api/integrations/clever/disconnect`

Body:
```json
{ "siteId": "site-123", "connectionId": "clever_conn_123" }
```

Does:
- marks integration connection as revoked
- disables or deletes server-managed token references
- preserves audit history

Audit action:
- `clever.disconnect`

## 6) Error contract

Every failure returns:

```json
{
  "code": "permission-denied",
  "message": "Site or HQ role required.",
  "correlationId": "trace_123",
  "details": {}
}
```

Required codes:
- `unauthenticated`
- `permission-denied`
- `invalid-argument`
- `failed-precondition`
- `provider-unavailable`
- `conflict`
- `not-found`

## 7) Security constraints

- Token exchange and refresh are server-only.
- Refresh tokens must not be stored in Firestore.
- State and nonce are mandatory for connect flow.
- Per-site authorization checked before every discovery, sync, resolve, and disconnect action.
- Provider outage must fail closed and preserve prior local data.

## 8) Pilot-only acceptance gates

- 1 district max
- 2 sites max
- preview mode exercised before any apply mode
- unmatched users require admin resolution
- rollback path verified
- traceability update can name concrete code, tests, and proof docs

## 9) Approval block

- Product approval:
- Compliance approval:
- Security approval:
- Release approval:
- Pilot district:
- Pilot sites:
- Decision date:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ120_CLEVER_INTERNAL_API_CONTRACT_DRAFT_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->