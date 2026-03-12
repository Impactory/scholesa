# RC3 Production Canary Checklist (Historical, Superseded)

**Date**: March 8, 2026  
**Project**: `studio-3328096157-e3f79`  
**Purpose**: Historical manual live canary pass for launch-critical workflows after deploy or before GO/NO-GO.

> Superseded on March 12, 2026 by `RC3_BIG_BANG_CUTOVER_CHECKLIST_MARCH_12_2026.md`.
> Do not use this document as the current production release-control artifact.
> This historical checklist predates the final big-bang release policy and must not be used as evidence for current learner AI guardrail compliance or release readiness.

Use the exact role accounts and route sequence in `RC3_OPERATOR_CANARY_SCRIPT_MARCH_8_2026.md` only when reviewing the historical March 8 canary evidence. Use `RC3_BIG_BANG_OPERATOR_SCRIPT_MARCH_12_2026.md` for the current release policy.

---

## Operator Rules

- Use live accounts only.
- Record start time, operator, and result for each role.
- Treat any failed primary CTA, redirect loop, or persistence failure as a release blocker.
- If any role fails, stop rollout and run the release gate in `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md`.
- Follow `RC3_OPERATOR_CANARY_SCRIPT_MARCH_8_2026.md` for the exact role order, accounts, routes, and evidence to capture.

---

## Canary Metadata

| Field | Value |
|---|---|
| Operator | ____________________ |
| Environment | Production |
| Pre-Canary Auth Check | Verified March 8, 2026 for all 6 role accounts with `Test123!` |
| Start Time | ____________________ |
| End Time | ____________________ |
| Result | GO / NO-GO |

---

## 1. Learner Canary

Account: `learner@scholesa.test`

- [ ] Log in successfully
- [ ] Land on learner default route
- [ ] Open missions successfully
- [ ] Create a mission attempt
- [ ] Submit the mission attempt
- [ ] Confirm the submitted state remains visible after refresh

Pass evidence:
- Route resolves to learner area
- Primary learner CTA persists after page refresh

---

## 2. Educator Canary

Account: `teacher01.demo@scholesa.org`

- [ ] Log in successfully
- [ ] Land on educator default route
- [ ] Open attendance workflow
- [ ] Record attendance for a linked learner
- [ ] Confirm attendance entry remains visible after refresh
- [ ] Confirm partner routes are denied

Pass evidence:
- Attendance write persists
- Access control still redirects out of partner-only routes

---

## 3. Parent Canary

Account: `parent001.demo@scholesa.org`

- [ ] Log in successfully
- [ ] Land on parent summary route
- [ ] Open portfolio view
- [ ] Confirm linked learner artifacts appear
- [ ] Confirm unrelated learner artifacts do not appear
- [ ] Confirm site routes are denied

Pass evidence:
- Parent sees only linked learner data
- No cross-learner artifact leakage

---

## 4. Site Canary

Account: `site001.demo@scholesa.org`

- [ ] Log in successfully
- [ ] Land on site dashboard route
- [ ] Open provisioning workflow
- [ ] Create or link a guardian relationship
- [ ] Confirm guardian relationship remains visible after refresh
- [ ] Confirm partner routes are denied

Pass evidence:
- Provisioning write persists
- Site isolation holds

---

## 5. Partner Canary

Account: `partner@scholesa.dev`

- [ ] Log in successfully
- [ ] Land on partner listings route
- [ ] Create a listing draft
- [ ] Publish the listing
- [ ] Confirm published status remains visible after refresh
- [ ] Confirm site routes are denied

Pass evidence:
- Listing status transitions to published and persists
- Partner routing stays isolated

---

## 6. HQ Canary

Account: `hq@scholesa.test`

- [ ] Log in successfully
- [ ] Land on HQ sites route
- [ ] Create a new site record
- [ ] Activate the site
- [ ] Confirm the site remains active after refresh
- [ ] Confirm unauthenticated direct HQ access redirects to login in a separate clean session

Pass evidence:
- HQ write persists
- HQ routes remain protected from anonymous access

---

## 7. Final Decision

- [ ] Pre-canary auth check still matches the documented six-account set
- [ ] All six role canaries passed
- [ ] No unexpected permission errors observed
- [ ] No redirect loops observed
- [ ] No broken primary CTA observed
- [ ] No persistence failure observed after refresh

**GO / NO-GO**: ____________________

**Notes**:

________________________________________________________________________________
________________________________________________________________________________
________________________________________________________________________________

---

## 8. Operator GO / NO-GO Summary

| Field | Value |
|---|---|
| Operator | ____________________ |
| Decision Time | ____________________ |
| Final Decision | GO / NO-GO |
| Evidence Reviewed | Live auth precheck / Manual browser canary / RC3 gate docs |
| Blocking Issue IDs | None / ____________________ |
| Rollback Needed | No / Yes |

Release decision summary:

________________________________________________________________________________
________________________________________________________________________________
________________________________________________________________________________
