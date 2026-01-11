# 49_ROUTE_FLIP_TRACKER.md
Route Flip Tracker - Enabled Features Registry

Last Updated: 2025-01-09

## Purpose
This document tracks which routes have been flipped from "disabled/placeholder" to "enabled/functional" as modules are implemented. A route is only flipped when its Module DoD (65_MODULE_DEFINITION_OF_DONE.md) passes.

---

## Route Registry Status

### Authentication Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/login` | ✅ ENABLED | 2025-01-09 | Firebase Auth login |
| `/register` | ✅ ENABLED | 2025-01-09 | Firebase Auth registration |

### Dashboard Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/` | ✅ ENABLED | 2025-01-09 | Role-based dashboard redirect |

### Educator Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/educator/attendance` | ✅ ENABLED | 2025-01-09 | Attendance module with offline support |
| `/educator/today` | ✅ ENABLED | 2025-01-09 | Today's schedule and quick actions |
| `/educator/sessions` | ❌ DISABLED | - | Session management |
| `/educator/learners` | ❌ DISABLED | - | Learner roster |
| `/educator/missions/review` | ❌ DISABLED | - | Mission review queue |

### Site Admin Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/site/provisioning` | ✅ ENABLED | 2025-01-09 | User provisioning + guardian linking |
| `/site/checkin` | ✅ ENABLED | 2025-01-09 | Physical site check-in/out |
| `/site/dashboard` | ❌ DISABLED | - | Site analytics |
| `/site/sessions` | ❌ DISABLED | - | Session scheduling |

### HQ Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/hq/user-admin` | ✅ ENABLED | 2025-01-09 | User administration CRUD |
| `/hq/sites` | ❌ DISABLED | - | Site management |
| `/hq/analytics` | ❌ DISABLED | - | Platform analytics |
| `/hq/billing` | ❌ DISABLED | - | Billing management |

### Learner Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/learner/today` | ✅ ENABLED | 2025-01-09 | Learner daily summary |
| `/learner/missions` | ✅ ENABLED | 2025-01-09 | Mission tracking with pillars |
| `/learner/habits` | ✅ ENABLED | 2025-01-09 | Habit coach with streaks |
| `/learner/portfolio` | ❌ DISABLED | - | Portfolio/achievements |

### Parent Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/parent/summary` | ✅ ENABLED | 2025-01-09 | Safe summary view of linked learners |
| `/parent/billing` | ❌ DISABLED | - | Payment history |
| `/parent/schedule` | ❌ DISABLED | - | Schedule view |

### Cross-Role Routes
| Route | Status | Flip Date | Notes |
|-------|--------|-----------|-------|
| `/messages` | ✅ ENABLED | 2025-01-09 | Notifications + conversations |
| `/profile` | ✅ ENABLED | 2025-01-09 | User profile and settings |
| `/settings` | ❌ DISABLED | - | App settings |

---

## Summary Statistics

| Category | Enabled | Disabled | Total |
|----------|---------|----------|-------|
| Auth | 2 | 0 | 2 |
| Dashboard | 1 | 0 | 1 |
| Educator | 2 | 3 | 5 |
| Site | 2 | 2 | 4 |
| HQ | 1 | 3 | 4 |
| Learner | 3 | 1 | 4 |
| Parent | 1 | 2 | 3 |
| Cross-Role | 2 | 1 | 3 |
| **Total** | **14** | **12** | **26** |

---

## Flip Criteria (from 65_MODULE_DEFINITION_OF_DONE.md)
Before flipping a route:
1. ✅ UI renders without errors
2. ✅ Service layer connects to API or mock data
3. ✅ Role gate enforces access control
4. ✅ Offline operations work (if applicable)
5. ✅ No placeholder/coming soon content
6. ✅ Follows design language

---

## Next Routes to Enable (Priority)
1. `/learner/today` - Learner daily view
2. `/educator/sessions` - Session management
3. `/profile` - User profile settings
4. `/site/dashboard` - Site analytics

---

## Change Log
| Date | Route | Action | Author |
|------|-------|--------|--------|
| 2025-01-09 | Multiple routes | Initial flip of 12 routes | Codex |
