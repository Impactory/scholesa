# Full Honesty Audit

Last updated: 2026-03-19
Status: Beta ready, not gold ready
Scope: Flutter app product surfaces, current route inventory, test evidence, and release readiness

This is a fresh whole-app honesty pass after the earlier blocker remediation, web rollout verification, shared-device logout verification, and native release-path hardening.

## Audit Decision

- Not gold ready.
- Beta ready for a controlled audience.
- The product is no longer failing because of obvious fake primary-path actions on the audited core flows.
- The remaining gap is release completeness and breadth confidence, not a single catastrophic user-flow lie.

## A. Release Matrix Updated

### Route and surface inventory

- Enabled route registry in the app router covers 52 page surfaces across learner, educator, parent, site, partner, HQ, and cross-role flows.
- Canonical aliases exist for:
  - `/educator/review-queue` -> `/educator/missions/review`
  - `/site/scheduling` -> `/site/sessions`
  - `/hq/cms` -> `/hq/curriculum`

### Verification inventory

- 36 focused test files currently cover direct pages, workflow paths, regressions, honesty checks, and placeholder-action checks.
- Current audit verification run:
  - `flutter analyze`: passed
  - Focused audit suite: passed
  - Total in the current broad audit run: 247 tests passed, 0 failed

### Surface classification

#### Complete or materially complete

- Authentication and shared-device sign-out
- Learner missions and habits core study paths
- Educator learner differentiation and follow-up request flow
- Cross-role messages and notifications unread-state and dismiss flows
- HQ role impersonation activation and exit flow
- HQ sites loading, filtering, search, and create-site flow
- Parent billing as honest view-only summary
- Parent schedule and portfolio support-request flows
- Site dashboard primary path after misleading pillar telemetry removal
- Site ops and deploy-facing runtime checks
- HQ exports bundle download path

#### Honest but partial

- Several secondary admin and support surfaces that intentionally degrade when identity, storage, or site context is missing

#### Operationally incomplete

- iOS distribution proof
- Android store upload proof

## B. Fixes Completed

### Product fixes already landed

1. Removed the disconnected pillar telemetry card from the site dashboard primary path.
2. Replaced the educator learner-support dead end with persisted follow-up requests.
3. Canonicalized audited route aliases to redirect to a single destination.
4. Consolidated duplicated Firestore session lookup logic in the AI assistant overlay.
5. Added regression proof that Settings sign-out clears auth state and returns to an unauthenticated route.
6. Preserved parent billing as an honest summary-and-support surface instead of fake self-service.
7. Kept parent portfolio and schedule secondary actions wired to real support-request persistence rather than dead buttons.

### Release hardening already landed

1. Web deploy scripts now promote latest ready revisions when appropriate.
2. iOS local and CI release helpers now fail early on missing signing prerequisites.
3. Android local and CI release helpers now support store-grade `.aab` output and internal-track automation.

## C. Evidence Of Verification

### Static and dynamic verification

- `flutter analyze` completed with no issues.
- The focused audit command completed successfully:
  - `flutter test test/*honesty* test/*placeholder* test/*regression* test/*workflow* test/missions_page_test.dart test/habits_page_test.dart test/messages_pages_test.dart test/hq_role_switcher_page_test.dart test/hq_sites_page_test.dart`
- Result: 247 tests passed, 0 failed.

### Notable verified behaviors

- Educator learner follow-up requests persist through the real support-request path.
- Parent portfolio share requests persist in app.
- Parent portfolio summary export writes a real file.
- Parent schedule reminder actions persist through the real support-request path.
- Parent billing remains explicit about support handoff and avoids fake `Pay Now` or `Manage Plan` actions.
- Settings sign-out clears the session and returns the user to an unauthenticated route.
- AI coach widget regressions pass even when Firebase is unavailable, which confirms safe failure handling rather than crash behavior.
- Missions and habits now provide degraded-mode guidance and a concrete continue action when AI runtime is unavailable.
- Attendance now renders a recoverable unavailable state instead of a bare provider-missing text failure.
- Messages and notifications now have direct page coverage for unread transitions, dismiss, and mark-all-read behavior.
- HQ role switcher now has direct page coverage for impersonation activation and exit behavior.
- HQ sites now has direct page coverage for Firestore-backed loading, filter/search behavior, and create-site persistence.

## D. Remaining Blockers

### Blocker 1: Native distribution is still not proven end to end

The repo now has honest release automation, but gold readiness still requires one successful distribution proof on each native platform.

Current state:

- iOS build flow is hardened but no successful TestFlight upload has been proven in this environment.
- Android release build flow is hardened but no successful Google Play upload has been proven in this environment.

This is the main gold gate.

### Residual risk: Breadth confidence is still lower than gold across the full route set

The app now has meaningful targeted coverage, but 52 enabled page surfaces are broader than the direct page-test footprint.

Why it matters:

- The core audited routes are much stronger.
- Missions, habits, and attendance now have direct degraded-mode coverage in addition to the broader honesty, placeholder, regression, and workflow suites.
- Messages and notifications now have direct page coverage instead of relying only on shared regressions.
- HQ role switcher now has direct route coverage instead of remaining audit-inferred only.
- HQ sites now has direct route coverage instead of remaining audit-inferred only.
- Secondary role surfaces still rely on a mix of direct page tests, workflow tests, placeholder-action tests, and regression coverage rather than comprehensive route-by-route end-to-end coverage.
- That is acceptable for beta.
- It is still short of gold for a role-dense admin app.

## E. Recommendation

- Recommendation: beta ready
- Not gold ready

## What Is Risky But Acceptable For Beta

1. Honest fallback states on secondary surfaces when site context, identity, storage, or a provider is unavailable.
2. Coverage that is strong on priority paths but not exhaustive across every enabled route.

## What Must Happen Before Gold

1. Complete one successful iOS TestFlight upload through the supported release path.
2. Complete one successful Android Play upload through the supported release path.
3. Expand direct or workflow-level verification over the remaining highest-risk secondary role surfaces until the full route set has fewer blind spots.