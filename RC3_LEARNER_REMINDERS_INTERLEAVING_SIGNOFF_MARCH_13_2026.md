# RC3 LEARNER REMINDERS + INTERLEAVING SIGNOFF
## March 13, 2026

**Status**: ✅ Release-signoff accepted with bounded residuals

**Scope**:
- REQ-081: learner goals, reminders, and value prompts
- REQ-084: interleaving engine with confusability matrix and mode toggle

---

## Decision

Both surfaces are signoff-ready for the current RC3 learner release path.

They remain marked `🟠` in the matrix because there are still known depth improvements beyond the current contract proof:
- REQ-081 does not yet include a live external push-provider delivery assertion beyond the typed provider contract test.
- REQ-084 still uses heuristic weighting for curriculum confusability rather than a fully authored curriculum graph.

Those residuals are not blocking the learner release path because the required user-visible behavior, persistence path, telemetry path, and backend generation path are now proven.

---

## Evidence Summary

### REQ-081: Learner goals, reminders, and value prompts

Implemented path:
- Flutter learner setup persists reminder preferences and value prompts.
- Reminder preferences sync through callable wiring.
- Backend stores learner reminder preferences.
- Shared reminder scheduler generates `learner_goal_reminder` notification requests.
- Typed notification payloads are proven against the notify-provider contract.
- Live canary proves reminder queue generation and `notification.requested` telemetry for the learner path.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`
- `apps/empire_flutter/app/lib/services/notification_service.dart`
- `functions/src/index.ts`
- `functions/src/notificationPipeline.ts`
- `scripts/learner_reminder_live_canary.js`

Validation evidence:
- Widget + persistence proof: `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Provider contract proof: `functions/src/notificationPipeline.test.ts`
- Live canary result:
  - `projectId=studio-3328096157-e3f79`
  - `queued=1`
  - `requestFound=true`
  - `telemetryFound=true`

Release read:
- The learner reminder path is operational end to end through queue generation and telemetry verification.
- The remaining gap is only that the external provider is validated through a focused contract test, not a live third-party push receipt.

### REQ-084: Interleaving engine with confusability matrix and mode toggle

Implemented path:
- Scaffolded mixed interleaving persists on learner mission assignments.
- Recommendation ordering now uses mission skills plus snapshot-derived misconception and confusability tags.
- Confusability-band output persists and is reflected in learner mission state.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart`
- `apps/empire_flutter/app/lib/modules/missions/mission_models.dart`
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`

Validation evidence:
- Service regression proof: `apps/empire_flutter/app/test/persistence_blockers_regression_test.dart`
- Widget + learner surface proof: `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Focused regression result: `flutter test test/persistence_blockers_regression_test.dart` passed

Release read:
- The current engine satisfies the contract for mode toggle, persisted recommendation output, and confusability-aware ordering.
- The remaining gap is sophistication, not correctness: authored curriculum weighting can still improve beyond the current snapshot-tag heuristic.

---

## Release Position

For RC3 learner release purposes:
- REQ-081 is accepted as ship-ready with bounded residual risk.
- REQ-084 is accepted as ship-ready with bounded residual risk.

These items should not block learner release confidence, telemetry confidence, or clean build confidence.

---

## Residuals To Carry Forward

1. Add a true live provider receipt check if external push-delivery proof becomes a gate.
2. Extend curriculum confusability from snapshot-tag heuristics to authored misconception graphs or weighted curriculum topology.

---

## Command Evidence

Verified during this signoff pass:

```bash
cd functions && npm run build && npx jest --runInBand src/notificationPipeline.test.ts
cd apps/empire_flutter/app && flutter test test/persistence_blockers_regression_test.dart
cd /Users/simonluke/dev/scholesa && node scripts/learner_reminder_live_canary.js --project=studio-3328096157-e3f79 --strict
```

Observed results:
- Functions build: passed
- Notification pipeline Jest proof: 3/3 passed
- Flutter persistence regression: passed
- Learner reminder live canary: passed