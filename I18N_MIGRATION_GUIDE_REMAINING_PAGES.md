# i18n Migration Guide: Remaining 6 Educator Pages

**Status**: Ready for Migration  
**Priority**: Optional (Post-Launch Optimization)  
**Effort**: ~1–2 hours total (~15 minutes per page)

---

## Overview

This guide details the i18n migration pattern for the 6 remaining educator pages to use the centralized `BosCoachingI18n` class for BOS/MIA-specific translations, ensuring consistency across all 10 surfaces (7 educator + 3 parent pages).

**Pages to Migrate**:
1. educator_learners_page.dart
2. educator_today_page.dart
3. educator_mission_review_page.dart
4. educator_mission_plans_page.dart
5. educator_learner_supports_page.dart
6. educator_integrations_page.dart

---

## Migration Pattern

### BEFORE (Current State with Hardcoded Maps)

```dart
import 'package:flutter/material.dart';

const Map<String, String> _educatorLearnersEs = <String, String>{
  'My Learners': 'Mis estudiantes',
  'Cognition': 'Cognición',
  'Engagement': 'Compromiso',
  'Integrity': 'Integridad',
  'BOS/MIA Learner Loop': 'Ciclo BOS/MIA del estudiante',
  // ... other keys
};

String _tEducatorLearners(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorLearnersEs[input] ?? input;
}

class EducatorLearnersPage extends StatefulWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
      Text(_tEducatorLearners(context, 'Cognition')),
      Text(_tEducatorLearners(context, 'BOS/MIA Learner Loop')),
    );
  }
}
```

### AFTER (Centralized i18n)

```dart
import 'package:flutter/material.dart';
import 'package:scholesa/i18n/bos_coaching_i18n.dart';

const Map<String, String> _educatorLearnersEs = <String, String>{
  'My Learners': 'Mis estudiantes',
  // Page-specific strings only (non-BOS/MIA)
};

String _tEducatorLearnersPageSpecific(BuildContext context, String input) {
  final String locale = Localizations.localeOf(context).languageCode;
  if (locale != 'es') return input;
  return _educatorLearnersEs[input] ?? input;
}

class EducatorLearnersPage extends StatefulWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
      // Use BosCoachingI18n for BOS/MIA-specific keys:
      Text(BosCoachingI18n.cognition(context)),  // ✅ Centralized
      Text(BosCoachingI18n.get(context, 'sessionLoopTitle')),  // ✅ Centralized
      
      // Use page-specific translation function for non-BOS/MIA keys:
      Text(_tEducatorLearnersPageSpecific(context, 'My Learners')),  // Local
    );
  }
}
```

---

## Step-by-Step Migration

### Step 1: Add Import

Add to the top of the file after existing imports:

```dart
import 'package:scholesa/i18n/bos_coaching_i18n.dart';
```

### Step 2: Identify BOS/MIA Keys

Search the file for these patterns and mark for migration:
- `'Cognition'`
- `'Engagement'`
- `'Integrity'`
- `'Goals'` / `'Active Learning Goals'`
- `'MVL'` / `'Mastery Validation'` / `mvlActive`/`mvlPassed`/`mvlFailed`
- `'Improvement Score'` / `'score'` / `'delta'`
- `'BOS/MIA'` / `'Learning Loop'` / `'Session Loop'` / `'Family'` references
- `'loadingInsights'` / `'errorLoadingInsights'`
- `'latestSignal'`

**Available BosCoachingI18n Keys** (25 total):
```
sessionLoopTitle, sessionLoopSubtitle, sessionLoopEmpty,
familyLearningTitle, familyLearningSubtitle, familyLearningEmpty,
familyScheduleTitle, familyScheduleSubtitle, familyScheduleEmpty,
familyBillingTitle, familyBillingSubtitle, familyBillingEmpty,
cognition, engagement, integrity,
improvementScore, activeGoals, mvlStatus,
mvlActive, mvlPassed, mvlFailed,
loadingInsights, errorLoadingInsights, latestSignal
```

### Step 3: Remove BOS/MIA Keys from Local Map

Edit `_educatorLearnersEs` to remove BOS/MIA-specific translations:

```dart
const Map<String, String> _educatorLearnersEs = <String, String>{
  'My Learners': 'Mis estudiantes',
  'Track progress and engagement': 'Sigue progreso y compromiso',
  // Remove:
  // 'Cognition': 'Cognición',  ❌ Delete
  // 'Engagement': 'Compromiso',  ❌ Delete
  // 'Integrity': 'Integridad',  ❌ Delete
  // Pages-specific strings only (non-BOS/MIA)
};
```

### Step 4: Replace Translation Calls

Replace hardcoded `_tEducatorLearners(context, 'key')` calls with `BosCoachingI18n` calls:

**Example replacements**:

```dart
// BEFORE
Text(_tEducatorLearners(context, 'Cognition'))

// AFTER
Text(BosCoachingI18n.cognition(context))

// BEFORE
Text(_tEducatorLearners(context, 'BOS/MIA Learner Loop'))

// AFTER
Text(BosCoachingI18n.get(context, 'sessionLoopTitle'))

// BEFORE
Text(_tEducatorLearners(context, 'Active Goals'))

// AFTER
Text(BosCoachingI18n.activeGoals(context))
```

---

## Mapping Guide: Common BOS/MIA Strings → BosCoachingI18n Keys

| Old String | BosCoachingI18n Key | Method |
|-----------|-------|--------|
| Cognition | cognition | `BosCoachingI18n.cognition(context)` |
| Engagement | engagement | `BosCoachingI18n.engagement(context)` |
| Integrity | integrity | `BosCoachingI18n.integrity(context)` |
| Improvement Score / score | improvementScore | `BosCoachingI18n.improvementScore(context)` |
| Active Learning Goals | activeGoals | `BosCoachingI18n.activeGoals(context)` |
| MVL / Mastery Validation | mvlStatus | `BosCoachingI18n.mvlStatus(context)` |
| In Progress | mvlActive | `BosCoachingI18n.mvlActive(context)` |
| Passed | mvlPassed | `BosCoachingI18n.mvlPassed(context)` |
| Failed / Challenged | mvlFailed | `BosCoachingI18n.mvlFailed(context)` |
| BOS/MIA Session Loop | sessionLoopTitle | `BosCoachingI18n.sessionLoopTitle(context)` |
| BOS/MIA Family Loop | familyLearningTitle | `BosCoachingI18n.familyLearningTitle(context)` |
| Loading insights... | loadingInsights | `BosCoachingI18n.loadingInsights(context)` |
| Unable to load | errorLoadingInsights | `BosCoachingI18n.errorLoadingInsights(context)` |

---

## Implementation Order (Recommended)

Migrate in this order (lowest to highest complexity):

1. **educator_today_page.dart** – Likely smallest scope
2. **educator_integrations_page.dart** – Integration-specific, fewer BOS/MIA refs
3. **educator_learner_supports_page.dart** – Support view
4. **educator_mission_review_page.dart** – Mission-specific view
5. **educator_mission_plans_page.dart** – Plan management
6. **educator_learners_page.dart** – Largest (most learners list features)

---

## Verification Checklist

For each migrated page:

- [ ] Import `BosCoachingI18n` added
- [ ] All BOS/MIA-specific string refs replaced with `BosCoachingI18n.*` calls
- [ ] Page-specific (non-BOS/MIA) strings kept in local `_*Es` map
- [ ] Local translation function only handles non-BOS/MIA keys
- [ ] `flutter analyze` runs without errors
- [ ] Tested in Spanish locale (es) – all BOS/MIA strings appear correctly
- [ ] Tested in English locale (en) – all strings appear correctly

---

## Testing the Migration

### Verify English Locale

```dart
// With device locale set to en_US:
flutter run
// Navigate to page
// Verify: 'Cognition', 'Engagement', 'Integrity', 'Improvement Score' display in English
```

### Verify Spanish Locale

```dart
// With device locale set to es_ES:
flutter run
// Navigate to page
// Verify: 'Cognición', 'Participación', 'Integridad', 'Puntuación de mejora' display in Spanish
```

### Static Analysis

```bash
cd apps/empire_flutter/app
flutter analyze --no-fatal-infos
# Should show 0 errors (4 info-level lints OK)
```

---

## Expected Changes Summary

| Page | Est. Changes | BOS/MIA Keys Migrated |
|------|-----|----|
| educator_today_page | ~8–12 replacements | 5–7 |
| educator_integrations_page | ~6–10 replacements | 3–5 |
| educator_learner_supports_page | ~10–15 replacements | 6–8 |
| educator_mission_review_page | ~12–18 replacements | 8–10 |
| educator_mission_plans_page | ~12–18 replacements | 8–10 |
| educator_learners_page | ~15–20 replacements | 10–12 |
| **TOTAL** | **~63–93 replacements** | **~40–52** |

**Expected Effort**: 15 min/page × 6 pages = ~90 minutes (~1.5 hours)

---

## Post-Migration Benefits

✅ **Consistency**: All BOS/MIA strings use single centralized source  
✅ **Maintainability**: Changes to BOS/MIA terminology done in one place  
✅ **Scalability**: Adding new languages (th, zh-CN) only requires updating `BosCoachingI18n`  
✅ **Reduced Code Duplication**: Each page has ~15–20 fewer lines of hardcoded maps  
✅ **Easier Testing**: Centralized i18n class can be unit tested independently

---

## References

- BosCoachingI18n class: `apps/empire_flutter/app/lib/i18n/bos_coaching_i18n.dart`
- Firebase i18n keys: `packages/i18n/locales/{en,es}.json` (bosCoaching namespace)
- Example migration: `educator_sessions_page.dart` (reference, not yet migrated but should follow this pattern)

---

## When to Complete

**Ideal Timeline**:
- **Before Launch**: Optional – System works with current local maps
- **Post-RC3**: Recommended – Clean up before RC4 hardening
- **Post-Launch**: Can be deferred – Not a blocker for production

**Recommendation**: Defer to post-launch phase if token budget constrains current window. The centralized system is ready; migration is a code quality optimization, not a functionality blocker.

---

**Document Version**: 1.0  
**Date**: March 3, 2026  
**Status**: Ready for Implementation
