# 50_PROVIDER_WIRING_PATTERNS.md
Provider Wiring Patterns (compile-safe, incremental)

Goal: add providers only when the module is implemented, without increasing coupling or causing build failures.

---

## Pattern 1 (Recommended): Route-scoped Provider
Attach provider(s) inside route builder.

Pros:
- no global dependency growth
- module can be removed/rewired easily
- fewer build issues

Example:
```dart
case '/site/incidents':
  return MaterialPageRoute(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IncidentsController(...)),
      ],
      child: const SiteIncidentsScreen(),
    ),
  );
```

---

## Pattern 2: Module Route Factory
Each feature exports `routes.dart` to keep main router clean.

`lib/features/incidents/routes.dart`
```dart
Route<dynamic> incidentsRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => IncidentsController(...),
      child: const SiteIncidentsScreen(),
    ),
  );
}
```

Main router:
```dart
if (settings.name == '/site/incidents') return incidentsRoute(settings);
```

---

## Pattern 3: App-level Provider (avoid unless required)
Only use for:
- auth state
- app config
- offline queue global coordinator

If a provider must be global, it must:
- be lightweight
- not depend on feature modules
- not import feature screens

---

## Error handling pattern
Controllers should expose:
- `bool isLoading`
- `Object? error`
- `void retry()`

UI should:
- show loading skeleton/placeholder
- show empty state
- show error state with retry

---

## Role gates
Wrap each module screen:
- `RoleGate(allowedRoles: [...], child: Screen())`

Ensure:
- wrong roles cannot access even if route is enabled

---

## Offline queue integration
Modules that write should:
- write to queue on offline
- reconcile with server on reconnect
- show a “Pending sync” ribbon

---

## Testing expectations
- Widget test: RoleGate works
- Repository test: basic read/write mapping
- Controller test: error->retry state transitions

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `50_PROVIDER_WIRING_PATTERNS.md`
<!-- TELEMETRY_WIRING:END -->
