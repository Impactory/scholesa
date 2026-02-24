# 26_FIRESTORE_RULES_SPEC.md

This is the **production Firestore rules specification** for Empire/Scholesa.
It is an allow/deny matrix plus required rule patterns so implementation is consistent.

> Rules MUST be **deny-by-default**. Every allow must have a reason.

---

## A) Rule philosophy
1) Least privilege: minimum access needed for workflow
2) Server authority where required:
   - billing/entitlements: API-only writes
   - intelligence (signals/insights): prefer API-only writes
3) Admin-only provisioning:
   - GuardianLink creation restricted to site/hq roles
4) Site scoping:
   - reads/writes permitted only within user.siteIds
5) Parent boundary:
   - parents never read teacher-only intelligence collections

---

## B) Required helper concepts (implement in rules)
Rules should implement helpers similar to:
- isAuthed()
- userRole()
- userSiteIds()
- hasSite(siteId)
- isAdmin()  (site or hq)
- isEducator(), isLearner(), isParent(), isPartner()

---

## C) Hard explicit denials (policy)
These must be denied even if other rules allow broad reads:

### Parent read DENY (teacher intelligence)
Parents must NOT read:
- learnerSupportProfiles
- learnerInsights
- sessionInsights

### Parent write DENY (provisioning & intake)
Parents must NOT write:
- guardianLinks
- learnerProfiles
- admin-only intake fields (Kyle/Parrot)

### Client write DENY (server-authoritative billing)
Clients must NOT write:
- subscriptions
- invoices
- entitlementGrants
(and any billing “status” fields that unlock access)

---

## D) Allow/Deny matrix by collection

### users/{uid}
- READ:
  - user can read self
  - site/hq can read users within shared site scope (optional)
- WRITE:
  - user can update limited self fields (e.g., displayName)
  - client cannot change role, siteIds, provisionedBy/provisionedAt, billingCustomerId

### sites/{siteId}
- READ:
  - authed users with membership
- WRITE:
  - hq only (or site admins limited fields if policy allows)

### guardianLinks/{id}
- READ:
  - site/hq can read for their site
  - parent can read links where parentId == uid (optional)
- WRITE:
  - CREATE/UPDATE/DELETE: site/hq only

### learnerProfiles/{id}, parentProfiles/{id}
- READ:
  - site/hq can read
  - educator can read within site if required
  - parentProfile: parent can read self (optional)
  - learnerProfile: parent read optional; recommended parent-safe fields only
- WRITE:
  - CREATE/UPDATE: site/hq only
  - deny parent writes; deny parent edits to Kyle/Parrot metadata always

### sessions, sessionOccurrences, enrollments
- READ:
  - site members within scope
- WRITE:
  - site/hq; educator only if policy explicitly allows

### attendanceRecords/{id}
- READ:
  - educator/site/hq within site
  - learner can read own (optional)
  - parent can read linked learner attendance (optional)
- WRITE:
  - educator/site/hq within site
  - validate recordedBy == request.auth.uid for educator writes
  - enforce deterministic doc id pattern if feasible

### missions, missionPlans
- READ:
  - site members; published missions may be broader if desired
- WRITE:
  - missionPlans: educators/site/hq only

### missionAttempts/{id}
- READ:
  - learner can read own
  - educator/site/hq can read within site
  - parent should not read raw attempts; use parent-safe summaries (recommended)
- WRITE:
  - learner can create/update attempt in draft/submitted
  - learner cannot write reviewedBy/reviewNotes
  - educator can write review fields and status transitions to reviewed

### billing collections (billingAccounts, billingPlans, subscriptions, invoices, entitlementGrants)
- READ:
  - owner roles within scope
- WRITE:
  - API/service account only

### cmsPages, leads
- READ:
  - cmsPages published public audience can be public
  - other audiences require matching role
- WRITE:
  - cmsPages: hq only
  - leads: allow create publicly OR via API (preferred)

### marketplace (partnerOrgs, listings, orders, fulfillments)
- READ:
  - listings published can be public/readable by sites
  - orders/fulfillments: buyer + site/hq within scope
- WRITE:
  - listing create: partner/site/hq allowed
  - listing approval fields: hq only
  - orders/fulfillments: prefer API-only (payments)

### contracting (contracts, deliverables, payouts)
- READ:
  - partner reads own; hq reads all
- WRITE:
  - partner writes drafts + deliverable submissions
  - hq writes approvals, acceptance, payouts approvals
  - payouts providerTransferId should be API-only

### telemetryEvents
- READ:
  - hq only
- WRITE:
  - create-only from client with strict validation (or route via API)
  - no updates

### intelligence + popups
- configs/supportStrategies, configs/popupRules:
  - READ: authed as needed
  - WRITE: hq only
- learnerSignals/sessionInsights/learnerInsights:
  - READ: educator/site/hq within site
  - WRITE: API-only recommended
- learnerSupportProfiles:
  - READ: educator/site/hq within site
  - WRITE: educator/site/hq allowed (audited); parents denied
- supportInterventions:
  - READ/WRITE: educator/site/hq within site (offline queue friendly)

---

## E) Emulator rules tests (mandatory)
Write tests that assert allow + deny cases for:
1) parent cannot create guardianLinks
2) parent cannot read sessionInsights / learnerInsights / learnerSupportProfiles
3) learner can write own missionAttempt but cannot set reviewed fields
4) educator can write attendance in site; cannot write other site
5) client cannot write entitlementGrants/subscriptions/invoices
6) partner cannot set approvedBy/approvedAt on listing

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `26_FIRESTORE_RULES_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
