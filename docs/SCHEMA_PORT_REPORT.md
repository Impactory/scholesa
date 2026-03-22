# Schema Port Report

| Interface (schema.ts) | Dart/TS Model File | Repository/Service | Collection |
| --- | --- | --- | --- |
| Role | src/types/schema.ts | n/a | n/a |
| User | src/types/schema.ts | src/repositories/userRepository.ts | users |
| Site | src/types/schema.ts | src/repositories/siteRepository.ts | sites |
| Session | src/types/schema.ts | src/repositories/sessionRepository.ts | sessions |
| SessionOccurrence | src/types/schema.ts | src/repositories/sessionOccurrenceRepository.ts | sessionOccurrences |
| Enrollment | src/types/schema.ts | src/repositories/enrollmentRepository.ts | enrollments |
| AttendanceRecord | src/types/schema.ts | src/repositories/attendanceRepository.ts | attendanceRecords |
| Pillar | src/types/schema.ts | src/repositories/pillarRepository.ts | pillars |
| Skill | src/types/schema.ts | src/repositories/skillRepository.ts | skills |
| SkillMastery | src/types/schema.ts | src/repositories/skillMasteryRepository.ts | skillMastery |
| Mission | src/types/schema.ts | src/repositories/missionRepository.ts | missions |
| MissionPlan | src/types/schema.ts | src/repositories/missionPlanRepository.ts | missionPlans |
| MissionAttempt | src/types/schema.ts | src/repositories/missionAttemptRepository.ts | missionAttempts |
| Portfolio | src/types/schema.ts | src/repositories/portfolioRepository.ts | portfolios |
| PortfolioItem | src/types/schema.ts | src/repositories/portfolioItemRepository.ts | portfolioItems |
| Credential | src/types/schema.ts | deferred in web; Flutter repository exists at apps/empire_flutter/app/lib/domain/repositories.dart | credentials |
| AccountabilityCycle | src/types/schema.ts | src/repositories/accountabilityRepository.ts | accountabilityCycles |
| AccountabilityKPI | src/types/schema.ts | src/repositories/accountabilityRepository.ts | accountabilityKPIs |
| AccountabilityCommitment | src/types/schema.ts | src/repositories/accountabilityRepository.ts | accountabilityCommitments |
| AccountabilityReview | src/types/schema.ts | src/repositories/accountabilityRepository.ts | accountabilityReviews |
| AuditLog | src/types/schema.ts | src/repositories/auditLogRepository.ts | auditLogs |

## Notes
- Web stack repositories remain scaffolded; full wiring paused.
- The web `Credential` repository is not present under `src/` today and should be treated as deferred rather than implemented.
- Flutter app (apps/empire_flutter/app) uses the same Firestore collections (users, sessions, occurrences, enrollments, attendanceRecords, missions, missionAttempts, portfolioItems, credentials) with site-scoped queries and offline queue support.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `SCHEMA_PORT_REPORT.md`
<!-- TELEMETRY_WIRING:END -->
