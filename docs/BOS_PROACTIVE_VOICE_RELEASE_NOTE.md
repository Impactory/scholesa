# BOS Proactive Voice Auto-Assist — Release Note

## Summary
This release enables BOS to proactively trigger AI coaching with spoken guidance when learners appear to hesitate, and enables automatic spoken greeting when the assistant opens.

## Included behavior
- Floating assistant opens by click and hover (pointer platforms) and automatically speaks greeting.
- BOS proactive engine runs periodic idle scans for learners.
- BOS evaluates hesitation via runtime state and intervention salience.
- AI coach automatically generates and speaks proactive nudges.
- BOS events are emitted for proactive flow:
  - `idle_detected`
  - `ai_help_opened`
  - `ai_help_used`
- Learner-facing proactive behavior is enabled in both floating and embedded AI coach surfaces.

## Files changed
- [apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart](../apps/empire_flutter/app/lib/runtime/ai_coach_widget.dart)
- [apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart](../apps/empire_flutter/app/lib/runtime/global_ai_assistant_overlay.dart)
- [apps/empire_flutter/app/lib/runtime/ai_context_coach_section.dart](../apps/empire_flutter/app/lib/runtime/ai_context_coach_section.dart)
- [apps/empire_flutter/app/lib/ui/localization/app_strings.dart](../apps/empire_flutter/app/lib/ui/localization/app_strings.dart)
- [apps/empire_flutter/app/test/ai_coach_widget_regression_test.dart](../apps/empire_flutter/app/test/ai_coach_widget_regression_test.dart)

## Validation status
- Full Flutter suite passed: 176/176.
- Deterministic regression tests added for:
  - auto-spoken greeting
  - proactive hesitation-triggered spoken coaching + BOS event flow

## Risk notes
- Spoken output still depends on client platform audio permissions and browser autoplay policy (web).
- BOS auto-assist includes cooldown and inactivity thresholds to reduce over-triggering.

## Deployment checklist
1. Run tests before deploy:
   - `cd apps/empire_flutter/app`
   - `flutter test`
2. Run static checks:
   - `flutter analyze`
3. Verify Firebase callable availability in target env:
   - `genAiCoach`
   - `bosGetIntervention`
   - `bosIngestEvent`
4. Smoke test in staging (learner account):
   - Open floating assistant by click: greeting is spoken.
   - Open floating assistant by hover (desktop/web pointer): greeting is spoken.
   - Leave learner idle/hesitating: proactive spoken nudge appears without manual prompt.
   - Confirm telemetry events emitted (`idle_detected`, `ai_help_opened`, `ai_help_used`).
5. Validate i18n:
   - English and Spanish proactive strings render.
6. Rollout:
   - Deploy to staging first, monitor for 24h.
   - Promote to production.

## Rollback plan
- If proactive behavior is too aggressive or voice degrades UX:
  - Revert release commit(s) touching runtime assistant files.
  - Redeploy app bundle.
  - Keep BOS backend callable endpoints unchanged.

## Post-deploy observability
Track daily:
- proactive trigger count per active learner
- helpful feedback ratio on AI responses
- average session time after proactive assist
- error rate for AI call + voice playback failures
