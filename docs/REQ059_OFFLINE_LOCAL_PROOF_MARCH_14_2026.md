# REQ-059 Offline Extensions Local Proof

Date: 2026-03-14

## Scope correction

The previous REQ-059 row pointed at deleted paths under `app/lib/features/offline/*` and overstated the implemented offline scope. The actual offline engine lives under `apps/empire_flutter/app/lib/offline/` and the shipped offline-capable slices now align to the canonical catalog in `docs/68_OFFLINE_OPS_CATALOG.md`:

- attendance record queueing
- presence check-in queueing
- presence check-out queueing
- incident submission queueing
- direct message send queueing
- mission proof bundle draft queueing

Billing remains online-only.

## Code changes validated

- `apps/empire_flutter/app/lib/modules/attendance/attendance_service.dart`
  - fixed duplicate-write behavior by queueing only when offline
- `apps/empire_flutter/app/lib/modules/checkin/checkin_service.dart`
  - added offline queueing for check-in and check-out
- `apps/empire_flutter/app/lib/modules/messages/message_service.dart`
  - added offline queueing for direct messages and optimistic local state
- `apps/empire_flutter/app/lib/modules/missions/mission_service.dart`
  - added offline queueing for proof bundle draft saves
- `apps/empire_flutter/app/lib/modules/site/site_incidents_page.dart`
  - added offline queueing for incident submission
- `apps/empire_flutter/app/lib/offline/sync_coordinator.dart`
  - replay now writes queued message sends into `messageThreads` + `messages`
  - replay now writes queued proof drafts into `proofOfLearningBundles`
  - queued check-outs now persist as idempotent check-in log records

## Test command

```bash
cd apps/empire_flutter/app && flutter test test/offline_extensions_regression_test.dart test/offline_queue_test.dart test/sync_coordinator_test.dart test/message_notification_request_test.dart test/persistence_blockers_regression_test.dart
```

## Result

- Passed
- 29 tests green
- No failing Flutter analyzer errors in edited files
