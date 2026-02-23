# Runbook: No Student Data Training

## Policy
- Student interaction data is analytics-only.
- No model training or fine-tuning pipeline can consume student requests/responses.

## Detection Artifact
- `audit-pack/reports/student-data-training-ban.json`

## Triage
1. Open report and review `findings`.
2. Remove any runtime references to:
   - `exportForTraining`
   - `training dataset`
   - `model training`
   - `fine-tune`
3. Ensure `src/lib/ai/interactionLogger.ts` retains `analytics_only_no_training` marker.

## Verification
- Run: `npm run compliance:gate`
- Confirm:
  - `student-data-training-ban.json` has `"passed": true`
  - `compliance-latest.json` has no `student_data_training_ban` failures
