# 29_GOOGLE_CLASSROOM_SCHEMA_EXTENSIONS.md
Schema additions for Classroom integration (Phase 1 + 2)

These entities extend `docs/02A_SCHEMA_V3.ts` without breaking existing v3.

All integration data must be:
- site-scoped where appropriate
- auditable
- tokens never stored in plaintext in Firestore

---

## Collections (recommended)

### integrations/{connectionId}
`IntegrationConnection`
- ownerUserId (teacher uid)
- provider = "google_classroom"
- status: active|revoked|error
- scopesGranted: string[]
- tokenRef: string (pointer to secret store / encrypted blob metadata)
- createdAt/updatedAt

### externalCourseLinks/{id}
`ExternalCourseLink`
- providerCourseId (Classroom course.id)
- ownerUserId (teacher uid)
- siteId
- sessionId
- syncPolicy: manual|daily|weekly
- lastRosterSyncAt
- lastCourseworkSyncAt

### externalUserLinks/{id}
`ExternalUserLink`
- providerUserId (Classroom userId)
- scholesaUserId (uid)
- siteId
- roleHint: learner|educator
- matchSource: email|manual|sis

### externalCourseworkLinks/{id}
`ExternalCourseworkLink`
- providerCourseId
- providerCourseWorkId
- siteId
- missionId
- sessionId?
- sessionOccurrenceId?
- publishedBy (uid)
- publishedAt

### syncJobs/{jobId}
`SyncJob`
- type: roster_import|coursework_publish|submission_pull|grade_push
- siteId
- requestedBy
- status: queued|running|failed|completed
- cursor/nextPageToken (if needed)
- lastError

### syncCursors/{id}
`SyncCursor`
- ownerUserId
- providerCourseId
- cursorType: roster|coursework|submissions
- nextPageToken / updatedMin
- updatedAt

---

## Mapping fields inside existing entities (additive)

### Session.metadata.external
Store *references only*:
- { provider: "google_classroom", courseId: "..." }

### Mission / MissionPlan metadata
- Mission.metadata.externalCourseworkLinkId (optional)
- MissionPlan.metadata.publishTargets (optional)

### MissionAttempt metadata
- MissionAttempt.metadata.external = { courseId, courseWorkId, submissionId?, state? }
State may mirror Classroom’s StudentSubmission state (read-only mirror).

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `29_GOOGLE_CLASSROOM_SCHEMA_EXTENSIONS.md`
<!-- TELEMETRY_WIRING:END -->
