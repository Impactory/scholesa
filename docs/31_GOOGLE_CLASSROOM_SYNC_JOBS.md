# 31_GOOGLE_CLASSROOM_SYNC_JOBS.md
Sync jobs (Phase 1 + 2) — reliability, quotas, and idempotency

This doc defines how we sync Classroom data without breaking classrooms.

---

## 1) Job types

### roster_import (Phase 1)
Inputs:
- providerCourseId
Outputs:
- ExternalUserLinks updated
- Enrollments upserted
Rules:
- never create GuardianLink automatically
- if removed from roster → mark Enrollment paused (do not delete)

Idempotency key:
- `roster_import:{courseId}:{dateBucket}`

### coursework_publish (Phase 1)
Creates Classroom CourseWork with Scholesa deep link.
Outputs:
- ExternalCourseworkLink created
Idempotency key:
- `coursework_publish:{courseId}:{missionId}:{occurrenceId?}`

### submission_pull (Phase 2)
Pull StudentSubmission states for the linked course/coursework.
Outputs:
- MissionAttempt.metadata.external.state updated (read-only mirror)
Idempotency key:
- `submission_pull:{courseId}:{courseWorkId}:{window}`

### grade_push (Phase 2)
Push Scholesa review summary to Classroom.
Outputs:
- Classroom grade and/or return state and private comments
Idempotency key:
- `grade_push:{courseId}:{courseWorkId}:{studentId}:{attemptId}`

---

## 2) Scheduling
Default:
- roster_import: nightly + manual button
- submission_pull: every 15–60 minutes during pilot (or later use push notifications)
- grade_push: manual per attempt or batch per review session

---

## 3) Quotas, backoff, and caching
- use exponential backoff on 429/5xx
- cache course list and roster snapshots
- incremental sync with cursors/nextPageToken
- never block educator UI on sync completion (show last sync time + manual sync)

---

## 4) Safety
- never overwrite Scholesa source-of-truth artifacts with Classroom copies (Mode A)
- only mirror states/summary outward
- log errors to SyncJob.lastError and emit telemetry
