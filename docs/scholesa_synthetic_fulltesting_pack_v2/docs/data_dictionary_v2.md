# Scholesa Synthetic Full Testing Pack v2 — Data Dictionary

This pack extends the starter data with normalized tables, regression suites, policy/safety cases, schema edge cases, longitudinal records, and high-volume load-test requests.

## core_evidence_records_v2

- **record_id** — Unique synthetic record identifier.
- **learner_id** — Synthetic learner key; joins to learners_v2.csv.
- **cohort_id** — Synthetic class/cohort key; joins to cohorts_v2.csv.
- **session_id** — Synthetic session key; joins to sessions_v2.csv.
- **grade_band** — One of 1-3, 4-6, 7-9, 10-12.
- **task_family** — Curriculum-aligned task type such as claim_evidence or experiment_design.
- **prompt_text** — Prompt shown to the learner for the evidence bundle.
- **learner_response** — Synthetic learner response text.
- **artifact_summary** — Summary of proof-of-work artifact or linked evidence.
- **teacher_observation** — Synthetic teacher note/checkpoint observation.
- **peer_feedback** — Synthetic peer feedback snippet.
- **checkpoint_result** — pass, pass_with_support, or not_yet.
- **proof_of_work_present** — Whether matching proof-of-work exists.
- **ai_used** — Whether AI support was used.
- **ai_mode** — Teacher-led or student modes with audit assumptions.
- **mastery** — Rubric-aligned mastery label.
- **evidence_use** — Rubric-aligned evidence quality label.
- **metacognition** — Rubric-aligned reflection/self-monitoring label.
- **integrity_risk** — Low/medium/high risk estimate for process-ownership mismatch.
- **bos_mastery_expected** — Suggested BOS mastery score target for testing.
- **mia_integrity_expected** — Suggested MIA integrity score target for testing.

## expected_model_outputs_v2

- **bos_mastery_score_expected** — Suggested output score for learner mastery.
- **bos_readiness_score_expected** — Suggested output score for readiness/next-step support.
- **mia_integrity_score_expected** — Suggested integrity/trust score.
- **mia_review_needed_expected** — Whether a teacher/reviewer check is expected.
- **expected_action** — auto_pass, coach_next_step, or escalate_teacher_review.

## gold_eval_suite_v2

- **gold_case_id** — Stable evaluation case identifier.
- **source_record_id** — Reference to a core record used as the source pattern.
- **adjudicated_*** — Adjudicated labels meant to act like human-reviewed benchmark tags.
- **adjudication_rationale** — Short synthetic rationale describing why the labels/scores were assigned.

## fairness_counterfactual_suite_v2

- **fairness_pair_id** — Pair identifier linking base and counterfactual records.
- **counterfactual_target** — What surface property was changed.
- **max_allowed_score_delta** — Expected score drift tolerance; keep within this band.

## privacy_safety_suite_v2

- **scenario_type** — Policy/safety scenario category.
- **expected_flag** — Which risk dimension should trigger.
- **expected_policy_action** — allow_with_redaction, warn_and_coach, block_and_explain, or escalate_teacher_review.

## schema_edgecase_suite_v2

- **payload** — Nested record payload intentionally containing a validation issue.
- **expected_validator_result** — fail or warn.
- **expected_error_codes** — Machine-readable expected validation errors.
- **expected_warning_codes** — Machine-readable expected validation warnings.

## load_test_requests_v2

- **request_profile** — Traffic profile such as baseline, long_context, ai_heavy, or integrity_edge.
- **payload** — Flattened request payload for inference/load testing.
