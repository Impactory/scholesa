# RC3 Operator Canary Script

**Date**: March 8, 2026  
**Project**: `studio-3328096157-e3f79`  
**Purpose**: One-page operator script for the live manual canary run.

---

## Use This With

- `RC3_PRODUCTION_CANARY_CHECKLIST_MARCH_8_2026.md`
- `RC3_RELEASE_GATE_STANDARD_MARCH_8_2026.md`
- `RC3_LIVE_E2E_SIGNOFF_MARCH_8_2026.md`

---

## Operator Rules

- Run in a clean browser profile or incognito window for each role.
- Use production only.
- Record the exact time, outcome, and any deviation.
- Do not continue to the next role if a role fails its primary CTA or shows incorrect scope.

---

## Live Canary Accounts

| Role | Email | UID | Site Context | Default Route |
|---|---|---|---|---|
| Learner | `learner@scholesa.test` | `FD3V35hureMivVtjxQ7fZNsQvnI3` | `site-1`, `site_001` | `/en/learner/today` |
| Educator | `teacher01.demo@scholesa.org` | `U-TEACH-001` | `SCH-DEMO-001` | `/en/educator/today` |
| Parent | `parent001.demo@scholesa.org` | `U-PAR-001` | `SCH-DEMO-001` | `/en/parent/summary` |
| Site | `site001.demo@scholesa.org` | `U-SITE-001` | `SCH-DEMO-001` | `/en/site/dashboard` |
| Partner | `partner@scholesa.dev` | `test-partner-001` | `site-1` | `/en/partner/listings` |
| HQ | `hq@scholesa.test` | `3hGfzDVbhyc5mDCgbLEPhZtDxCH2` | `site-1`, `site_001` / HQ | `/en/hq/sites` |

**Credential note**:
- The current live operator password verified for this canary set is `Test123!`.
- If any account stops authenticating with that password, treat it as a release-blocking credential drift and rerun the live identity audit before proceeding.

---

## Step Order

Run roles in this order:

1. Learner
2. Educator
3. Parent
4. Site
5. Partner
6. HQ

This order minimizes cross-role contamination and ends with the highest-privilege surface.

---

## 1. Learner Script

Account: `learner@scholesa.test`

Steps:
1. Log in.
2. Confirm redirect to `/en/learner/today`.
3. Open Missions.
4. Create a mission attempt.
5. Submit the mission attempt.
6. Refresh the page.
7. Confirm the attempt remains submitted.

Expected outcome:
- learner lands on learner route only
- learner CTA persists after refresh
- no access to HQ route

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## 2. Educator Script

Account: `teacher01.demo@scholesa.org`

Steps:
1. Log in.
2. Confirm redirect to `/en/educator/today`.
3. Open Attendance.
4. Record attendance for a linked learner.
5. Refresh the page.
6. Confirm the attendance entry persists.
7. Attempt `/en/partner/listings` directly.

Expected outcome:
- educator lands on educator route only
- attendance write persists after refresh
- partner route access is denied or redirected

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## 3. Parent Script

Account: `parent001.demo@scholesa.org`

Steps:
1. Log in.
2. Confirm redirect to `/en/parent/summary`.
3. Open Portfolio.
4. Confirm linked learner artifacts are visible.
5. Confirm unrelated learner artifacts are not visible.
6. Attempt `/en/site/dashboard` directly.

Expected outcome:
- parent sees only linked learner data
- no unrelated learner data appears
- site route access is denied or redirected

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## 4. Site Script

Account: `site001.demo@scholesa.org`

Steps:
1. Log in.
2. Confirm redirect to `/en/site/dashboard`.
3. Open Provisioning.
4. Create or link a guardian relationship.
5. Refresh the page.
6. Confirm the guardian relationship persists.
7. Attempt `/en/partner/listings` directly.

Expected outcome:
- site admin lands on site route only
- provisioning write persists after refresh
- partner route access is denied or redirected

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## 5. Partner Script

Account: `partner@scholesa.dev`

Steps:
1. Log in.
2. Confirm redirect to `/en/partner/listings`.
3. Create a listing draft.
4. Publish the listing.
5. Refresh the page.
6. Confirm published status persists.
7. Attempt `/en/site/dashboard` directly.

Expected outcome:
- partner lands on partner route only
- listing status persists as published
- site route access is denied or redirected

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## 6. HQ Script

Account: `hq@scholesa.test`

Steps:
1. Log in.
2. Confirm redirect to `/en/hq/sites`.
3. Create a new site record.
4. Activate the site.
5. Refresh the page.
6. Confirm active status persists.
7. In a separate clean session, open `/en/hq/sites` without logging in.

Expected outcome:
- HQ lands on HQ route only
- site activation persists after refresh
- anonymous direct HQ access redirects to login

Operator evidence:
- Result: ____________________
- Notes: ____________________

---

## Final Operator Signoff

| Field | Value |
|---|---|
| Operator | ____________________ |
| Start Time | ____________________ |
| End Time | ____________________ |
| GO / NO-GO | ____________________ |

Release may only proceed if all six roles pass and `RC3_PRODUCTION_CANARY_CHECKLIST_MARCH_8_2026.md` is fully completed.
