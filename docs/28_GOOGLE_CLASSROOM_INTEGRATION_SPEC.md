# 28_GOOGLE_CLASSROOM_INTEGRATION_SPEC.md
Scholesa ↔ Google Classroom integration (Phase 1 + Phase 2)

This integration keeps Scholesa as the **in-person operating system** (attendance, missions, evidence, reflection, teacher review, interventions, pillar coaching),
while Google Classroom remains the familiar **distribution layer** (course hub + assignment surface).

**Phase 1 (Roster + Publish Links):**
- Connect teacher’s Google account
- Link Google Classroom Course → Scholesa Session/Site
- Import roster → create/update Enrollments
- Publish Scholesa Mission links into Classroom as CourseWork

**Phase 2 (Status + Grade/Feedback pushback):**
- Read Classroom submission state (NEW/CREATED/TURNED_IN/RETURNED)
- Post Scholesa review summary back to Classroom (grade and/or private comment) as appropriate

Reference: Classroom API concepts + resources, grades, and StudentSubmission lifecycle. See Google’s guides and REST resources.

---

## 1) Stakeholder experience

### Educator
1. “Connect Google Classroom” in Scholesa (one-time)
2. Select Courses to link
3. For each Course:
   - map to Scholesa `siteId` + `sessionId`
   - choose roster sync behavior (daily/weekly/manual)
4. In Scholesa, build or choose a Mission (pillar-coded)
5. “Publish to Classroom” creates a Classroom CourseWork item containing:
   - title + short description
   - deep link to Scholesa mission attempt page (PWA/web-first)
6. Students click from Classroom → complete in Scholesa
7. Educator reviews in Scholesa → optionally “Sync summary to Classroom” (Phase 2)

### Learner
- Learner can start from Classroom or Scholesa.
- Classroom item links to Scholesa where evidence + reflection happen.
- Learner sees “Submitted in Scholesa” and (optional) Classroom grade/return state.

### Parent
- No change to Scholesa parent boundaries.
- Parents never see teacher-only intelligence.
- Guardian links remain admin-only in Scholesa.

### Admin/HQ
- Optional domain-level configuration and consent screen governance.
- Auditability of who linked what.

---

## 2) Integration modes
We support both; default is Mode A.

### Mode A (Recommended): “Scholesa is the source of truth”
- Learners submit in Scholesa
- Scholesa writes back a *summary* to Classroom (Phase 2):
  - grade + private comment (optional)
  - link to portfolio/evidence

### Mode B (Optional later): “Mirror Classroom submissions into Scholesa”
- Scholesa ingests Classroom studentSubmissions and attachments
- Higher complexity (Drive permissions, formats, edge cases)

---

## 3) Data flows (Phase 1 + 2)

### Phase 1: Connect → Link course → Sync roster → Publish coursework
**Connect**
- OAuth in API
- store tokens securely

**Link Course**
- create `ExternalCourseLink`
- set the linked `siteId` + `sessionId`

**Sync roster**
- list course students and map to Scholesa users
- create/update Enrollment records
- never create parent GuardianLink automatically

**Publish coursework**
- create Classroom CourseWork item with Scholesa deep link
- create `ExternalCourseworkLink` tying CourseWorkId ↔ mission/plan

### Phase 2: Pull states → Push grade/comment
**Pull submission state**
- teacher account lists studentSubmissions (or per student)
- reconcile state into Scholesa “external submission state” (read-only)

**Push grade/comment**
- set grade / return state using Classroom API grade guide and StudentSubmission methods where permitted
- ALWAYS keep detailed pillar coaching inside Scholesa; only push summaries to Classroom.

---

## 4) Permissions and scopes (principles)
- Request **least privilege** per role.
- Select only needed scopes.

Minimum suggested scope strategy:
- Teacher linking + roster import: read access to courses + rosters
- Publishing coursework: scope that permits creating courseWork
- Phase 2 grade sync: scope that permits reading/updating StudentSubmissions and grades

(Exact scopes are finalized in docs/30.)

---

## 5) Operational roll-out checklist (for use)
1. Create Google Cloud project for “Scholesa Classroom Integration”
2. Configure OAuth consent screen
3. Add authorized redirect URIs for Cloud Run API
4. Decide:
   - teacher-by-teacher connect (fast) vs domain-managed deployment (scalable)
5. Train:
   - “Connect + Link Course” 5-minute guide
   - “Publish weekly mission” workflow
   - “Sync review summary” workflow (Phase 2)
6. Run pilot with 1–2 sites, then expand

---

## 6) Non-negotiables
- Scholesa design language remains unchanged by integration work.
- Parents remain restricted (no teacher intelligence access).
- Admin-only provisioning stays intact.
- API owns OAuth tokens and privileged writes.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `28_GOOGLE_CLASSROOM_INTEGRATION_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
