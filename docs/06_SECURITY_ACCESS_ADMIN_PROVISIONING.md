# 06_SECURITY_ACCESS_ADMIN_PROVISIONING.md

This is the security contract.

Security is enforced in THREE layers:
1) Firestore rules
2) API authorization
3) Audit logs

---

## Threats we must stop
- parent self-linking learners
- parent reading teacher-only intelligence collections
- cross-site data leakage
- client writing “paid” state or entitlements
- bypassing approvals (listings/contracts/payouts)

---

## Hard rules (non-negotiable)
1) Parent cannot create GuardianLink (admin-only).
2) Parent cannot read teacher intelligence:
   - learnerSupportProfiles
   - learnerInsights
   - sessionInsights
3) Client cannot write:
   - Subscription / Invoice / EntitlementGrant
4) Site scope enforced everywhere `siteId` exists.
5) Audit logs exist for privileged actions:
   - provisioning + guardian link changes
   - approvals (listing/contract/payout)
   - billing updates
   - insight generation/approval

---

## Admin-only “Kyle & Parrot”
Admin must capture and store:
- LearnerProfile.metadata.kyleParrot = { kyleAnswer, parrotAnswer }
Parents cannot edit these. Recommended: parents cannot read them.

---

## API auth middleware (required)
Every privileged endpoint:
- verify Firebase ID token
- load user doc → role + siteIds
- enforce site scope
- enforce role permission
- write AuditLog
- proceed

---

## Firestore rules principles
- deny-by-default
- role-based allow lists
- explicit parent denies for intelligence collections
- prevent client from writing server-authoritative collections

Concrete allow/deny matrix and rule patterns: `docs/26_FIRESTORE_RULES_SPEC.md`
