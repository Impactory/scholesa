# REQ-117 Google Classroom Local Proof

Date: 2026-03-14

## What was incomplete

The educator integrations page was largely static and did not consume the callable integrations-health payload. The sync-job pipeline also wrote `provider` on queued sync jobs, while the UI health surface was matching on `type`, which broke end-to-end status reconciliation.

## Changes made

- `apps/empire_flutter/app/lib/modules/educator/educator_integrations_page.dart`
  - switched to a callable-backed integrations surface
  - renders live Google Classroom connection state
  - triggers sync jobs and connection status changes through injectable or callable handlers
- `apps/empire_flutter/app/lib/modules/site/site_integrations_health_page.dart`
  - now matches sync jobs using `provider` with fallback to `type`
- `functions/src/workflowOps.ts`
  - queued sync jobs now persist both `provider` and `type` for stable UI consumption
- `apps/empire_flutter/app/lib/domain/repositories.dart`
  - integration/course/user/coursework repositories are now injectable for focused Firestore proof

## Validation

Flutter widget and repository proof:

```bash
cd apps/empire_flutter/app && flutter test test/google_classroom_integration_test.dart test/site_roster_review_queue_test.dart
```

Result:

- Passed
- 3 tests green

Functions TypeScript build:

```bash
cd /Users/simonluke/dev/scholesa && npm --prefix functions run build
```

Result:

- Passed
