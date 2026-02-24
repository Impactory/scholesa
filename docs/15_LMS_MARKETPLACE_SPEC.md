# 15_LMS_MARKETPLACE_SPEC.md

Marketplace publishes mission packs/courses/programs/services with governance.

## Objects
- PartnerOrg
- MarketplaceListing
- Order
- Fulfillment

## Lifecycle
draft → submitted → approved/rejected → published → archived

Approvals are HQ-only.

## Purchases
- API creates checkout/payment intent
- webhook confirms paid
- API writes Fulfillment
- access is derived from Fulfillment + Entitlements

## QA
- publish without approval blocked
- fulfill without paid blocked

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `15_LMS_MARKETPLACE_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
