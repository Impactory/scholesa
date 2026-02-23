# 49_ROUTE_FLIP_TRACKER.md
Route Flip Tracker - Enabled Features Registry

Last Updated: 2026-02-23
Source of Truth: `apps/empire_flutter/app/lib/router/app_router.dart` (`kKnownRoutes`)

## Status Summary

- Total routes in registry: **46**
- Enabled routes: **46**
- Disabled routes: **0**
- Placeholder/coming-soon on enabled routes: **0**

## Category Coverage

| Category | Enabled | Disabled | Total |
|---|---:|---:|---:|
| Public/Auth/Dashboard | 3 | 0 | 3 |
| Learner | 4 | 0 | 4 |
| Educator | 8 | 0 | 8 |
| Parent | 4 | 0 | 4 |
| Site | 9 | 0 | 9 |
| Partner | 3 | 0 | 3 |
| HQ | 11 | 0 | 11 |
| Cross-role | 4 | 0 | 4 |
| **Total** | **46** | **0** | **46** |

## Enabled Route Registry

### Public/Auth/Dashboard
- `/welcome`
- `/login`
- `/`

### Learner
- `/learner/today`
- `/learner/missions`
- `/learner/habits`
- `/learner/portfolio`

### Educator
- `/educator/today`
- `/educator/attendance`
- `/educator/sessions`
- `/educator/learners`
- `/educator/missions/review`
- `/educator/mission-plans`
- `/educator/learner-supports`
- `/educator/integrations`

### Parent
- `/parent/summary`
- `/parent/billing`
- `/parent/schedule`
- `/parent/portfolio`

### Site
- `/site/checkin`
- `/site/provisioning`
- `/site/dashboard`
- `/site/sessions`
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

1. UI renders without errors: ✅
2. Service/API wiring complete: ✅
3. Role gate enforcement active: ✅
4. Offline support where applicable: ✅
5. No placeholder for enabled routes: ✅
6. Design language consistency: ✅

## Change Log

| Date | Scope | Action |
|---|---|---|
| 2026-02-23 | Full registry | Reconciled tracker to live `kKnownRoutes`; all 46 routes enabled |
