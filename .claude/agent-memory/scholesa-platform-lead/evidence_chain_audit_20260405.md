---
name: Evidence Chain Audit 2026-04-05 (updated)
description: Full evidence chain audit — route wiring conflicts, dead renderers, schema inconsistencies, seed data, Flutter growth engine, generic card routes
type: project
---

## Evidence Chain Audit Findings (2026-04-05, updated)

### P0: Route Page Bypass — Dead Custom Renderers

5 routes have page.tsx files that bypass WorkflowRoutePage entirely, rendering components directly. This makes the registered custom renderers in customRouteRenderers.tsx DEAD CODE for those routes. The bypassed renderers are substantive (not wrappers).

| Route | page.tsx imports | Dead custom renderer |
|---|---|---|
| /educator/today | EducatorDashboardToday | EducatorTodayRenderer |
| /learner/today | LearnerDashboardToday | LearnerProgressReportRenderer |
| /learner/portfolio | LearnerPortfolioBrowser + LearnerEvidenceSubmission | LearnerPortfolioCurationRenderer |
| /parent/summary | ParentSummaryDashboard | GuardianCapabilityViewRenderer |
| /educator/missions/review | WorkflowRoutePage + RubricReviewPanel (renderRecordDetail) | EducatorEvidenceReviewRenderer |

Additionally, 5 more routes bypass dispatch without conflict: /hq/capabilities, /educator/evidence, /educator/verification, /parent/passport, /site/evidence-health.

**Why:** Platform evolved through two patterns without consolidation.
**How to apply:** Pick one pattern per route. The custom renderers are generally more feature-complete. Direct-import pages are missing RoleRouteGuard, Suspense, and telemetry.

### P0: Path Mismatches in customRouteRenderers.tsx

| Renderer | Mapped path | Correct path |
|---|---|---|
| HqCapabilityFrameworkRenderer | /hq/curriculum | /hq/capability-frameworks |
| LearnerProofAssemblyRenderer | /learner/missions | /learner/proof-assembly |
| LearnerShowcasePeerReviewRenderer | NOT MAPPED | needs route |
| LearnerMiloOSRenderer | NOT MAPPED | needs route |

### P1: Seed Data Schema Inconsistencies

- Rubrics seeded to `assessmentRubrics` collection; RubricManager may read from `rubrics`
- Mastery: seed uses latestLevel/highestLevel; renderers use currentLevel/currentScore
- Portfolio: seed uses proofOfLearningStatus/capabilityIds; renderer reads verificationStatus/linkedCapabilityIds
- Capabilities: seed uses `title`; HqCapabilityAnalyticsRenderer reads `name`

### P1: Evidence Routes Still on Generic Cards

/hq/rubric-builder, /educator/observations, /educator/proof-review, /educator/rubrics/apply, /learner/checkpoints, /learner/reflections, /learner/peer-feedback, /parent/growth-timeline

### P1: Missing RoleRouteGuard on Direct-Import Pages

/hq/capabilities, /educator/evidence, /educator/verification, /parent/passport, /site/evidence-health all render bare components without role enforcement.

### Confirmed: All Custom Renderers Are Real

All 12 renderers in src/features/workflows/renderers/ are substantive implementations with real Firestore queries and domain-specific UI. EducatorEvidenceReviewRenderer (880 lines) includes the full growth write engine.

### Confirmed: Seed Data Covers Evidence Chain

seedFirestore.js covers 16+ evidence chain collections including capabilities (4), rubrics (1), missionAttempts (1), proofOfLearningBundles (1), evidenceRecords (2), capabilityMastery (3), capabilityGrowthEvents (3), rubricApplications (1), portfolioItems (2), learnerReflections (1), checkpointHistory (2), skillEvidence (2), aiInteractionLogs (2), peerFeedback (1), recognitionBadges (1), badgeAwards (1).

### Confirmed: Flutter GrowthEngineService Is Real

268-line service with onRubricApplied, onCheckpointCompleted, onProofVerified, _checkCapabilityThreshold. NOT routed through offline queue — growth events lost if offline.

### Confirmed: No TODO/FIXME/STUB in Flutter Codebase

Zero matches in apps/empire_flutter/app/lib/. Export stub is correct conditional import pattern.

### Recommendation

Beta-ready. P0 fix: resolve route bypass conflicts and path mismatches so custom renderers are not dead code. P1: normalize seed schema fields and add RoleRouteGuard to direct-import pages.
