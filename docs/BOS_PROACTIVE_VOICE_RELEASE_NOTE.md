# BOS Proactive Voice Auto-Assist — Release Note

## Summary
This release enables BOS to proactively trigger AI help with spoken guidance when learners appear to hesitate, and enables automatic spoken greeting when the assistant opens.

Current production policy: learner-facing spoken coaching may respond autonomously only when BOS/MIA returns certified confidence `>= 0.97`. Low-confidence, unavailable, or consent-blocked inference must escalate safely instead of speaking fabricated guidance.

## Included behavior
- Floating assistant opens by click and hover (pointer platforms) and automatically speaks greeting.
- BOS proactive engine runs periodic idle scans for learners.
- BOS evaluates hesitation via runtime state and intervention salience.
- AI help automatically generates and speaks proactive nudges.
- BOS events are emitted for proactive flow:
  - `idle_detected`
  - `ai_help_opened`
  - `ai_help_used`
- Learner-facing proactive behavior is enabled in both floating and embedded AI help surfaces.

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
- Learner-facing assistance is COPPA-gated and site-scoped; if consent or confidence requirements are not satisfied, the runtime must degrade to an escalation message rather than a direct coaching answer.

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
4. Smoke test in production cutover window (learner account):
   - Open floating assistant by click: greeting is spoken.
   - Open floating assistant by hover (desktop/web pointer): greeting is spoken.
   - Leave learner idle/hesitating: proactive spoken nudge appears without manual prompt.
   - Force a low-confidence or unavailable learner AI response and confirm the user receives an escalation or educator-review prompt rather than fabricated help.
   - Confirm telemetry events emitted (`idle_detected`, `ai_help_opened`, `ai_help_used`).
5. Validate i18n:
   - English, ZH-CN, and ZH-TW proactive strings render.
6. Rollout:
   - Use the full big-bang cutover flow in `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md`.
   - Complete `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md` before opening broad traffic.

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
- escalation rate caused by learner confidence/COPPA guardrails
