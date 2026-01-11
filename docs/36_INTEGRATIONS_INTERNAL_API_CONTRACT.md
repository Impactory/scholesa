# 36_INTEGRATIONS_INTERNAL_API_CONTRACT.md
Internal APIs to build (Dart API on Cloud Run)
Google Classroom Add-on + GitHub integration

These are **your platform endpoints** (not Google/GitHub endpoints).
All endpoints:
- require Firebase Auth JWT
- enforce role-based access and site scoping
- write AuditLog for privileged operations
- return stable error codes and machine-readable error bodies

---

## A) Google Classroom (Add-on + roster + grades)

### 1) OAuth connect
`POST /api/integrations/google/classroom/auth-url`
- body: { returnUrl }
- returns: { url }

`GET /api/integrations/google/classroom/callback`
- query: code, state
- result: stores tokenRef, creates IntegrationConnection, redirects to returnUrl

### 2) Add-on iframe bootstrap
`GET /api/integrations/google/classroom/addon/context`
- query: courseId, itemId, itemType, attachmentId?, addOnToken
- returns: { userRoleInCourse, siteCandidates, sessionCandidates, attachmentMeta }

(Used by iframe pages to render correctly.)

### 3) Create add-on attachment (Phase 1)
`POST /api/integrations/google/classroom/addon/attachments:create`
- body: { courseId, itemId, itemType, missionId, title, description, dueDate?, maxPoints?, githubTask? }
- does:
  - validates teacher role
  - creates attachment in Classroom
  - creates ExternalCourseworkLink
- returns: { attachmentId, providerCourseWorkId?, deepLink }

Idempotency:
- header `Idempotency-Key`

### 4) Roster sync
`POST /api/integrations/google/classroom/courses/{courseId}/sync-roster`
- body: { siteId, sessionId }
- does:
  - list students
  - map to Scholesa users
  - upsert Enrollments
  - pause missing
- returns: { added, updated, paused, unmatched }

### 5) Pull submission state (Phase 2)
`POST /api/integrations/google/classroom/addon/attachments/{attachmentId}/submissions:pull`
- body: { courseId, itemId }
- returns: { statesByStudent }

### 6) Push grade/comment summary (Phase 2)
`POST /api/integrations/google/classroom/addon/attachments/{attachmentId}/grade:push`
- body: { courseId, itemId, learnerId, pointsEarned, maxPoints?, privateComment?, returnToStudent?: boolean }
- returns: { ok: true }

Also support non-add-on CourseWork grade patch/return if you still publish CourseWork items:
- (optional) `/api/integrations/google/classroom/coursework/{courseWorkId}/grade:push`
- (optional) `/api/integrations/google/classroom/submissions/{submissionId}/return`

---

## B) GitHub (tasks inside missions)

### 1) GitHub connect (OAuth or App install handshake)
`POST /api/integrations/github/auth-url`
- returns GitHub OAuth URL (if using OAuth flow)

`GET /api/integrations/github/callback`
- stores tokenRef, creates GitHubConnection

If using GitHub App:
- `GET /api/integrations/github/app/install-callback` (installationId, setup_action)
- store installationId and org/account link

### 2) Link GitHub assignment (link-based)
`POST /api/integrations/github/link-assignment`
- body: { missionId, githubClassroomAssignmentUrl }
- returns: { ok: true }

### 3) Provision repo from template (advanced)
`POST /api/integrations/github/repos:provision`
- body: { siteId, learnerId, templateOwner, templateRepo, newRepoName, private: boolean }
- returns: { repoFullName, repoUrl }

### 4) Create issues / checklist
`POST /api/integrations/github/repos/{owner}/{repo}/issues:create`
- body: { title, body, labels? }
- returns: { issueUrl }

### 5) Webhooks
`POST /api/integrations/github/webhooks`
- handles GitHub webhook deliveries (signature verified)
- updates telemetry + optional “progress signals” for attempts/portfolios

---

## Error and audit contracts
Return shape for errors:
{ code, message, correlationId, details? }

AuditLog actions (examples):
- google.classroom.connect
- google.classroom.attachment.create
- google.classroom.roster.sync
- google.classroom.grade.push
- github.connect
- github.repo.provision
- github.webhook.received
