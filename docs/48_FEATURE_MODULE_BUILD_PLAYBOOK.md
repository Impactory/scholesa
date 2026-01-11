# 48_FEATURE_MODULE_BUILD_PLAYBOOK.md
Feature Module Build Playbook (Flutter + Cloud Run + Firestore)

Goal: implement Scholesa feature modules incrementally without breaking builds.
Dashboards remain stable and “flip routes on” only when a module is complete.

**Design language lock:** keep current design language (Material Cards/ListTiles, existing tokens). No reskin.

---

## 1) Non-negotiable rules
1. `role_dashboards.dart` stays “dumb”:
   - no Firestore queries
   - no new provider imports
   - only renders card registry + routes
2. Every feature module owns its:
   - repositories (Firestore + API)
   - controllers/state (Provider ChangeNotifier or equivalent)
   - UI screens + widgets
3. Routes are enabled ONLY when the module passes the “Done checklist” (section 6).

---

## 2) Standard module structure (required)
Create modules under:
`lib/features/<module_name>/...`

Recommended structure:
```
lib/
  features/
    <module_name>/
      data/
        <module_name>_repository.dart
        <module_name>_datasource.dart
      domain/
        models.dart
        usecases.dart              // optional
      state/
        <module_name>_controller.dart
        <module_name>_provider.dart
      ui/
        <module_name>_screen.dart
        widgets/
      routes.dart                  // Route factory + route names
```

---

## 3) Provider wiring pattern (route-scoped = safest)
Prefer attaching providers at route build time, not globally.

Example:
```dart
case '/educator/attendance':
  return MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => AttendanceController(
        repo: AttendanceRepository(
          firestore: FirebaseFirestore.instance,
          api: CloudRunApiClient(),
        ),
      ),
      child: const EducatorAttendanceScreen(),
    ),
  );
```

Benefits:
- avoids heavy global providers
- isolates dependency changes to each module
- dashboards compile regardless of module status

---

## 4) Role gates (required)
Each module screen must gate access.

Preferred:
- `RoleGate(allowedRoles: ['educator'], child: EducatorAttendanceScreen())`

Minimum:
- in `build()`, read `AppState.role` and show Forbidden screen if not allowed.

---

## 5) Offline-first integration rule
If a module performs writes during class time:
- add an offline queue adapter:
  - write to local queue when offline
  - sync when online
  - show “Pending sync” banner + queue count

Modules likely needing offline:
- attendance
- check-in/out
- mission evidence uploads metadata (file upload may require online but queue metadata)

---

## 6) Route enablement “Done checklist”
Set `kKnownRoutes[route] = true` ONLY when:

1) Screen exists and compiles  
2) Provider wiring exists and compiles  
3) Route is registered in router (Material routes or onGenerateRoute)  
4) Role gate is enforced  
5) Smoke tests pass:
   - opens from dashboard
   - empty state is graceful
   - one happy-path action works
   - offline does not crash (if applicable)

Until then: keep route disabled and show “not wired yet” SnackBar from dashboard.

---

## 7) Recommended build order
Use `47_ROLE_DASHBOARD_CARD_REGISTRY.md` as canonical source of cards.

Phase A (Shared):
- Messages
- Notifications

Phase B (Educator core):
- Today’s Classes
- Attendance
- Review Queue
- Mission Plans
- Learner Supports

Phase C (Site admin operations):
- Provisioning
- Check-in/out
- Incidents
- Identity Resolution
- Integrations Health
- Site Billing

Phase D (Learner):
- Today
- Missions
- Habit Coach
- Portfolio

Phase E (Parent):
- Summary
- Schedule
- Portfolio Highlights
- Billing

Phase F (Partner/HQ):
- Partner listings/contracts/payouts
- HQ approvals/audit/safety/billing/integrations health

---

## 8) Testing expectations
Every module PR must include:
- a short manual QA run (steps)
- at least one widget test for role guard rendering
- at least one “repository happy path” test (mocked)

---

## 9) Doc sources
- Cards and per-role expected features: `47_ROLE_DASHBOARD_CARD_REGISTRY.md`
- Integration flows: docs 28–40
- Physical ops and compliance: docs 41–46
