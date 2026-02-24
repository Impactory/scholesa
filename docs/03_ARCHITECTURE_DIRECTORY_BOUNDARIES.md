# 03_ARCHITECTURE_DIRECTORY_BOUNDARIES.md

## Architecture overview
- Flutter app (web-first, PWA)
- Firebase Auth for identity
- Firestore + Storage for data & artifacts
- Dart API on Cloud Run for privileged operations
- Offline-first store (Isar) + sync queue

---

## Why these boundaries exist
A classroom product becomes unstable when:
- the client can grant itself access (“paid”, “admin”, “approved”)
- business rules live only in UI
- offline mode is bolted on later

Therefore:
- Firestore rules are the guardrails
- API is the authority for sensitive operations
- UI stays fast and consistent (and does not redesign the product)

---

## Design language continuity (enforced)
All feature work must preserve the current design language:
- Keep existing typography scale, spacing rhythm, tokens, and component styling.
- Reuse existing components before adding new ones.
- Any new component must be added to `design_system/` with full states and responsive rules.
- No global restyling, no new theme approach, no token renaming.

---

## Responsibilities

### Flutter app (client)
Must:
- be fast in class
- work offline for critical flows
- never grant itself privileges
- emit telemetry events safely

Must NOT write:
- EntitlementGrant / Subscription / Invoice
- GuardianLink (admin-only)
- computed intelligence collections (prefer API)

### Dart API (Cloud Run)
Must:
- verify Firebase ID tokens
- enforce role + site scope
- write audit logs for privileged actions
- process Stripe webhooks + grant entitlements
- compute signals/insights (rules-based first)
- offer idempotent batch endpoints for classroom reliability

### Firestore rules
Must:
- deny by default
- enforce site scope + role boundaries
- explicitly block parents from teacher intelligence collections
- block client writes to server-authoritative collections

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `03_ARCHITECTURE_DIRECTORY_BOUNDARIES.md`
<!-- TELEMETRY_WIRING:END -->
