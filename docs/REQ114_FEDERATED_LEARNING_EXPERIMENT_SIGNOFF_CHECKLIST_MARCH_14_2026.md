# REQ-114 Federated Learning Experiment Sign-off Checklist

Date: 2026-03-14
Status: Draft

Complete this checklist before any REQ-114 prototype moves from paper design into a real pilot.

## Preconditions

- [ ] `docs/REQ114_FEDERATED_LEARNING_RD_ARCHITECTURE_BRIEF_MARCH_14_2026.md` approved.
- [ ] `docs/REQ114_FEDERATED_LEARNING_PRIVACY_REVIEW_FORM_MARCH_14_2026.md` completed and approved.
- [ ] Security review completed.
- [ ] Approved pilot sites listed.
- [ ] Remote disable and rollback path tested.

## Device and runtime gates

- [ ] Runtime target explicitly limited to approved platforms.
- [ ] Feature flag or experiment switch exists.
- [ ] Background execution limits documented.
- [ ] Battery and network budgets documented.
- [ ] Offline behavior documented.

## Data and storage gates

- [ ] Raw update payload schema approved.
- [ ] No raw prompts, transcripts, or free-text artifacts are uploaded.
- [ ] Aggregate threshold documented.
- [ ] Raw update retention period documented.
- [ ] Aggregate retention period documented.
- [ ] Deletion procedure documented.

## Security and privacy gates

- [ ] Signed experiment configuration used.
- [ ] Site isolation enforced by default.
- [ ] Access to raw experiment data restricted to approved roles.
- [ ] Audit logs enabled for experiment enrollment and config changes.
- [ ] Incident response path documented.

## Pilot success gates

- [ ] Success metrics defined before rollout.
- [ ] Harm metrics defined before rollout.
- [ ] Rollback trigger thresholds defined.
- [ ] Pilot limited to approved sites and cohort size.
- [ ] Post-pilot review owner assigned.

## Final sign-off

- Product approval:
- Privacy/compliance approval:
- Security approval:
- Data/ML approval:
- Release approval:
- Go / Hold:
- Date:

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: no
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `REQ114_FEDERATED_LEARNING_EXPERIMENT_SIGNOFF_CHECKLIST_MARCH_14_2026.md`
<!-- TELEMETRY_WIRING:END -->