# REQ-031 Invariant Enforcement Proof

Date: 2026-03-13

Requirement: REQ-031 Invariant enforcement

Files reviewed and validated:
- `invariants.ts`
- `src/__tests__/invariants.test.ts`

Local proof:
- `npm test -- --runInBand --runTestsByPath src/__tests__/invariants.test.ts`

Verified behavior:
- Existing session, mission, site, user, program, and course references resolve cleanly.
- Missing references throw deterministic invariant-violation errors.
- User role enforcement rejects mismatched roles.
- Program/course hierarchy enforcement rejects mismatched ownership.

Status:
- REQ-031 can be marked complete.