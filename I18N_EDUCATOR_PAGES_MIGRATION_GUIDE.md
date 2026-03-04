# i18n Migration Guide: Educator Pages (Post-Launch)

**Status**: Post-Launch Enhancement  
**Created**: March 3, 2026  
**Scope**: 6 remaining educator pages

---

## Background

The Scholesa platform uses a **centralized i18n system** via `BosCoachingI18n` (in `apps/empire_flutter/app/lib/i18n/bos_coaching_i18n.dart`) for shared coaching and education concepts.

Currently, 6 educator pages still use **inline translation maps** instead of the centralized system:

1. [educator_integrations_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart)
2. [educator_mission_plans_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_mission_plans_page.dart)
3. [educator_sessions_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_sessions_page.dart)
4. [educator_learner_supports_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_learner_supports_page.dart)
5. [educator_mission_review_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_mission_review_page.dart)
6. [educator_today_page.dart](apps/empire_flutter/app/lib/modules/educator/educator_today_page.dart)

---

## Migration Steps (per page)

### 1. Import BosCoachingI18n

```dart
import '../../i18n/bos_coaching_i18n.dart';
```

### 2. Map Inline Strings to BosCoachingI18n Methods

Example for `educator_sessions_page.dart`:

| Inline Key | BosCoachingI18n Method | Notes |
|------------|------------------------|-------|
| 'Upcoming' | `BosCoachingI18n.upcoming(context)` | NEW: Add if needed |
| 'Ongoing' | `BosCoachingI18n.sessionInProgress(context)` | Already in system |
| 'Past' | `BosCoachingI18n.sessionCompleted(context)` | Already in system |
| 'Enrolled' | Via learner model | Already available |
| 'Schedule' | `BosCoachingI18n.sessionSchedule(context)` | NEW: Add if needed |

### 3. Remove _educatorXxxEs Map and _tEducatorXxx Function

Once all strings are migrated, delete:

```dart
const Map<String, String> _educatorSessionsEs = <String, String>{...};
String _tEducatorSessions(BuildContext context, String input) {...}
```

### 4. Update Calls

Replace:

```dart
// OLD
_tEducatorSessions(context, 'Upcoming')

// NEW
BosCoachingI18n.upcoming(context)
```

---

## BosCoachingI18n Methods Currently Available

```dart
// Core metrics
BosCoachingI18n.cognition(context)
BosCoachingI18n.engagement(context)
BosCoachingI18n.integrity(context)
BosCoachingI18n.improvementScore(context)
BosCoachingI18n.mvlStatus(context)
BosCoachingI18n.activeGoals(context)

// Session
BosCoachingI18n.sessionLoopTitle(context)
BosCoachingI18n.latestSignal(context)
BosCoachingI18n.sessionLoopEmpty(context)
BosCoachingI18n.sessionInProgress(context)
BosCoachingI18n.sessionCompleted(context)
```

---

## Pages NOT Yet Migrated (Ready for RC3.1)

| Page | Strings to Migrate | Effort |
|------|--------------------|--------|
| educator_integrations_page.dart | 15 strings | ~20 min |
| educator_mission_plans_page.dart | 18 strings | ~25 min |
| educator_sessions_page.dart | 22 strings | ~30 min |
| educator_learner_supports_page.dart | 12 strings | ~15 min |
| educator_mission_review_page.dart | 16 strings | ~20 min |
| educator_today_page.dart | 20 strings | ~25 min |

**Total Effort**: ~2 hours (can be batched in RC3.1)

---

## Advantages of Centralized i18n

1. **Consistency**: All translations updated in one place
2. **Reusability**: No duplication of strings across 6 pages
3. **Maintainability**: New locale support added automatically
4. **Telemetry**: Centralized logging of i18n misses
5. **Governance**: Single source of truth for education terminology

---

## Next Actions

1. ✅ **RC3 (Current)**: educator_learners_page.dart migrated (demo)
2. ⏳ **RC3.1 (Post-Launch)**: Migrate remaining 6 pages (2 hours)
3. ⏳ **RC3.2**: Audit learner/parent/hq pages for i18n consolidation

---

**Migration Owner**: Assigned to dev team  
**Deadline**: RC3.1 (within 1 sprint post-launch)
