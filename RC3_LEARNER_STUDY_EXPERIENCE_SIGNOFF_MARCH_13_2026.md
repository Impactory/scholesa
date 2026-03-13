# RC3 LEARNER STUDY EXPERIENCE SIGNOFF
## March 13, 2026

**Status**: ✅ Release-signoff accepted with bounded residuals

**Scope**:
- REQ-082: study session orchestration with KT plus FSRS review UX
- REQ-085: worked-example injection, fading, and decay after sustained correctness
- REQ-087: motivation layer: autonomy choices, competence signals, shout-outs
- REQ-088: accessibility surfaces: keyboard-only, drag alternatives, TTS, reading level, reduced distraction, contrast controls

---

## Decision

These learner study-experience surfaces are accepted as ship-ready for the current RC3 learner release path.

They remain marked `🟠` in the matrix because the residuals are depth and parity gaps beyond the current release contract, not failures of the implemented learner flow.

---

## Evidence Summary

### REQ-082: Study session orchestration with KT plus FSRS review UX

Implemented path:
- Learner mission study surfaces persist FSRS state, interleaving mode, and review timing.
- Study-flow controls are present in learner mission UX.
- Learner telemetry is emitted for the reviewed mission-flow actions already in scope.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart`
- `apps/empire_flutter/app/lib/modules/missions/mission_models.dart`
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`

Validation evidence:
- Widget + service regression proof in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Persistence regression proof in `apps/empire_flutter/app/test/persistence_blockers_regression_test.dart`

Residual:
- Broader scheduler parity is still incomplete.

Release read:
- The learner-facing orchestration flow is functioning, persisted, and regression-covered.
- The remaining gap is broader scheduler parity beyond the current learner release path.

### REQ-085: Worked-example injection, fading, and decay after sustained correctness

Implemented path:
- Worked examples can be shown and persisted.
- Fade-stage progression is persisted.
- Prompt-level decay is represented in learner mission state and surfaced in the mission flow.
- Sustained correct FSRS ratings now automatically decay worked-example support and persist the resulting fade stage.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart`
- `apps/empire_flutter/app/lib/modules/missions/mission_models.dart`
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`

Validation evidence:
- Widget + service regression proof in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Persistence regression proof in `apps/empire_flutter/app/test/persistence_blockers_regression_test.dart`
- Focused regression now covers sustained-correctness worked-example decay in `apps/empire_flutter/app/test/persistence_blockers_regression_test.dart`

Residual:
- Longer-horizon mastery policy is still incomplete beyond the current sustained-correctness decay window.

Release read:
- The current worked-example system satisfies the release contract for injection, persistence, fade progression, and sustained-correctness decay.
- The remaining gap is longer-horizon mastery sophistication beyond the current decay window, not present-release correctness.

### REQ-087: Motivation layer: autonomy choices, competence signals, shout-outs

Implemented path:
- The learner motivation loop card surfaces goals, reminders, value prompts, and reflection entry points.
- The learner motivation loop now includes a shout-out action that persists a learner celebration record through the reflection path.
- The learner-facing loop supports autonomy and competence signaling in the current dashboard path.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`
- `apps/empire_flutter/app/lib/i18n/learner_surface_i18n.dart`
- `src/lib/motivation/motivationEngine.ts`
- `src/lib/telemetry/sdtTelemetry.ts`

Validation evidence:
- Widget proof in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Widget regression now covers shout-out persistence in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`

Residual:
- Wider motivation-engine parity is still incomplete.

Release read:
- The current learner release path includes a functioning motivation loop with real learner-visible prompts, persistence-linked actions, and a persisted shout-out path.
- Remaining parity work does not block current learner release behavior.

### REQ-088: Accessibility surfaces: keyboard-only, drag alternatives, TTS, reading level, reduced distraction, contrast controls

Implemented path:
- Learner setup persists accessibility preferences.
- Reading level, reduced-distraction, and related learner settings are surfaced in the learner flow.
- Mission study details now honor keyboard-only learner preferences with explicit no-drag controls, large action buttons, and a visible close affordance.
- Accessibility-setting telemetry is already captured in the live learner event path.

Primary implementation files:
- `apps/empire_flutter/app/lib/modules/learner/learner_today_page.dart`
- `apps/empire_flutter/app/lib/modules/missions/missions_page.dart`
- `apps/empire_flutter/app/lib/domain/models.dart`
- `apps/empire_flutter/app/lib/i18n/learner_surface_i18n.dart`
- `apps/empire_flutter/app/lib/i18n/workflow_surface_i18n.dart`

Validation evidence:
- Widget + persistence proof in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Widget regression now covers keyboard-only mission controls and no-drag mission actions in `apps/empire_flutter/app/test/learner_site_surfaces_localization_test.dart`
- Live telemetry audit coverage for `accessibility.setting.changed`

Residual:
- Formal WCAG automation and broader accessibility parity beyond the learner mission release path are still missing.

Release read:
- Accessibility preference persistence, learner-facing configuration, and keyboard-only no-drag mission actions are operational in the current release path.
- The remaining gap is deeper accessibility breadth and automation, not a broken learner accessibility flow.

---

## Release Position

For RC3 learner release purposes:
- REQ-082 is accepted as ship-ready with bounded residual risk.
- REQ-085 is accepted as ship-ready with bounded residual risk.
- REQ-087 is accepted as ship-ready with bounded residual risk.
- REQ-088 is accepted as ship-ready with bounded residual risk.

These items should not block learner release confidence or the current clean build and telemetry confidence position.

---

## Residuals To Carry Forward

1. Complete broader scheduler parity for the study orchestration layer.
2. Extend worked-example decay to a fuller long-horizon correctness policy.
3. Close wider motivation-engine parity gaps.
4. Add automated WCAG coverage and broader non-learner accessibility parity.

---

## Command Evidence

Evidence already established and referenced by this signoff:

```bash
cd apps/empire_flutter/app && flutter test test/persistence_blockers_regression_test.dart
npm run qa:telemetry-live-audit -- --hours=720 --project=studio-3328096157-e3f79
```

Observed results used by this signoff:
- Flutter persistence regression: passed
- Learner telemetry audit: passed