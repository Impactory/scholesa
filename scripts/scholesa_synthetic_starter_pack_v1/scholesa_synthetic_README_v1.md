# Scholesa Synthetic Starter Pack v1

This pack contains **2,640 synthetic records** aligned to the Scholesa routines we discussed:
- retrieval and explain-it-back
- checkpoint evidence and proof-of-work
- reflection and next-step notes
- AI-use disclosures
- model limitations, fairness notes, and experiment design
- portfolio-like artifact summaries

## Files
- `scholesa_synthetic_bootstrap_v1.jsonl` — 2,400 bootstrap rows for training warm-starts
- `scholesa_synthetic_bootstrap_v1.csv` — CSV version of the same
- `scholesa_synthetic_challenge_v1.jsonl` — 240 challenge rows for regression and integrity tests
- `scholesa_synthetic_challenge_v1.csv` — CSV version of the same
- `scholesa_synthetic_all_v1.csv` — combined dataset
- `scholesa_synthetic_bundle_v1.xlsx` — workbook with records, schema, and summary sheets

## Design rules used
1. Rows preserve source provenance (`data_source`, `synthetic_method`, `source_weight`).
2. Bootstrap rows are marked `eligible_for_training=true` and `eligible_for_eval=false`.
3. Challenge rows are marked `eligible_for_training=false` and `eligible_for_eval=true`.
4. AI fields are blank whenever `ai_used=false`.
5. Grades 1-3 only use `teacher_led` AI mode when AI appears.
6. Challenge patterns cover polished-but-thin work, high-confidence wrong reasoning, weak proof-of-work, fairness blind spots, and responsible AI use.

## Suggested use
- Start model warm-up with the bootstrap set.
- Keep the challenge set out of normal training.
- As real data arrives, down-weight synthetic rows first in common task families like reflection, checkpoint evidence, and AI disclosure.
- Keep a small challenge set for regression even after real data dominates.

## Quick counts
- Total rows: 2,640
- Bootstrap rows: 2,400
- Challenge rows: 240
- AI-used rows: 445
- High integrity-risk rows: 252

## Caution
This pack is synthetic by design. Do not use it to claim product quality or learner outcomes. Use it for schema testing, cold-start model behavior, edge-case coverage, and regression.
