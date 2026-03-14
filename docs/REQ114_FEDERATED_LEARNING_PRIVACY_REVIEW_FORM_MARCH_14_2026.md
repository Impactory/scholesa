# REQ-114 Federated Learning Privacy Review Form

Date: 2026-03-14
Status: Draft

Use this form before approving any prototype or pilot tied to REQ-114.

## Review metadata

- Reviewer name:
- Reviewer role:
- Review date:
- Experiment owner:
- Proposed runtime target: Flutter mobile / web PWA / hybrid
- Proposed pilot sites:
- Reference architecture doc:

## 1) Data inventory

- Describe every field in the client update payload:
- Are any direct identifiers present: yes/no
- Are any indirect identifiers or unique combinations present: yes/no
- Are raw prompts, transcripts, reflections, or artifact bodies present: yes/no
- Are free-text fields present anywhere in the upload path: yes/no

## 2) Consent and legal posture

- Which consent basis is being used:
- Are school-consent records sufficient for this experiment: yes/no
- Is parent notice additionally required: yes/no
- Is the cohort limited to explicitly approved sites: yes/no
- Is opt-out or disable behavior documented: yes/no

## 3) Storage and retention

- Where are raw client updates stored:
- Retention period for raw updates:
- Retention period for aggregated outputs:
- Deletion path documented: yes/no
- Rollback and disable path documented: yes/no

## 4) Access control

- Roles allowed to configure the experiment:
- Roles allowed to inspect raw update metrics:
- Roles allowed to view aggregate results:
- Are educator and parent surfaces excluded from raw experiment data: yes/no

## 5) Re-identification and leakage review

- Risk of update inversion assessed: yes/no
- Risk of membership inference assessed: yes/no
- Cross-site contamination risk assessed: yes/no
- Malicious or poisoned client update handling assessed: yes/no
- Aggregate threshold documented: yes/no

## 6) Device impact

- Battery budget documented: yes/no
- Network budget documented: yes/no
- Metered-network behavior documented: yes/no
- Low-battery behavior documented: yes/no
- Offline behavior documented: yes/no

## 7) Decision

- Result: APPROVED / HOLD / REJECTED
- Required follow-ups:
- Notes:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ114_FEDERATED_LEARNING_PRIVACY_REVIEW_FORM_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->