# Export & Delete Runbook

## Export request
Input: learnerId + siteId
Outputs:
- JSON/CSV export of learning records
- Artifact links (time-limited)
- AI interaction log excerpt (if policy allows)

## Delete request
Steps:
- Verify requester authority
- Execute deletion jobs
- Verify Firestore docs removed
- Verify storage objects removed
- Record completion evidence
