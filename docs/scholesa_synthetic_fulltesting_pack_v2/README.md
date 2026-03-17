# Scholesa Synthetic Full Testing Pack v2

This pack extends the starter set with **normalized tables, benchmark suites, policy/safety cases, schema validation cases, longitudinal sequences, and high-volume load-test traffic**.

## What is included

### Core normalized data
- **48 cohorts**
- **2,880 learners**
- **384 sessions**
- **14,400 core evidence bundles**
- **13,165 artifact/proof-of-work rows**
- **2,365 AI trace rows**
- **14,400 teacher observation rows**
- **10,344 peer feedback rows**
- **14,400 expected BOS/MIA target rows**
- **91,245 raw event-log rows**

### Evaluation and stress-test suites
- **1,280 gold evaluation cases**
- **1,536 fairness counterfactual rows** (768 pairs)
- **1,536 integrity adversarial cases**
- **768 privacy/safety cases**
- **512 schema edge cases**
- **3,072 longitudinal trajectory rows**
- **40,000 load-test requests**
- **388 dashboard aggregate rows**

## Design goals
1. Preserve source provenance and keep synthetic-only rows clearly labeled.
2. Cover typical classroom evidence, AI-use traces, proof-of-work, and teacher feedback.
3. Provide dedicated files for fairness, integrity, privacy/safety, and schema validation.
4. Keep **training-eligible** and **evaluation-only** suites separated.
5. Make BOS/MIA testing easier with explicit expected score targets and actions.

## Suggested usage
- Use `normalized/core_evidence_records_v2.*` for ingestion, feature extraction, and warm-start experiments.
- Use `normalized/expected_model_outputs_v2.csv` for supervised target testing.
- Use `suites/gold_eval_suite_v2.jsonl` as the first benchmark.
- Use `suites/fairness_counterfactual_suite_v2.jsonl` and `suites/integrity_adversarial_suite_v2.jsonl` for regression.
- Use `suites/privacy_safety_suite_v2.jsonl` and `suites/schema_edgecase_suite_v2.jsonl` for policy + pipeline testing.
- Use `suites/load_test_requests_v2.jsonl` to simulate API/load traffic.
- Use `schema/qc_report_v2.json` and `docs/file_manifest_v2.*` to verify completeness.

## Caution
This pack is synthetic. It is for schema testing, model warm-starts, evaluation design, regression, moderation, and performance testing. It should **not** be used to claim learner outcomes or product quality.

## Seed and integrity notes
- Seed: `20260313`
- Grades 1–3 only use `none` or `teacher_led` AI modes in core/trajectory files.
- AI fields are blank when `ai_used=false` in core data.
- Schema edgecase rows intentionally violate one or more rules and should be treated as validation fixtures.
