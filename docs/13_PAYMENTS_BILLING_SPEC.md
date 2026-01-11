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
