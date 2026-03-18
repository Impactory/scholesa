# 49_ROUTE_FLIP_TRACKER.md
Route Flip Tracker - Enabled Features Registry

Last Updated: 2026-03-18
Source of Truth: `apps/empire_flutter/app/lib/router/app_router.dart` (`kKnownRoutes`)

## Status Summary

- Total routes in registry: **52**
- Enabled routes: **52**
- Disabled routes: **0**
- Redirect-only routes outside registry: **1** (`/register` → `/login`)
- Placeholder/coming-soon on enabled routes: **under active audit**

## Category Coverage

| Category | Enabled | Disabled | Total |
|---|---:|---:|---:|
| Public/Auth/Dashboard | 3 | 0 | 3 |
| Learner | 6 | 0 | 6 |
| Educator | 9 | 0 | 9 |
| Parent | 6 | 0 | 6 |
| Site | 10 | 0 | 10 |
| Partner | 3 | 0 | 3 |
| HQ | 11 | 0 | 11 |
| Cross-role | 4 | 0 | 4 |
| **Total** | **52** | **0** | **52** |

## Enabled Route Registry

### Public/Auth/Dashboard
- `/welcome`
- `/login`
- `/`

### Learner
- `/learner/onboarding`
- `/learner/today`
- `/learner/missions`
- `/learner/habits`
- `/learner/portfolio`
- `/learner/settings`

### Educator
- `/educator/today`
- `/educator/attendance`
- `/educator/sessions`
- `/educator/learners`
- `/educator/missions/review`
- `/educator/review-queue`
- `/educator/mission-plans`
- `/educator/learner-supports`
- `/educator/integrations`

### Parent
- `/parent/summary`
- `/parent/billing`
- `/parent/schedule`
- `/parent/portfolio`
- `/parent/messages`
- `/parent/settings`

### Site
- `/site/checkin`
- `/site/provisioning`
- `/site/dashboard`
- `/site/sessions`
- `/site/scheduling`
- `/site/ops`
- `/site/incidents`
- `/site/identity`
- `/site/integrations-health`
- `/site/billing`

### Partner
- `/partner/listings`
- `/partner/contracts`
- `/partner/payouts`

### HQ
- `/hq/user-admin`
- `/hq/role-switcher`
- `/hq/sites`
- `/hq/analytics`
- `/hq/billing`
- `/hq/approvals`
- `/hq/audit`
- `/hq/safety`
- `/hq/integrations-health`
- `/hq/curriculum`
- `/hq/feature-flags`

### Cross-role
- `/messages`
- `/notifications`
- `/profile`
- `/settings`

## Route Flip Gate Compliance (per docs/65)

1. UI compiles and routes are registered in the live router: ✅
2. Role gate enforcement present on gated routes: ✅
3. Full manual route-by-route end-to-end re-certification: pending
4. Service/API wiring complete on every enabled route: under active audit
5. No placeholder or fake action on every enabled route: under active audit
6. Offline support where applicable: under active audit

## Change Log

| Date | Scope | Action |
|---|---|---|
| 2026-02-23 | Full registry | Reconciled tracker to live `kKnownRoutes`; all 46 routes enabled |
| 2026-03-17 | Router registry + audit posture | Corrected live route count to 47 known routes, noted `/register` redirect route, and removed unsupported blanket route-compliance claims pending the current release audit |
| 2026-03-18 | Inventory-aligned aliases | Added 5 documented alias routes with honest equivalent screens: learner settings, educator review queue, parent messages, parent settings, and site scheduling |

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `49_ROUTE_FLIP_TRACKER.md`
<!-- TELEMETRY_WIRING:END -->
