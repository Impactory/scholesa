# BOS-MIA + AI Usefulness KPI Checklist (2-Week Validation)

## Goal
Move from "integration complete" to evidence-based usefulness using telemetry already present in the app.

## Scope
- Audience: learner role only
- Window: 14 consecutive days
- Unit of analysis: site, then global rollup
- Required minimum sample: 100 learner sessions per site (or 300 globally)

## Event Inputs (Existing)
- `cta.clicked` with metadata:
  - `cta=global_ai_assistant_open`
  - `cta=global_ai_assistant_close`
  - `trigger` (`click`, `hover`, `bos_auto_popup`)
- `idle_detected`
- `focus_restored`
- `ai_help_opened`
- `ai_help_used`
- `voice.transcribe`
- `voice.message`
- `ai_coach_response`
- `ai_coach_feedback`

## KPI Definitions

1) BOS Proactive Activation Rate
- Formula: `bos_auto_popup_open_count / learner_session_count`
- Where `bos_auto_popup_open_count` = count of `cta.clicked` where `metadata.cta=global_ai_assistant_open` and `metadata.trigger=bos_auto_popup`
- Target: `>= 0.25` and `<= 1.50` per learner session
- Why: too low means BOS not triggering; too high means potential over-triggering

2) Proactive Completion Parity
- Formula: `bos_auto_popup_close_count / bos_auto_popup_open_count`
- Target: `>= 0.92`
- Why: validates users can exit/complete assistant flow after BOS-driven open

3) Hesitation Recovery Rate
- Formula: `focus_restored_within_120s_after_idle / idle_detected_count`
- Target: `>= 0.45`
- Why: core usefulness signal that BOS+AI helps learners re-engage quickly

4) Help Conversion Rate
- Formula: `ai_help_used_count / ai_help_opened_count`
- Target: `>= 0.55`
- Why: confirms opens become meaningful usage

5) Voice-First Completion Rate
- Formula: `voice.message_count / voice.transcribe_count`
- Target: `>= 0.70`
- Why: measures transcription-to-message handoff quality in voice-only flow

6) AI Response Coverage
- Formula: `ai_coach_response_count / ai_help_used_count`
- Target: `>= 0.95`
- Why: confirms assistant usage returns an actual response reliably

7) Learner Positive Feedback Ratio
- Formula: `positive_ai_feedback_count / total_ai_feedback_count`
- Target: `>= 0.65`
- Why: direct perceived usefulness signal

8) HQ Real-World Usability Score
- Formula: `avg(usability_score, usefulness_score, reliability_score, voice_quality_score)` from `bos_mia.usability.feedback`
- Target: `>= 4.0 / 5.0`
- Why: leadership-level field feedback on real deployment quality

## Guardrail Metrics (Must Pass)

A) BOS Spam Guardrail
- Condition: `bos_auto_popup_open_count per learner per 10 min <= 2`
- Fail if exceeded in >5% of learner sessions

B) Voice Failure Guardrail
- Condition: `(voice.transcribe_count - voice.message_count) / voice.transcribe_count <= 0.30`
- Fail if above threshold for 2 consecutive days

C) Silent Failure Guardrail
- Condition: `ai_help_used_count - ai_coach_response_count <= 5%`
- Fail if exceeded for any full day

## Go / No-Go Rubric (after 14 days)
- GO (scale):
  - At least 7/8 core KPIs hit target
  - All 3 guardrails pass
- CONDITIONAL GO:
  - 6/8 core KPIs hit
  - No more than 1 guardrail fail, with a concrete mitigation plan
- NO-GO:
  - <=5/8 core KPIs hit, or >=2 guardrail failures

## Daily Operating Checklist (10 minutes)
- Confirm BOS proactive open/close parity trend is stable
- Check hesitation recovery trend by site
- Check voice handoff drop (`voice.transcribe` -> `voice.message`)
- Check AI response coverage and feedback ratio
- Flag outlier sites for educator coaching + mic permission checks

## Week 1 / Week 2 Actions

Week 1 (stability)
- Tune only thresholds/cooldowns if BOS spam guardrail is failing
- Fix permission and audio blockers on affected devices/sites

Week 2 (optimization)
- Improve prompt quality where feedback ratio is weak
- Tighten BOS trigger logic only if recovery remains below target

## Decision Output Template
- `Integration confidence`: 95/100 (current)
- `Usefulness confidence`: ___ /100 (derived from KPI outcomes)
- `Decision`: GO / CONDITIONAL GO / NO-GO
- `Top 3 blockers`: ...
- `Next 2 engineering actions`: ...
