# 34_GOOGLE_CLASSROOM_PROVIDER_APIS.md
Google Classroom APIs Scholesa will call (Add-on + Roster + Grades)

This file is a **provider mapping**: external Google APIs Scholesa uses and the internal wrapper responsibilities.

Service endpoint: `classroom.googleapis.com` citeturn0search8

---

## 1) Add-on attachment APIs (core to Option 2)
### Create attachments
- `courses.courseWork.addOnAttachments.create`
- `courses.announcements.addOnAttachments.create`
- `courses.courseWorkMaterials.addOnAttachments.create`
Creates an AddOnAttachment under a post. citeturn0search7turn0search0turn0search8

### Manage attachment submissions / grading
- `courses.courseWork.addOnAttachments.studentSubmissions.*`
Used to fetch/alter grade back to Classroom for an add-on attachment; grade set via `pointsEarned`. citeturn0search3turn0search8

---

## 2) Classroom roster + course APIs (supports your physical school operations)
- `courses.list`, `courses.get` (course discovery) citeturn0search12turn0search8
- `courses.students.list` (roster import) citeturn0search8
- `courses.teachers.list` (verify teacher role when linking)

Scholesa uses these to map:
Classroom `courseId` → Scholesa `siteId` + `sessionId`
Classroom student list → Scholesa user + Enrollment (no parent auto-link)

---

## 3) Grades (non add-on CourseWork)
If you use standard CourseWork items as well:
- Set/update grades: `courses.courseWork.studentSubmissions.patch` (draftGrade / assignedGrade). citeturn0search1turn0search13
- Return submissions: `courses.courseWork.studentSubmissions.return` (note: return does not automatically copy draftGrade → assignedGrade). citeturn0search5

---

## 4) Provider wrapper requirements (Scholesa)
Your Dart API must implement:
- OAuth token acquisition + refresh, securely stored (see docs/30)
- retry + backoff for 429/5xx
- idempotency on create attachment operations
- audit log for every external write (create attachment, post grade, return)

---

## 5) Critical implementation constraint
Classroom writes that modify CourseWork/submissions must be made with the same Developer Console project OAuth client that created the work item (important when you manage multiple environments). citeturn0search4turn0search5

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `34_GOOGLE_CLASSROOM_PROVIDER_APIS.md`
<!-- TELEMETRY_WIRING:END -->
