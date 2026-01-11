# 33_CLASSROOM_ADDON_PRODUCT_SPEC.md
Scholesa “Works with Google Classroom” Add-on (Option 2)

Goal: Scholesa becomes a **Google Classroom Add-on** so teachers can select Scholesa directly from the Classroom UI when creating an assignment, attach Scholesa missions, and (Phase 2) grade/return from within the same workflow.

**Non‑negotiable:** keep Scholesa’s current design language intact. No design-system changes, no reskin.

Google Classroom add-ons open third-party content in iframes and support teacher + student flows, plus mobile-specific expectations. citeturn2search14turn2search11turn2search7

---

## 1) What teachers experience (inside Classroom)
### Attachment Discovery (Teacher)
- In Classroom assignment creation, teacher clicks “Add-ons” → selects “Scholesa”.
- Classroom loads Scholesa’s **Attachment Discovery iframe** launch URL and passes query parameters (courseId, itemId, itemType, addOnToken, login_hint, etc.). citeturn2search10turn2search2
- Scholesa shows:
  - choose Mission / Mission Pack / Session Occurrence
  - optional “Include GitHub task” toggle
  - optional grading mode toggle (Phase 2)
- When teacher confirms, Scholesa calls the Classroom add-ons API to **create an AddOnAttachment** on that post. citeturn0search0turn0search7

### Teacher View (attached item management)
- Teacher can reopen the attachment to:
  - adjust mission selection
  - adjust points/maxPoints handling
  - view aggregate status
- Scholesa can fetch attachment context and manage scoring for the add-on attachment. citeturn0search3

---

## 2) What students experience (inside Classroom)
### Student View iframe
- Students open assignment → attachment renders Scholesa content in the Student View iframe.
- Students complete mission steps (evidence + reflection) inside Scholesa.
- If “Complete outside of Classroom” is required on mobile or unsupported devices, Scholesa must deep link out or open a mobile page externally per Google’s mobile journey expectations. citeturn2search11turn2search7

---

## 3) “GitHub inside Scholesa Add-on” (behavior)
Within the attachment UI, Scholesa can show one of two GitHub behaviors:

### A) Link-based (recommended for schools)
- Teacher pastes/chooses an existing GitHub Classroom assignment link (or repo link).
- Students click it (opens GitHub) but Scholesa remains the evidence + reflection + review system.
- Lowest risk, easiest to deploy.

### B) Managed provisioning (advanced)
- Teacher selects a Scholesa “GitHub template task”
- Scholesa provisions a repo (template → student repo) and manages issues/PR checks via GitHub API
- Requires a GitHub App + org install (preferred) and/or GitHub OAuth for user-to-server actions in some cases.

(See docs/35 and /37.)

---

## 4) Required web routes (your app)
Classroom add-ons require specific pages you host:

### Iframe entrypoints
- `/classroom/iframe/discovery` (Attachment Discovery)
- `/classroom/iframe/teacher` (Teacher View)
- `/classroom/iframe/student` (Student View)

### OAuth callback / session setup
- `/classroom/oauth/callback` (server callback)
- optional: `/classroom/iframe/callback` pages if needed by your framework

Google’s walkthroughs and iframe docs show the query params that must be captured on first load and persisted across the session. citeturn2search3turn2search2

---

## 5) Installation and admin requirements
- Publish and install via Google Workspace Marketplace listing for the add-on. citeturn2search12turn2search0
- District admins can allowlist/install add-ons for domains/OUs/groups; admin install is the recommended option for complete functionality. citeturn2search4turn2search8

---

## 6) Phase 1 + Phase 2 mapping
### Phase 1 (Add-on)
- discovery iframe → create attachment
- optional roster sync from Classroom (outside add-on; educator connects once)

### Phase 2 (Add-on grading)
- fetch and update add-on attachment student submissions grades via addOnAttachments studentSubmissions endpoints (pointsEarned) where applicable. citeturn0search3turn0search8
- for non-add-on CourseWork grading, use StudentSubmission patch/return flows. citeturn0search1turn0search5
