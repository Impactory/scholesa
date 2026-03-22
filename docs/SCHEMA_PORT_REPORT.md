# Schema Port Report

| Interface (schema.ts) | Dart/TS Model File | Implemented repository/service | Collection |
| --- | --- | --- | --- |
| Role | src/types/schema.ts | n/a | n/a |
| User | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | users |
| Site | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | sites |
| Session | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | sessions |
| SessionOccurrence | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | sessionOccurrences |
| Enrollment | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | enrollments |
| AttendanceRecord | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | attendanceRecords |
| Pillar | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | pillars |
| Skill | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | skills |
| SkillMastery | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | skillMastery |
| Mission | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | missions |
| MissionPlan | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | missionPlans |
| MissionAttempt | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | missionAttempts |
| Portfolio | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | portfolios |
| PortfolioItem | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | portfolioItems |
| Credential | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | credentials |
| AccountabilityCycle | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | accountabilityCycles |
| AccountabilityKPI | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | accountabilityKPIs |
| AccountabilityCommitment | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | accountabilityCommitments |
| AccountabilityReview | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | accountabilityReviews |
| AuditLog | src/types/schema.ts | apps/empire_flutter/app/lib/domain/repositories.dart | auditLogs |

## Notes
- This report maps implemented repository coverage to the Flutter app. A web `src/repositories/` layer is not present in the repo today and should be treated as deferred rather than scaffolded.
- Flutter app (apps/empire_flutter/app) uses the same Firestore collections (users, sessions, occurrences, enrollments, attendanceRecords, missions, missionAttempts, portfolioItems, credentials) with site-scoped queries and offline queue support.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `SCHEMA_PORT_REPORT.md`
<!-- TELEMETRY_WIRING:END -->
