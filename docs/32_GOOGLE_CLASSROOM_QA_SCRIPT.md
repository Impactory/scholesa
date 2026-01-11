# 32_GOOGLE_CLASSROOM_QA_SCRIPT.md
QA script for Classroom integration (Phase 1 + 2)

## Test accounts
- Teacher account (Classroom teacher)
- Student account (Classroom student)
- Scholesa site admin account
- Scholesa parent account (linked through admin)

---

## Phase 1 — Connect, link, roster, publish

### 1) Connect
1. Teacher clicks “Connect Google Classroom”
2. OAuth consent completes
3. Scholesa shows status “Connected” and list of available courses
Expected:
- IntegrationConnection created (API)
- AuditLog entry written

### 2) Link course to session
1. Teacher selects course
2. Maps to siteId + sessionId
Expected:
- ExternalCourseLink created
- UI shows mapping

### 3) Roster import
1. Trigger manual roster sync
Expected:
- Enrollments created/updated
- Removed students get Enrollment.status=paused (no delete)
- No GuardianLinks created automatically

### 4) Publish coursework link
1. Teacher selects Mission
2. Click “Publish to Classroom”
Expected:
- CourseWork created in Classroom with Scholesa link
- ExternalCourseworkLink created
- Teacher sees confirmation + deep link preview

---

## Phase 2 — Pull states, push summaries

### 5) Student opens assignment
1. Student opens Classroom assignment and clicks Scholesa link
2. Completes attempt in Scholesa, submits
Expected:
- MissionAttempt created with metadata.external identifiers (as available)
- Submission_pull eventually reflects state in Scholesa UI (if enabled)

### 6) Educator reviews attempt
1. Teacher reviews and marks reviewed in Scholesa
2. Click “Sync summary to Classroom”
Expected:
- Classroom grade/comment updated per policy
- AuditLog entry written
- Re-running the same action does not duplicate (idempotent)

---

## Security boundaries
### 7) Parent boundary
- Parent can view weekly summaries
- Parent cannot read teacher insights collections
- Parent cannot access integration mapping screens

---

## Failure cases
### 8) Token revoked
- revoke Classroom token in Google account
- run roster sync
Expected:
- IntegrationConnection.status=error
- user prompted to reconnect, no crash

### 9) Quota/429
- simulate rate limit
Expected:
- jobs backoff, UI shows “last sync failed” with retry option
