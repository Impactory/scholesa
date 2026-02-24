# 02_SCHEMA_CONTRACT.md

This doc defines how data changes stay stable, secure, and auditable.

## Canonical schema file
- `docs/02A_SCHEMA_V3.ts` is the single source of truth for:
  - collection names
  - entity shapes
  - invariants (authority, deterministic IDs)

If it’s not in `02A`, it isn’t part of the platform.

---

## Rules
1) **No ad-hoc collections** in UI/API code.
2) **Deterministic IDs** where required (attendance).
3) **Authority enforced**:
   - API-only writes for billing + entitlements
   - Prefer API-only writes for computed intelligence (signals/insights)
   - Admin-only writes for guardian links and intake
4) **Backward compatibility**:
   - Additive changes are preferred
   - If breaking change is needed, add migration plan + compatibility layer

---

## “Kyle & Parrot” admin-only intake
School admin must capture these responses:
- store under `LearnerProfile.metadata.kyleParrot = { kyleAnswer, parrotAnswer }`
- parents cannot create or edit these fields
- recommended default: parents cannot read these fields

---

## Change procedure (mandatory)
When adding/modifying schema:
1) Update `02A_SCHEMA_V3.ts`
2) Update Firestore rules (`docs/26`)
3) Update API validators and model mappings (`docs/27`)
4) Update traceability (`docs/10`)
5) Add tests and QA steps (`docs/09`)
6) Pass audit (`docs/19`)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `02_SCHEMA_CONTRACT.md`
<!-- TELEMETRY_WIRING:END -->
