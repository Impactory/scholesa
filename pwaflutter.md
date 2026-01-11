# SCHOLESA_DART_TOTAL_MIGRATION_VIBE.md
## Rebuild Scholesa Entirely in Dart (Flutter Web PWA + Dart Cloud Run API)

You are Google Gemini working in Firebase Studio / VS Code.
Your task: migrate Scholesa from Next.js to a Dart-first architecture:
- Flutter Web PWA for ALL UI
- Dart Cloud Run API for ALL server-side logic
- Firebase remains the platform for Auth/Firestore/Storage and security rules.

This is a REBUILD, not a patch.
Do not keep old Next.js routing, SW logic, or component systems.
Do not produce partial stubs. Every screen must be minimally functional.

---

## 0) NON-NEGOTIABLE RULES

1) One Source of Truth
- User role: Firestore `users/{uid}.role`
- Studio/site scope: `siteId` and `siteIds` fields in Firestore, not URL hacks
- 3 Pillars: always present and visible:
  - FUTURE_SKILLS
  - LEADERSHIP_AGENCY
  - IMPACT_INNOVATION

2) Version Governance
- Use FVM to pin Flutter version for the repo
- Lock Dart SDK constraints in `pubspec.yaml`
- No “random upgrades”; every upgrade must update:
  - VERSION_BASELINE_SCHOLESA.md
  - pubspec.lock (commit it)
- Never “fix build” by disabling analyzers/lints

3) Security & Privacy
- No server secrets in Flutter client
- All privileged actions happen ONLY in `scholesa_api` (Dart server)
- Parent/learner-facing AI outputs must be DRAFT + human approval

4) Offline-first is REQUIRED
- Educator attendance must work offline
- Learner reflections must work offline
- Offline queue must sync on reconnect

5) Compliance Evidence
At the end of each phase, you must produce:
- A checklist of what was implemented
- How to manually verify it
- Which tests were added or run

---

## 1) TARGET REPO STRUCTURE (MUST MATCH)

repo/
├─ apps/
│  └─ scholesa_flutter/
│     ├─ lib/
│     │  ├─ app.dart
│     │  ├─ main.dart
│     │  ├─ routing/
│     │  │  ├─ app_router.dart
│     │  │  └─ role_routes.dart
│     │  ├─ theme/
│     │  │  ├─ scholesa_theme.dart
│     │  │  └─ tokens.dart
│     │  ├─ core/
│     │  │  ├─ auth/
│     │  │  ├─ firestore/
│     │  │  ├─ offline/
│     │  │  ├─ models/
│     │  │  ├─ utils/
│     │  │  └─ widgets/
│     │  ├─ features/
│     │  │  ├─ landing/
│     │  │  ├─ login/
│     │  │  ├─ learner/
│     │  │  ├─ educator/
│     │  │  ├─ parent/
│     │  │  ├─ site/
│     │  │  ├─ partner/
│     │  │  ├─ hq/
│     │  │  └─ pillars/
│     │  └─ l10n/
│     ├─ web/
│     │  ├─ manifest.json
│     │  └─ icons/
│     ├─ pubspec.yaml
│     └─ analysis_options.yaml
│
├─ services/
│  └─ scholesa_api/
│     ├─ bin/
│     │  └─ server.dart
│     ├─ lib/
│     │  ├─ routes/
│     │  ├─ middleware/
│     │  ├─ auth/
│     │  ├─ firestore/
│     │  ├─ kpis/
│     │  ├─ accountability/
│     │  ├─ ai/
│     │  └─ invariants/
│     ├─ pubspec.yaml
│     └─ Dockerfile
│
├─ infra/
│  ├─ cloudrun/
│  │  ├─ deploy_web.sh
│  │  └─ deploy_api.sh
│  └─ scheduler/
│     └─ jobs.md
│
├─ firestore.rules
├─ firestore.indexes.json
├─ VERSION_BASELINE_SCHOLESA.md
└─ docs/
   ├─ SCHOLESA_QA_FINAL_COMPLIANCE_CHECKLIST.md
   └─ SCHOLESA_DART_TOTAL_MIGRATION_VIBE.md

No Next.js app folder remains in the final state.

---

## 2) PHASED DELIVERY (DO NOT SKIP)

### Phase A — Bootstrap (Day 0)
A1. Create Flutter app under `apps/scholesa_flutter`
A2. Add FlutterFire dependencies and initialize Firebase for web
A3. Create Dart API under `services/scholesa_api` (basic server health endpoint)
A4. Create version baseline docs and FVM config
A5. Produce a “Build & Run” section in README:
- Flutter web run command
- API run command
- Deployment scripts outline

Exit Criteria:
- Flutter app runs locally
- Dart API runs locally
- Both compile cleanly

---

### Phase B — Auth + Role Routing (Critical)
B1. Implement login/logout/password reset in Flutter
B2. Ensure `users/{uid}` exists after login (create if missing only via controlled flow)
B3. Implement role-based routing using:
- `users/{uid}.role` (source of truth)
- `role_routes.dart` mapping:
  learner -> /learner
  educator -> /educator
  parent -> /parent
  siteLead -> /site
  partner -> /partner
  hq/admin -> /hq

B4. Implement protected routing (no role -> redirect to onboarding/error)

Exit Criteria:
- Each test user logs in and lands on the correct dashboard
- No blank screens, no infinite spinners, friendly errors

---

### Phase C — MVP Dashboards for All Roles
C1. Landing page (public)
C2. Learner dashboard:
- Today’s missions + pillar badges
- Create missionAttempt + reflection
- “My 3 Pillars” summary widget
C3. Educator dashboard:
- Today’s sessions
- Roster and attendance marking
- View/create missionPlan for session
C4. Parent dashboard:
- Child overview + weekly story draft view
C5. Site dashboard:
- Today at site: sessions overview
- Create/edit session (basic)
C6. Partner dashboard (if in scope):
- Challenges list (basic)
C7. HQ dashboard:
- Create programs and missions (with pillar codes)
- View top-level KPIs summary

Exit Criteria:
- Every role dashboard is functional, not placeholder-only
- Firestore writes happen with correct IDs and required fields

---

### Phase D — Offline-first Classroom Mode
D1. Implement local persistence (choose one: Hive or Isar)
D2. Implement offline queue for:
- attendanceRecords
- missionAttempts
- reflections/portfolioItems
D3. UI indicators:
- offline banner
- “queued changes” counter
D4. Sync strategy:
- on reconnect, replay queue safely
- log failures and keep items queued until success

Exit Criteria:
- Educator can take attendance offline and it syncs on reconnect
- Learner can write reflection offline and it syncs on reconnect
- No data loss

---

### Phase E — Dart API replaces privileged server logic
E1. Implement auth middleware in API:
- Verify Firebase ID token
- Load user role + site scope from Firestore
E2. Implement endpoints:
- POST /kpis/recompute (hq only)
- POST /accountability/cycle-update (hq/siteLead)
- POST /ai/educator-plan (educator -> draft only)
- POST /ai/parent-summary (educator/hq -> draft only)
- GET  /health

E3. Implement Cloud Scheduler job plan:
- daily cycle updates
- weekly KPI recompute

Exit Criteria:
- API endpoints enforce role scope
- Scheduler can call endpoints securely
- AI outputs are stored as DRAFT requiring approval

---

### Phase F — Cloud Run Deployment
F1. Build Flutter web and serve on Cloud Run
- Either:
  - serve static via a small Dart static server, OR
  - use a minimal web server in container
F2. Deploy `scholesa_api` on Cloud Run with service account IAM to Firestore
F3. Validate PWA:
- manifest loads
- installable
- caching does not break app updates

Exit Criteria:
- Both services run on Cloud Run
- PWA assets return 200
- No console errors for auth/routing

---

## 3) DATA MODEL & INVARIANTS (MUST ENFORCE)

You must preserve the same Firestore collections and ensure invariants:

- sessions -> sessionOccurrences -> attendanceRecords
- missions -> missionPlans -> missionAttempts
- pillars must be present and used everywhere

Implement invariant checks in API:
- no orphaned sessionOccurrences
- no attendanceRecords for unenrolled learners
- missionAttempts must reference valid missionId and learnerId
- pillarCodes must be one or more valid codes

---

## 4) AI SAFETY REQUIREMENTS

- AI calls happen ONLY through `scholesa_api`
- Parent/Learner-facing AI content:
  - saved as DRAFT
  - requires educator/HQ approval
- Never auto-send AI content

---

## 5) COMPLIANCE MODE (MANDATORY)

At the end of each phase, output a Compliance Report:

A) Implemented Items (✅ list)
B) Evidence (how to verify manually)
C) Tests added or run (unit or integration)
D) Remaining Gaps (🟡 with exact next actions)
E) Risks (and mitigations)

You may not claim a phase complete without its Exit Criteria met.

---

## 6) FINAL QA GATE

Before declaring migration complete:
- Follow the entire `SCHOLESA_QA_FINAL_COMPLIANCE_CHECKLIST.md`
- Ensure offline flows pass
- Ensure role scoping works
- Ensure Cloud Run deployments are stable
- Ensure no secrets are in the Flutter client

Only then is the Dart migration “DONE”.
