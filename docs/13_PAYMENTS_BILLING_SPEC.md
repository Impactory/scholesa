# 13_PAYMENTS_BILLING_SPEC.md

Billing is server-authoritative. The client cannot “unlock” paid features.

## Provider
Stripe

## Core rule
Only API writes:
- Subscription
- Invoice
- EntitlementGrant

## Subscription flow
1) UI → API: create checkout session
2) Stripe completes payment
3) Stripe webhook → API
4) API verifies signature + idempotency
5) API writes subscription + entitlements
6) UI reads entitlements to gate features

## Marketplace payments
- Orders created by API
- Fulfillment created only after webhook confirms paid

## QA
- client write to EntitlementGrant denied
- webhook replay does not duplicate entitlements

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `13_PAYMENTS_BILLING_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
