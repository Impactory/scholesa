# 38_QA_SCRIPT_CLASSROOM_ADDON_GITHUB.md
QA script — Classroom Add-on + GitHub integration

This QA script validates:
- Classroom add-on attachment flows (teacher + student)
- Phase 2 grade sync
- GitHub link-based task flow
- GitHub webhook ingestion (optional advanced)

## UAT status snapshot (2026-02-20)

- Core stack is currently green and deployed live.
- Add-on + GitHub UAT remains **manual acceptance scope** and has not been fully rerun as part of the latest core live-only regression pass.
- Keep this script as the go/no-go checklist before enabling add-on + GitHub flows for all production sites.

---

## Test setup
Accounts:
- Google Classroom teacher account (licensed for add-ons if required)
- Google Classroom student account
- Scholesa site admin (provisioning)
- GitHub org + test repos (or GitHub Classroom assignment link)

Admin prerequisites:
- Add-on installed/allowlisted in domain or test tenant. citeturn2search4turn2search12

---

## A) Classroom Add-on (Phase 1)
### 1) Discovery iframe loads
- Teacher creates assignment → selects Scholesa add-on
Expected:
- discovery iframe loads and renders mission picker
- query params are captured once and persisted for the session. citeturn2search10turn2search2

### 2) Attachment created
- Teacher selects mission → Attach
Expected:
- AddOnAttachment created under the post. citeturn0search7turn0search0
- ExternalCourseworkLink created in Firestore
- AuditLog written

---

## B) Student view + completion
### 3) Student view iframe
- Student opens assignment
Expected:
- student iframe loads Scholesa mission
- mobile: deep link/out-of-classroom behavior matches Google’s mobile journey expectations. citeturn2search7turn2search11

### 4) Submit in Scholesa
Expected:
- MissionAttempt submitted + evidence saved
- no parent access to teacher-only insights

---

## C) Phase 2 grading
### 5) Teacher grades in Scholesa and syncs
Expected:
- grade written back to Classroom via attachment submissions grade fields (pointsEarned). citeturn0search3turn0search8
- idempotent: repeated sync does not duplicate or corrupt

---

## D) GitHub link-based
### 6) Teacher includes GitHub assignment link
- attach link as a mission step
Expected:
- students can access link
- Scholesa still collects evidence/reflection

---

## E) GitHub webhooks (advanced)
### 7) Webhook delivery
- trigger push/PR
Expected:
- webhook received and verified
- telemetry event created
- optional student nudge generated

---

## Regression: design language lock
Visually confirm:
- no typography/color/component changes introduced by add-on pages
- add-on pages use the same design tokens as the core app
