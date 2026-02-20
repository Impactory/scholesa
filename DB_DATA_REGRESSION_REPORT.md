# DB + Data Regression Report

- Generated: 2026-02-20T15:24:46.397Z
- Scope: Firestore emulator regression run (15 checks)
- Summary: PASS=12, WARN=3, FAIL=0

## CRUD regression

| Status | Check | Details |
|---|---|---|
| PASS | Critical entities support create/read/update/delete lifecycle | Validated 7 entities |

## Migration regression

| Status | Check | Details |
|---|---|---|
| PASS | Upgrade migration path executes and data shape is valid | Migrated 2 user docs to schemaVersion=2 |
| PASS | Rollback strategy restores state after injected failure | Rollback executed (Injected migration failure) |

## Data integrity regression

| Status | Check | Details |
|---|---|---|
| PASS | Uniqueness enforced via deterministic doc IDs and create() | Duplicate write rejected as expected |
| WARN | Foreign-key style references are validated | Firestore accepted enrollment referencing missing session/learner; enforce via Cloud Functions or app transaction checks |
| WARN | Cascade delete behavior is explicit and verified | Session delete does not cascade to occurrences (expected in Firestore unless handled manually) |

## Transaction regression

| Status | Check | Details |
|---|---|---|
| PASS | Commit writes apply atomically | Counter after commit = 1 |
| PASS | Rollback prevents partial writes on transaction failure | Counter after rollback = 1 |
| PASS | Concurrent transactions preserve isolation under contention | Counter after 20 concurrent increments = 20 |

## Performance query regression

| Status | Check | Details |
|---|---|---|
| PASS | Critical filtered + ordered query returns with acceptable latency | Returned 25 docs in 21.71ms (emulator timing) |
| PASS | Composite index definition exists for high-traffic missionAttempts query | Index entry present in firestore.indexes.json |

## Backup/restore regression

| Status | Check | Details |
|---|---|---|
| PASS | Logical backup + restore replay returns dataset to expected state | Restored docs=2 |
| WARN | Point-in-time recovery (PITR) validation | PITR cannot be validated in Firestore emulator; run managed-service PITR drill in production/staging project |

## Concurrency regression

| Status | Check | Details |
|---|---|---|
| PASS | Double-write race on same deterministic ID rejects one writer | Settled results: rejected/fulfilled |
| PASS | High-contention transactional updates avoid lost writes | credits=25 |

## Notes

- Firestore has no native foreign keys/cascade constraints; WARN results indicate where app/function-level guards should be used.
- Query-plan introspection is limited in emulator; latency + index definition checks are used as practical proxies.
- PITR must be validated against managed Firestore in a cloud project (not emulator).

