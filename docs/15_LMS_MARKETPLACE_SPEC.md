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
