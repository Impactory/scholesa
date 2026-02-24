# Offline Verification Steps (web + Flutter)

## Flutter (apps/empire_flutter/app)
- Build/run on device or emulator.
- Toggle network (Airplane mode) to simulate offline.

### Connectivity Banner + Queue Flush
1) From any screen, go offline; ensure red offline banner appears.
2) Enqueue a dummy action via a feature that registers an OfflineQueue dispatcher (e.g., attendance when available).
3) Confirm queued count increases in banner.
4) Go online; banner disappears and dispatcher runs, clearing the queue.

## Web (Next.js) — paused stack, keep for reference
- Open app in browser, login as target role.
- Open DevTools → Network → Offline to simulate.

### AttendanceRecord Queue
1) Role: educator. Go offline.
2) Mark attendance for a learner.
3) Inspect localStorage key `scholesa_offline_queue_v1` contains attendance item.
4) Go online; verify item removed from queue and attendanceRecords doc created.

### MissionAttempt Queue
1) Role: learner. Offline.
2) Start attempt.
3) Confirm queue entry; go online; verify missionAttempts doc exists.

### PortfolioItem Queue
1) Role: learner. Offline.
2) Add reflection.
3) Confirm queue entry; go online; verify portfolioItems doc exists.

### Retry/Dedup
- Create same attempt twice offline; queue should keep last by id (dedup).
- Turn online; ensure single write occurs.

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `OFFLINE_VERIFICATION.md`
<!-- TELEMETRY_WIRING:END -->
